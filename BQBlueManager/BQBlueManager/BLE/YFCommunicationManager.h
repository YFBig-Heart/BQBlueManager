//
//  YFCommunicationManager.h
//  PaddleTennisDemo
//
//  Created by Coollang on 2017/10/11.
//  Copyright © 2017年 Coollang-YF. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YFBluetoothConstant.h"
#import "LGBluetooth.h"

typedef NS_ENUM(NSInteger, kYFBleErrorCode) {
    kYFBleCentralNotReadyErrorCode = -3001,
    kYFBleNoServieErrorCode = -3002,
    kYFBleTimeOutErrorCode  = -3003,
    kYFBleNotFoundUUIDErrorCode = -3004,
    // The name is too long
    kYFBleDeviceNameLengthMoreThan17Char = -3005,
    // Operation command or parameter is incorrect
    kYFBleOperationCommandOrParameterIsIncorrect = -3006,
    // BLE Sensor response data error,or response data equle null
    kYFBleSensorResponseDataError = -3007,
};

typedef void(^OperationBlock)(BOOL success, id feedbackData);
typedef void(^DiscoverPerpheralsCallback)(NSArray *peripherals,NSError *error);
typedef void(^BleConnectBlock)(BOOL success,NSError *error);

@interface YFCommunicationManager : NSObject

@property (nonatomic, strong) LGPeripheral *lgPeripheral;
@property (nonatomic, strong) LGCentralManager *lgCenterManager;
@property (nonatomic, assign, readonly) BOOL isPeripheralConnected;
@property (nonatomic, assign, readonly) BOOL isCentralReady;
@property (nonatomic, assign, readonly) BOOL isDFUMode;

@property (nonatomic, strong) NSNumber *batteryValue;
@property (nonatomic, strong) NSString *modifyName;
@property (nonatomic, assign) BOOL shouldRetryConnect;

+ (instancetype)shareInstance;
+ (NSError *)errorDomainAndInfoWithErrorCode:(kYFBleErrorCode)code;

- (void)startScanPeripheralsWithBlock:(DiscoverPerpheralsCallback)scanBlock;
- (void)stopScanningPeripherals;


- (void)connectPeripheral:(LGPeripheral *)peripheral completion:(BleConnectBlock)block;
- (void)reconnetDeviceCompletion:(BleConnectBlock)block;
- (void)reConnectPeripheralUUID:(NSUUID *)uuid completion:(BleConnectBlock)block;
- (void)disconnectThePeripheralWithCompletionBlock:(BleConnectBlock)block;


#pragma mark - Bluetooth operation

/**
 param operationType : Bluetooth operation type
 param object: Used to pass parameters to the device
    **Note:
       *1. operationType == OperationTypeReadSwingDetailData
        Parameter format (E.g):  @{@"SwingDetail.Index":@(1), @"SwingDetail.DayUnixTimeStamp",@(1507680000)}
 
       *2. operationType == OperationTypeChangeDeviceName
         Parameter format (E.g): @"PaddleTennis"
 
       *3. operationType == OperationTypeHand
         Parameter format (E.g): @"0"  0->rightHand, 1-> leftHand
 return void
 */
- (void)requestOperationType:(OperationType)operationType parmaObject:(id)object completionBlock:(BleHandleCompletionBlock)block;



@end
