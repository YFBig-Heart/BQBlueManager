//
//  YFCommunicationManager.m
//  PaddleTennisDemo
//
//  Created by Coollang on 2017/10/11.
//  Copyright © 2017年 Coollang-YF. All rights reserved.
//

#import "YFCommunicationManager.h"
#import "YFBTHandler.h"


static NSString * const kNewOperationService = @"0001";
static NSString * const kNewNotifyCharacteristic = @"0003";
static NSString * const kNewWriteCharacteristic = @"0002";
static NSString * const kNewReadCharacteristic = @"0004";

#pragma mark - DFU
static NSString * const dfuServiceUUIDString = @"00001530-1212-efde-1523-785feabcd123";
static NSString * const dfuControlPointCharacteristicUUIDString = @"00001531-1212-efde-1523-785feabcd123";
static NSString * const dfuMacReadUUIDString = @"00001533-1212-efde-1523-785feabcd123";

@interface YFCommunicationManager (){
    NSMutableArray *homePageArr; //运动主界面数据保存统一处理
    BOOL isReponsed; //实时指令发送后5秒是否被应答
}
@property (nonatomic, strong) LGCharacteristic *deviceNewWriteCharacterstic;
@property (nonatomic, strong) LGCharacteristic *deviceNewNotifyCharacterstic;
@property (nonatomic, strong) LGCharacteristic *deviceNewReadCharacterstic;
@property (nonatomic, strong) LGCharacteristic *dfuMacReadCharacterstic;
@property (nonatomic, strong) LGCharacteristic *dfuControlPointCharacterstic;

@property (nonatomic, copy) BleConnectBlock connectBlock;
@property (nonatomic, copy) OperationBlock operationBlock;

/** 当前操作的回调 */
@property (nonatomic, copy)BleHandleCompletionBlock currenthandleBlock;

@end

@implementation YFCommunicationManager
- (instancetype)init{
    if (self = [super init]){
        _shouldRetryConnect = YES;
    }
    return self;
}

+ (void)initialize {
    [[YFCommunicationManager shareInstance] lgCenterManager];
}
+ (instancetype)shareInstance {
    static id shareInstsance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstsance = [[self alloc] init];
    });
    return shareInstsance;
}
- (LGCentralManager *)lgCenterManager {
    return [LGCentralManager sharedInstance];
}

- (BOOL)isPeripheralConnected {
    return [YFCommunicationManager shareInstance].lgPeripheral.isConnected;
}
- (void)startScanPeripheralsWithScanBlock:(LGCentralManagerDiscoverPeripheralsCallback)scanBlock {
    if ([self isCentralReady] && scanBlock) {
        [[LGCentralManager sharedInstance] scanForPeripheralsWithScanBlock:scanBlock];
    }
}
- (NSNumber *)batteryValue {
    return [self isPeripheralConnected] ? _batteryValue : @0;
}
- (BOOL)isDFUMode {
    return (self.dfuMacReadCharacterstic || self.dfuControlPointCharacterstic);
}
- (void)startScanPeripheralsWithBlock:(DiscoverPerpheralsCallback)scanBlock {
    if (![self isCentralReady]) {
        if (scanBlock) {
            scanBlock(nil,[YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleCentralNotReadyErrorCode]);
        }
        return;
    }
    [[LGCentralManager sharedInstance] scanForPeripheralsWithScanBlock:^(NSArray *peripherals) {
        if (scanBlock) {
            scanBlock(peripherals,nil);
        }
    }];
}
- (void)stopScanningPeripherals {
    if ([LGCentralManager sharedInstance].isScanning) {
        [[LGCentralManager sharedInstance] stopScanForPeripherals];
    }
}

#pragma mark - connect& disconnect
- (void)connectPeripheral:(LGPeripheral *)peripheral completion:(BleConnectBlock)block {
    self.lgPeripheral = peripheral;
    self.connectBlock = block;
    __weak YFCommunicationManager *weakSelf = self;
    [peripheral connectWithTimeout:5 completion:^(NSError *error) {
        if (!error) {
            if (!self.isDFUMode) {
                weakSelf.shouldRetryConnect = YES;
            }
            [weakSelf setupServicesWithPeripheral:peripheral completion:block];
        } else {
            if (error.code ==  kConnectionTimeoutErrorCode) {
                block(NO,[YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleTimeOutErrorCode]);
            }else {
                block(NO,error);
            }
        }
    }];
}
- (void)setupServicesWithPeripheral:(LGPeripheral *)peripheral completion:(BleConnectBlock)block {
     self.connectBlock = block;
    [self defaultCharacteristicSetting];
    
    self.lgPeripheral = peripheral;
    __weak YFCommunicationManager *weakSelf = self;
    [peripheral discoverServicesWithCompletion:^(NSArray *services, NSError *error) {
        
        for (LGService *service in services) {
//            YFPTLog(@"serve uuidString:%@", service.UUIDString);
            if ([service.UUIDString isEqualToString:kNewOperationService]) {
                [service discoverCharacteristicsWithCompletion:^(NSArray *characteristics, NSError *error) {
                    for (LGCharacteristic *characteristic in characteristics) {
                        YFPTLog(@"characteristic:%@", characteristic.UUIDString);
                       
                        if ([characteristic.UUIDString isEqualToString:kNewWriteCharacteristic]) {
                            weakSelf.deviceNewWriteCharacterstic = characteristic;
                            [weakSelf checkIfAllReady];
                        } else if ([characteristic.UUIDString isEqualToString:kNewNotifyCharacteristic]) {
                            weakSelf.deviceNewNotifyCharacterstic = characteristic;
                            [characteristic setNotifyValue:YES completion:nil onUpdate:^(NSData *data, NSError *error) {
                                [weakSelf handleData:data];
                                [weakSelf checkIfAllReady];
                            }];
                        } else if ([characteristic.UUIDString isEqualToString:kNewReadCharacteristic]) {
                            weakSelf.deviceNewReadCharacterstic = characteristic;
                            [characteristic readValueWithBlock:^(NSData *data, NSError *error) {
                                if (!error) {
                                    peripheral.macAddress = [self convertNewMacAddressWithData:data];
                                    YFPTLog(@"mac data:%@", peripheral.macAddress);
                                    [weakSelf checkIfAllReady];
                                }
                            }];
                        }
                    }
                }];
                
            } else if ([service.UUIDString isEqualToString:dfuServiceUUIDString]) {
                [service discoverCharacteristicsWithCompletion:^(NSArray *characteristics, NSError *error) {
                    for (LGCharacteristic *characteristic in characteristics) {
//                        YFPTLog(@"characteristic:%@", characteristic.UUIDString);
                        if ([characteristic.UUIDString isEqualToString:dfuMacReadUUIDString]) {
                            weakSelf.dfuMacReadCharacterstic = characteristic;
                            [weakSelf checkIfAllReady];
                        } else if ([characteristic.UUIDString isEqualToString:dfuControlPointCharacteristicUUIDString]) {
                            weakSelf.dfuControlPointCharacterstic = characteristic;
                            [weakSelf checkIfAllReady];
                        }
                    }
                }];
            }
        }
        
    }];
}
- (void)reConnectPeripheralUUID:(NSUUID *)uuid completion:(BleConnectBlock)block {
    if (uuid == nil) {
        if (block){
            block(NO,[YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleNotFoundUUIDErrorCode]);
        }
        return;
    }
    LGPeripheral * peripheral = [[[LGCentralManager sharedInstance] retrievePeripheralsWithIdentifiers:@[uuid]] lastObject];
    __weak YFCommunicationManager *weakSelf = self;
    [peripheral connectWithTimeout:5 completion:^(NSError *error) {
        if (!error) {
            [weakSelf setupServicesWithPeripheral:peripheral completion:block];
        }else{
            if (error.code ==  kConnectionTimeoutErrorCode) {
               block(NO,[YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleTimeOutErrorCode]);
            }else {
                block(NO,error);
            }
           
        }
    }];
}

- (void)reconnetDeviceCompletion:(BleConnectBlock)block {
    NSString *UUIDString = self.lgPeripheral.UUIDString;
    if (UUIDString.length <= 0) {
        if (block){
            block(NO,[YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleNotFoundUUIDErrorCode]);
        }
        return;
    }
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:UUIDString];
    [self reConnectPeripheralUUID:uuid completion:block];
}

- (void)disconnectThePeripheralWithCompletionBlock:(BleConnectBlock)block {
    if (self.lgPeripheral.isConnected) {
        self.shouldRetryConnect = NO;
        [self.lgPeripheral disconnectWithCompletion:^(NSError *error) {
            if (!error) {
                if (block) {
                    block(YES,nil);
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:kLGPeripheralDidDisconnect object:nil];
            }
        }];
    } else {
        if (block) {
            block(YES,nil);
        }
    }
}



#pragma mark - 发送操作指令
- (void)performOperationType:(OperationType)operationType object:(id)object completionBlock:(OperationBlock)block {
    NSData *data = [self dataWithOperationType:operationType object:object];
    if (data == nil) {
        return;
    }
    [self.deviceNewWriteCharacterstic writeValue:data completion:^(NSError *error) {
        YFPTLog(@"error:%@",error);
        if (!error) {
            YFPTLog(@"发送特征值数据:%@",data);
            if (self.operationBlock) {
                self.operationBlock(NO,nil);
            }
            if (operationType == OperationType3DData && [object integerValue] == 4) {
                block(YES,nil);
            }else {
               self.operationBlock = block;
            }
        }
    }];
}

- (NSData *)dataWithOperationType:(OperationType)operationType object:(id)object {
    Byte bytes[20];
    bytes[0] = [self head];
    bytes[1] = [self getFunctionCodeByOperationType:operationType];
    NSInteger index = 2;
    switch (operationType) {
        case OperationTypeVerify:{
            long long timeStamp = [[NSDate date] timeIntervalSince1970];
            bytes[2] = timeStamp /(256 * 256 * 256);
            bytes[3] = timeStamp /(256 * 256);
            bytes[4] = timeStamp /256;
            bytes[5] = timeStamp % 256;
            index = 6;
        }
            break;
        case OperationTypeChangeDeviceName:{
            if (![self checkModifyNameLength:object]) {
                if (self.currenthandleBlock) {
                    self.currenthandleBlock(NO, nil, [YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleDeviceNameLengthMoreThan17Char]);
                    self.currenthandleBlock = nil;
                }
                return nil;
            }
            NSMutableData *nameData = [[object dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
            NSInteger nameLength = [nameData length];
            if (nameLength < 17) {
                Byte bytes[1];
                bytes[0] = 0x20;
                NSData *spaceData = [NSData dataWithBytes:bytes length:1];
                for (NSUInteger index = 0; index < 17 - nameLength; index++) {
                    [nameData appendData:spaceData];
                }
            }
            const u_int8_t *value = [nameData bytes];
            for (NSUInteger index = 0; index < 17; index++) {
                bytes[2 + index] = (Byte)value[index];
            }
            index = 19;
        }
            break;
        case OperationTypeUpdateDevice:{
            bytes[2] = 0x0E;
            bytes[3] = [self getFirmwareVersionByteWithOemType:self.lgPeripheral.oemType];
            index = 4;
        }
            break;
        case OperationTypeHand:{
            NSString *hand = object;
            //hand = [hand isEqualToString:@"1"] ? @"0":@"1";
            bytes[2] = (Byte)[hand integerValue];
            index = 3;
        }
            break;
        case OperationTypeReadSwingDetailData:{
            // 动作详情数据读取
            NSInteger timeStamp = [object[@"SwingDetail.DayUnixTimeStamp"] integerValue]/86400;
            bytes[2] = timeStamp/256;
            bytes[3] = timeStamp%256;
            NSInteger item = [object[@"SwingDetail.Index"] integerValue];
            bytes[4] = item / 256;
            bytes[5] = item % 256;
            YFPTLog(@"%x--%x-%x-%x-%x-%x",bytes[1],bytes[2],bytes[4],bytes[5],bytes[6],bytes[19]);
            index = 6;
        }
            break;
        case OperationTypeQuitRunTime:{
            bytes[2] = 0x02;
            index = 3;
            if (self.currenthandleBlock) {
                self.currenthandleBlock(YES, @{@"code":@"0",@"bleDesc":@""}, nil);
                self.currenthandleBlock = nil;
            }
            self.operationBlock = nil;
        }
            break;
        case OperationType3DData:{
            if (object != nil) {
                bytes[2] = (Byte)[object integerValue];
            }else {
                bytes[2] = 0x00;
            }
            index = 3;
        }
            break;
        default:
            index = 2;
            break;
    }
    for (NSUInteger indexT = index; index < 19; index++) {
        bytes[indexT] = 0x00;
    }
    bytes[19] = [YFBTHandler modulusValue:bytes countOfBytes:sizeof(bytes)];
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    return data;
}

- (Byte)head {
    return 0xA8;
}

- (Byte)getFirmwareVersionByteWithOemType:(OemType)type {
    return (Byte)type;
}

- (Byte)getFunctionCodeByOperationType:(OperationType)operationType {
    Byte functionByte = [YFBTHandler getFunctionCodeByOperationType:operationType];
    if (operationType == OperationTypeEnterRunTimeData) {
        [self performSelector:@selector(isReponsed) withObject:nil afterDelay:5.0];
    }else if (operationType == OperationTypeReadHomePageData){
        homePageArr = @[].mutableCopy;
    }
    return functionByte;
}
- (void)isReponsed {
    if (!isReponsed) {
        [self performOperationType:OperationTypeEnterRunTimeData object:nil completionBlock:self.operationBlock];
        isReponsed = NO;
    }
}
#pragma mark - private method
- (BOOL)checkModifyNameLength:(NSString *)name
{
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    if (nameData.length > 17) {
        return NO;
    }
    return YES;
}
- (void)defaultCharacteristicSetting {
    self.deviceNewNotifyCharacterstic = nil;
    self.deviceNewWriteCharacterstic = nil;
    self.deviceNewReadCharacterstic = nil;
    self.dfuMacReadCharacterstic = nil;
    self.dfuControlPointCharacterstic = nil;
}
- (void)checkIfAllReady {
    if (self.deviceNewNotifyCharacterstic && self.deviceNewWriteCharacterstic && self.deviceNewReadCharacterstic && self.connectBlock) {
        self.connectBlock(YES,nil);
        self.connectBlock = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kLGPeripheralDidConnect object:nil];
        [self stopScanningPeripherals];
        return;
    } else if (self.dfuMacReadCharacterstic && self.dfuControlPointCharacterstic && self.connectBlock) {
        self.connectBlock(YES,nil);
        self.connectBlock = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kLGPeripheralDidConnect object:nil];
        return;
    }
}

- (NSString *)convertNewMacAddressWithData:(NSData *)data
{
    if ([data length] != 6) {
        return nil;
    }
    const u_int8_t *bytes = [data bytes];
    NSMutableString *valueString = [[NSMutableString alloc] initWithString:@""];
    for (NSInteger index = [data length] - 1; index >= 0; index--) {
        u_int8_t value = bytes[index];
        u_int8_t firstValue = value/16;
        u_int8_t secondValue = value%16;
        NSString *toFirstValueString = [YFBTHandler toValueStringWithValue:firstValue];
        NSString *toSecondValueString = [YFBTHandler toValueStringWithValue:secondValue];
        [valueString appendString:toFirstValueString];
        [valueString appendString:toSecondValueString];
    }
    
    return valueString;
}
// 处理球拍返回的数据
- (void)handleData:(NSData *)data {
    YFPTLog(@"handle data:%@", data);
    if ([data length] > 3) {
        const u_int8_t *bytes = [data bytes];
//        Byte functionByte = bytes[1];
//        if (![self verifyValidData:data functionByte:functionByte]) {
//            if (self.operationBlock) {
//                self.operationBlock(NO, nil);
//                self.operationBlock = nil;
//            }
//            if (self.currenthandleBlock) {
//                self.currenthandleBlock(NO, nil, [YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleOperationCommandOrParameterIsIncorrect]);
//                self.currenthandleBlock = nil;
//            }
//        }
        switch (bytes[1]) {
            case 0x23:
                if (bytes[2] != 0x05) {
                    [homePageArr addObject:data];
                } else {
                    [homePageArr addObject:data];
                    self.operationBlock(YES,homePageArr);
                }
                return;
                break;
            case 0x24:
                if (bytes[2] == 0x00) {
                    isReponsed = YES;
                    self.operationBlock(YES, data);
                    return;
                }
                break;
            case 0x05:
                if (self.operationBlock) {
                    self.operationBlock(YES, data);
                    self.operationBlock = nil;
                }
                break;
            case 0x12:
                if (self.operationBlock) {
                    self.operationBlock(YES, data);
                    self.operationBlock = nil;
                }
                break;
            default:
                break;
        }
        if (self.operationBlock) {
            self.operationBlock(YES, data);
        }
    }
}
// 此方法有问题：暂时弃用
- (BOOL)verifyValidData:(NSData *)data functionByte:(Byte)functionByte {
    const u_int8_t *bytes = [data bytes];
    if (bytes[1] != functionByte) {
        return NO;
    }
    Byte verify = [YFBTHandler modulusValue:(Byte *)bytes countOfBytes:[data length]];
    if (verify == bytes[[data length] - 1]) {
        return YES;
    }
    return NO;
}
#pragma mark - error
+ (NSError *)errorDomainAndInfoWithErrorCode:(kYFBleErrorCode)code {
    switch (code) {
        case kYFBleCentralNotReadyErrorCode:
            return [NSError errorWithDomain:@"BLENotReadyErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey:@"Please turn on bluetooth and allow connection"}];
        case kYFBleNoServieErrorCode:
            return [NSError errorWithDomain:@"BLENoServieErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey:@"No Servie"}];
        case kYFBleTimeOutErrorCode:
            return [NSError errorWithDomain:@"BLETimeOutErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey:@"Connect Time Out"}];
        case kYFBleNotFoundUUIDErrorCode:
            return [NSError errorWithDomain:@"BLENotFoundUUIDErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey:@"Not found UUID"}];
        case kYFBleDeviceNameLengthMoreThan17Char:
            return [NSError errorWithDomain:@"BLEDeviceNameLengthMoreThan17CharErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey:@"The input device name is too long"}];
        case kYFBleOperationCommandOrParameterIsIncorrect:
            return [NSError errorWithDomain:@"BLEOpcodeOrParameterIsIncorrectErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey:@"Bluetooth opcode or parameter is incorrect"}];
        case kYFBleSensorResponseDataError:
            return [NSError errorWithDomain:@"BLESensorResponseDataErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey:@"BLE Sensor response data error,or response data equle null"}];
        default:
            break;
    }
}

#pragma mark - 具体操作
- (void)requestOperationType:(OperationType)operationType parmaObject:(id)object completionBlock:(BleHandleCompletionBlock)block {
    
    if (operationType == OperationType3DData && [object isEqual:@(4)]) {
        
    }else {
       self.currenthandleBlock = block;
    }
    [[YFCommunicationManager shareInstance] performOperationType:operationType object:object completionBlock:^(BOOL success, id feedbackData) {
        [YFBTHandler handleVerifyData:feedbackData withOperationType:operationType withCompletion:^(BOOL success, id response, NSError *error) {
            if (block) {
                block(success,response,error);
            }
        }];
    }];
}

@end


