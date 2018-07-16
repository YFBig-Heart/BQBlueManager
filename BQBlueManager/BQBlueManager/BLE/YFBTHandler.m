//
//  YFBTHandler.m
//  PaddleTennisDemo
//
//  Created by Coollang on 2017/10/11.
//  Copyright © 2017年 Coollang-YF. All rights reserved.
//

#import "YFBTHandler.h"
#import "YFCommunicationManager.h"


@implementation YFBTHandler

+ (void)handleVerifyData:(id)data withOperationType:(OperationType)type withCompletion:(BleHandleCompletionBlock)block {
    if (type == OperationTypeReadHomePageData && [data isKindOfClass:[NSArray class]]) {
        [self handleHomePageData:data completed:^(NSDictionary *HomePageData) {
            if (HomePageData) {
                block(YES,HomePageData,nil);
            }
        }];
    }else {
        if (![data isKindOfClass:[NSData class]] ) {
            return;
        }
        Byte functionCode = [self getFunctionCodeByOperationType:type];
        const u_int8_t *bytes = [data bytes];
        if ([data length] == 20) {
            if (bytes[1] == functionCode) {
                switch (type) {
                    case OperationTypeDeviceVersion:
                        block(YES,[self deviceVersionAndBatteryData:data],nil);
                        break;
                    case OperationTypeBatteryRead:
                        block(YES,[self deviceBatteryData:data],nil);
                        break;
                    case OperationTypeHand:
                        block(YES,[self handleHandData:data],nil);
                        break;
                    case OperationTypeEnterRunTimeData:
                        block(YES,[self handleRuntimeData:data],nil);
                        break;
                    case OperationTypeReadSwingDetailData:{
                        [self handleSportDetailData:data completed:^(NSDictionary *swingDetalDict) {
                            if (swingDetalDict) {
                                block(YES,swingDetalDict,nil);
                            }else {
                                block(NO,nil,[YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleSensorResponseDataError]);
                            }
                        }];
                    }
                        break;
                    case OperationTypeReadHomePageData:
                        break;
                    case OperationType3DData:{
                        [self handleSport3DData:data completed:^(NSDictionary *swing3DDatalDict) {
                            if (swing3DDatalDict) {
                                block(YES,swing3DDatalDict,nil);
                            }else {
                                block(NO,nil,[YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleSensorResponseDataError]);
                            }
                        }];
                    }
                        break;
                    default:
                        block(YES,@{@"code":@"0",@"bleDesc":@""},nil);
                        break;
                }
            }else{
                block(NO,nil,[YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleSensorResponseDataError]);
            }
        }else{
            block(NO,nil,[YFCommunicationManager errorDomainAndInfoWithErrorCode:kYFBleSensorResponseDataError]);
        }
    }
}

// 设备版本号电量
+ (id)deviceVersionAndBatteryData:(NSData *)data {
    Byte bytes[6];
    const u_int8_t *dataBytes = [data bytes];
    for (NSInteger i = 0; i < 6; i++) {
        bytes[i] = dataBytes[i+2];
    }
    NSData *versionData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSString * version = [[NSString alloc] initWithData:versionData encoding:NSUTF8StringEncoding];
    NSInteger battery = dataBytes[17];
    return @{
             @"code":@"0",
             @"bleDesc":@{
                     @"version":version,
                     @"battery":@(battery),
                     }
             };
}
// 设备电量
+ (id)deviceBatteryData:(NSData *)data {
    const u_int8_t *bytes = [data bytes];
    return @{@"code":@"0",
             @"bleDesc":@{@"battery":@(bytes[2])},
             };
}
// 设置正反手
+ (id)handleHandData:(NSData *)data {
    const u_int8_t *dataBytes = [data bytes];
    NSInteger hand = dataBytes[2];
    return @{@"code":@"0",
             @"bleDesc":@{@"hand":@(hand)},
             };
}
// 处理实时数据
+ (id)handleRuntimeData:(NSData *)data {
    const u_int8_t *bytes = [data bytes];
    SportPoseType actionType = SportPoseTypeShaQiu;
    NSInteger swingSpeed = 0;
    CGFloat strength = 0;
    NSInteger swingTime = 0; // 挥拍时间，单位ms
    NSInteger hitBallTime = 0; // 击球时间，单位ms
    
    /*挥拍属性*/
    NSInteger areaValue = 0; //击球区域
    HandDirectionType handType; // 正反手方向
    ServeDirectionType serveDirectionType; // 出球方向
    JCHandBallType handBallType; // 上下手方向
    BOOL isHitBall = NO;// 是否击中球
    
    NSTimeInterval timeStamp = 0; // 时间戳

    // actionType:动作类型  swingSpeed:挥拍速度  strength:挥拍力量,swingTime:挥拍时间ms hitBallTime:击球时间ms  isHitBall: 有没有击中球 areaValue:击球区域   handType: 正反手 serveDirectionType: 出球方向 handBallType：上下手 timeStamp：时间戳
    if (bytes[2] == 0x01) {
        actionType = [self parseActionType:bytes[3]];// 挥拍类型
        swingSpeed = bytes[4] * 256 + bytes[5];
        strength = (bytes[6] *256 + bytes[7]) * 0.1;
        swingTime = bytes[8] * 10;
        hitBallTime = bytes[9] * 10;
        
        Byte property = bytes[10];
        isHitBall = property & (0x01 << 4)?YES:NO;
        handBallType = property & (0x01 << 3) ? JCHandBallTypeDown:JCHandBallTypeUp;
        handType = property & (0x01 << 2) ? HandDirectionTypeBackward:HandDirectionTypeForeward;
        serveDirectionType = property & (0x03 << 0);
        areaValue = property >> 5;
        
        timeStamp = bytes[11]*256*256*256 + bytes[12]*256*256 + bytes[13]*256 + bytes[14];
        // 第二步
        return @{@"code":@"1",
                 @"bleDesc":@{
                         @"actionType":@(actionType),
                         @"swingSpeed":@(swingSpeed),
                         @"strength":@(strength),
                         @"swingTime":@(swingTime),
                         @"hitBallTime":@(hitBallTime),
                         @"isHitBall":@(isHitBall),
                         @"areaValue":@(areaValue),
                         @"handType":@(handType),
                         @"serveDirectionType":@(serveDirectionType),
                         @"handBallType":@(handBallType),
                         @"timeStamp":@(timeStamp),
                         },
                 };
    }else if (bytes[2] == 0x00){
        // 第一步
        return @{@"code":@"0",
                 @"bleDesc":@"Enter Real time Success",
                 };
    }else {
        return nil;
    }
}
+ (void)handleHomePageData:(NSMutableArray <NSData *>*)homePageArr completed:(void(^)(NSDictionary *HomePageData))block{
    if (![homePageArr isKindOfClass:[NSArray class]]) {
        block(nil);
        return;
    }
    NSMutableArray *sportItems = @[].mutableCopy;
    NSMutableDictionary *sportDict = nil;
    for (NSData *data in homePageArr) {
        const u_int8_t *bytes = [data bytes];
        if (data.length != 20 || bytes[1] != 0x23) {
            continue;
        }
        if (bytes[2] == 0x01) {
            //step1
            sportDict = [NSMutableDictionary dictionary];
            NSString *dateTimeStamp = [@((bytes[3] * 256 + bytes[4]) * 86400) stringValue];
            NSInteger exerciseTimeInterval = bytes[5] * 256 + bytes[6];
            NSInteger dayAmountOfCount = bytes[7] * 256 + bytes[8]; // 挥拍总数
            NSInteger avgSpeed = bytes[10] * 256 +bytes[11]; // 平均挥速
            NSInteger foreHandCount = bytes[12] * 256 +bytes[13]; // 正手次数
            [sportDict setObject:dateTimeStamp forKey:@"dateTimeStamp"];
            [sportDict setObject:@(exerciseTimeInterval) forKey:@"exerciseTimeInterval"];
            [sportDict setObject:@(dayAmountOfCount) forKey:@"dayAmountOfCount"];
            [sportDict setObject:@(avgSpeed) forKey:@"avgSpeed"];
            [sportDict setObject:@(foreHandCount) forKey:@"foreHandCount"];
        } else if (bytes[2] == 0x02) {
            //step2
            if (!sportDict) {
                sportDict = [NSMutableDictionary dictionary];
            }
            // 上高球
            NSInteger upForeGaoQiuCount = bytes[3] * 256 +bytes[4];
            NSInteger upBackGaoQiuCount = bytes[5] * 256 +bytes[6];
            // 上杀球
            NSInteger upForeShaQiuCount = bytes[7] * 256 +bytes[8];
            NSInteger upBackShaQiuCount = bytes[9] * 256 +bytes[10];
            // 上吊球
            NSInteger upForeDiaoQiuCount = bytes[11] * 256 +bytes[12];
            NSInteger upBackDiaoQiuCount = bytes[13] * 256 +bytes[14];
            // 下挑球
            NSInteger downForeTiaoQiuCount = bytes[15] * 256 +bytes[16];
            NSInteger downBackTiaoQiuCount = bytes[17] * 256 +bytes[18];
            
            [sportDict setObject:@(upForeGaoQiuCount) forKey:@"upForeGaoQiuCount"];
            [sportDict setObject:@(upBackGaoQiuCount) forKey:@"upBackGaoQiuCount"];
            
            [sportDict setObject:@(upForeShaQiuCount) forKey:@"upForeShaQiuCount"];
            [sportDict setObject:@(upBackShaQiuCount) forKey:@"upBackShaQiuCount"];
            
            [sportDict setObject:@(upForeDiaoQiuCount) forKey:@"upForeDiaoQiuCount"];
            [sportDict setObject:@(upBackDiaoQiuCount) forKey:@"upBackDiaoQiuCount"];
            
            [sportDict setObject:@(downForeTiaoQiuCount) forKey:@"downForeTiaoQiuCount"];
            [sportDict setObject:@(downBackTiaoQiuCount) forKey:@"downBackTiaoQiuCount"];
        }else if (bytes[2] == 0x03){
            if (!sportDict) {
                sportDict = [NSMutableDictionary dictionary];
            }
            // 下抽球
            NSInteger downForeChouQiuCount = bytes[3] * 256 +bytes[4];
            NSInteger downBackChouQiuCount = bytes[5] * 256 +bytes[6];
            // 上挡球
            NSInteger upForeDangQiuCount = bytes[7] * 256 +bytes[8];
            NSInteger upBackDangQiuCount = bytes[9] * 256 +bytes[10];
            // 下挡球
            NSInteger downForeDangQiuCount = bytes[11] * 256 +bytes[12];
            NSInteger downBackDangQiuCount = bytes[13] * 256 +bytes[14];
            // 下搓球
            NSInteger downForeCuoQiuCount = bytes[15] * 256 +bytes[16];
            NSInteger downBackCuoQiuCount = bytes[17] * 256 +bytes[18];
            [sportDict setObject:@(downForeChouQiuCount) forKey:@"downForeChouQiuCount"];
            [sportDict setObject:@(downBackChouQiuCount) forKey:@"downBackChouQiuCount"];
            
            [sportDict setObject:@(upForeDangQiuCount) forKey:@"upForeDangQiuCount"];
            [sportDict setObject:@(upBackDangQiuCount) forKey:@"upBackDangQiuCount"];
            
            [sportDict setObject:@(downForeDangQiuCount) forKey:@"downForeDangQiuCount"];
            [sportDict setObject:@(downBackDangQiuCount) forKey:@"downBackDangQiuCount"];
            
            [sportDict setObject:@(downForeCuoQiuCount) forKey:@"downForeCuoQiuCount"];
            [sportDict setObject:@(downBackCuoQiuCount) forKey:@"downBackCuoQiuCount"];
        }else if (bytes[2] == 0x04){
            if (!sportDict) {
                sportDict = [NSMutableDictionary dictionary];
            }
            // 上非标球
            NSInteger upForeNotStandQiuCount = bytes[3] * 256 +bytes[4];
            NSInteger upBackNotStandQiuCount = bytes[5] * 256 +bytes[6];
            // 下非标球
            NSInteger downForeNotStandQiuCount = bytes[7] * 256 +bytes[8];
            NSInteger downBackNotStandQiuCount = bytes[9] * 256 +bytes[10];
            [sportDict setObject:@(upForeNotStandQiuCount) forKey:@"upForeNotStandQiuCount"];
            [sportDict setObject:@(upBackNotStandQiuCount) forKey:@"upBackNotStandQiuCount"];
            [sportDict setObject:@(downForeNotStandQiuCount) forKey:@"downForeNotStandQiuCount"];
            [sportDict setObject:@(downBackNotStandQiuCount) forKey:@"downBackNotStandQiuCount"];
            NSTimeInterval minTimeInterval = [[YFBTHandler formateString:@"2017-11-01 00:00:00"] timeIntervalSince1970];
            if ([sportDict[@"dateTimeStamp"] longLongValue] > minTimeInterval) {
                [sportItems addObject:sportDict];
            }
        }else if (bytes[2] == 0x05) {
            [sportItems sortUsingComparator:^NSComparisonResult(NSDictionary * _Nonnull obj1, NSDictionary *_Nonnull obj2) {
                return [obj1[@"dateTimeStamp"] longLongValue] < [obj2[@"dateTimeStamp"] longLongValue];
            }];
            block(@{@"code":@"0",
                    @"bleDesc":sportItems,
                    });
        }
    }
}

+ (void)handleSportDetailData:(NSData *)data completed:(void(^)(NSDictionary *swingDetalDict))block {
    const u_int8_t *bytes = [data bytes];
    if (bytes[2] == 0x01) {
        SportPoseType actionType = [self parseActionType:bytes[3]];
        NSInteger swingSpeed = bytes[4] * 256 + bytes[5];
        CGFloat strength = (bytes[6] * 256 + bytes[7]) * 0.1;
        NSInteger swingTime = bytes[8] * 10;
        NSInteger hitBallTime = bytes[9] * 10;
        NSString *timeStamp = [@(bytes[10] * 256 * 256 * 256 + bytes[11] * 256 * 256 + bytes[12] * 256 + bytes[13]) stringValue];
        
        //挥拍属性
        Byte property = bytes[15];
        BOOL isHitBall = property & (0x01 << 4) ? YES:NO;
        JCHandBallType handBallType = property & (0x01 << 3) ? JCHandBallTypeDown:JCHandBallTypeUp;
        HandDirectionType handType = property & (0x01 << 2) ? HandDirectionTypeBackward:HandDirectionTypeForeward;
        ServeDirectionType serveDirectionType = property & (0x03 << 0);
        NSInteger areaValue = property >> 5;
        
        NSInteger indexK = bytes[17] * 256 + bytes[18];
        block(@{@"code":@"0",
                 @"bleDesc":@{
                         @"actionType":@(actionType),
                         @"swingSpeed":@(swingSpeed),
                         @"strength":@(strength),
                         @"swingTime":@(swingTime),
                         @"hitBallTime":@(hitBallTime),
                         @"isHitBall":@(isHitBall),
                         @"areaValue":@(areaValue),
                         @"handType":@(handType),
                         @"serveDirectionType":@(serveDirectionType),
                         @"handBallType":@(handBallType),
                         @"timeStamp":timeStamp,
                         @"indexK":@(indexK)
                         },
                 });
    } else if (bytes[2] == 0x02){
        block(@{
                @"code":@"1",
                @"bleDesc":@"Read Completed",
                });
    }
}

+ (void)handleSport3DData:(NSData *)data completed:(void(^)(NSDictionary *swing3DDatalDict))block {
    
    const u_int8_t *bytes = [data bytes];
    NSMutableDictionary *sporDict = nil;
    if (bytes[2] == 0x00) {
        block(@{
                @"code":@"0",
                @"bleDesc":@"Enter 3D Success!",
                });
    }else if (bytes[2] == 0x01){
        sporDict = [NSMutableDictionary dictionary];
        NSInteger groupCount = bytes[3]; // 总包数
        SportPoseType actionType = [self parseActionType:bytes[4]];
        NSInteger swingSpeed = bytes[5] * 256 + bytes[6];
        CGFloat strength = (bytes[7] * 256 + bytes[8]) * 0.1;
        NSInteger swingTime = bytes[9] * 10;
        NSString *timeStamp = [@(bytes[10] * 256 * 256 * 256 + bytes[11] * 256 * 256 + bytes[12] * 256 + bytes[13]) stringValue];
        //挥拍属性
        Byte property = bytes[14];
        BOOL isHitBall = property & (0x01 << 4) ? YES:NO;
        JCHandBallType handBallType = property & (0x01 << 3) ? JCHandBallTypeDown:JCHandBallTypeUp;
        HandDirectionType handType = property & (0x01 << 2) ? HandDirectionTypeBackward:HandDirectionTypeForeward;
        ServeDirectionType serveDirectionType = property & (0x03 << 0);
        NSInteger areaValue = property >> 5;
        
        //有效数(开始ID):指3D有效数据曲线的开始下标
        NSInteger validDataStartId = bytes[15];
        // 指3D有效数据曲线的结束下标(3D曲线的总点数包含结束ID这点的数据在内)
        NSInteger validDataEndId = bytes[16];
        
        //  最大拍速ID:最大挥拍速度对应的数据下标(作为分割完整一拍数据的分割点，
        //  前半拍(引拍):0<= 引拍 <最大拍速ID;后半拍(收拍):最大拍速ID<= 收拍 <数据总包数)
        NSInteger maxSpeedId = bytes[17];
        
        block(@{
                @"code":@"1",
                @"bleDesc":@{
                        @"groupCount":@(groupCount),
                        @"actionType":@(actionType),
                        @"swingSpeed":@(swingSpeed),
                        @"strength":@(strength),
                        @"swingTime":@(swingTime),
                        @"timeStamp":timeStamp,
                        @"isHitBall":@(isHitBall),
                        @"handBallType":@(handBallType),
                        @"handType":@(handType),
                        @"serveDirectionType":@(serveDirectionType),
                        @"areaValue":@(areaValue),
                        @"startID":@(validDataStartId),
                        @"endID":@(validDataEndId),
                        @"maxSpeedId":@(maxSpeedId),
                        },
                });
    }else if (bytes[2] == 0x02){
        // 一包一包的数据
        NSString *q0,*q1,*q2,*q3;
        NSString *gx,*gy,*gz;
        NSInteger ax,ay,az;
        // q0~q3:放大了 100 倍。
        CGFloat factor = 0.01;
        CGFloat qq0 = ((int8_t)(bytes[3])) * factor;
        CGFloat qq1 = ((int8_t)(bytes[4])) * factor;
        CGFloat qq2 = ((int8_t)(bytes[5])) * factor;
        CGFloat qq3 = ((int8_t)(bytes[6])) * factor;
        float recip = sqrt(qq0 * qq0 + qq1 * qq1 + qq2 * qq2 + qq3 * qq3);
        qq0 = qq0 / recip;
        qq1 = qq1 / recip;
        qq2 = qq2 / recip;
        qq3 = qq3 / recip;
        q0 = [NSString stringWithFormat:@"%f",qq0];
        q1 = [NSString stringWithFormat:@"%f",qq1];
        q2 = [NSString stringWithFormat:@"%f",qq2];
        q3 = [NSString stringWithFormat:@"%f",qq3];
        
        gx = @([self converHexWithHighByte:bytes[7] lowByte:bytes[8]]).stringValue;
        gy = @([self converHexWithHighByte:bytes[9] lowByte:bytes[10]]).stringValue;
        gz = @([self converHexWithHighByte:bytes[11] lowByte:bytes[12]]).stringValue;
        
        ax = [self converHexWithHighByte:bytes[13] lowByte:bytes[14]] / 4;
        ay = [self converHexWithHighByte:bytes[15] lowByte:bytes[16]] / 4;
        az = [self converHexWithHighByte:bytes[17] lowByte:bytes[18]] / 4;
        
        NSInteger indexI = bytes[19];
        /*
        第i包:发送到第几包数据，i≥0 (0为第一包). 连续发送包数等于总的数据包数(i == 总包数-1)时停止返回。
        补充说明:DTW曲线和评分功能的数据为重力分量(vx,vy,vz),重力分量由四元数q0~q3通过公式算出来，
        公式为:vx =(q1*q3 - q0*q2)*196， vy =(q0*q1 + q2*q3)*196，vz =(q0*q0 - 0.5 + q3*q3)*196 DTW的数据总包数 = 数据总包数
         */
        block(@{
                @"code":@"2",
                @"bleDesc":@{
                        @"q0":q0,
                        @"q1":q1,
                        @"q2":q2,
                        @"q3":q3,
                        @"gx":gx,
                        @"gy":gy,
                        @"gz":gz,
                        @"ax":@(ax),
                        @"ay":@(ay),
                        @"az":@(az),
                        @"indexI":@(indexI),
                        },
                });
    }else if (bytes[2] == 0x03){
        // 整拍3D数据完成返回
        NSInteger indexK = bytes[3]*256 + bytes[4];
        block(@{@"code":@"3",
                @"bleDesc":@{@"indexK":@(indexK)}
                });
    }
}

+ (NSDate *)formateString:(NSString *)string
{
    static NSDateFormatter *dateFormatter = nil;
    if (dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    }
    return [dateFormatter dateFromString:string];
}

/**
 双字节正负数转换
 */
+ (NSInteger)converHexWithHighByte:(Byte)hightByte lowByte:(Byte)lowByte{
    
    BOOL isPositive = hightByte & (0x01 << 7)?NO:YES;//判断符号位
    if (isPositive) {//正数
        return (hightByte * 256 + lowByte);
    }
    else{//负数
        hightByte = hightByte ^ 0xff;
        lowByte = lowByte ^ 0xff;;
        return -((hightByte *256 + lowByte)+1);
    }
}

#pragma mark - 一些数据计算
+ (NSString *)toValueStringWithValue:(u_int8_t)value {
    switch (value) {
        case 0:
        case 1:
        case 2:
        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
        case 8:
        case 9:
            return [@(value) stringValue];
            break;
        case 10:
            return @"A";
            break;
        case 11:
            return @"B";
            break;
        case 12:
            return @"C";
            break;
        case 13:
            return @"D";
            break;
        case 14:
            return @"E";
            break;
        case 15:
            return @"F";
            break;
        default:
            return @"";
            break;
    }
}
+ (Byte)getFunctionCodeByOperationType:(OperationType)operationType {
    Byte functionByte = '\0';
    switch (operationType) {
        case OperationTypePowerOff:
            functionByte = 0x01;
            break;
        case OperationTypeRestartDevice:
            functionByte = 0x02;
            break;
        case OperationTypeCleanData:
            functionByte = 0x03;
            break;
        case OperationTypeResetDevice:
            functionByte = 0x04;
            break;
        case OperationTypeUpdateDevice:
            functionByte = 0x05;
            break;
        case OperationTypeVerify:
            functionByte = 0x11;
            break;
        case OperationTypeChangeDeviceName:
            functionByte = 0x12;
            break;
        case OperationTypeHand:
            functionByte =0x13;
            break;
        case OperationTypeDeviceVersion:
            functionByte = 0x21;
            break;
        case OperationTypeBatteryRead:
            functionByte = 0x22;
            break;
        case OperationTypeReadHomePageData:
            //homePageArr = @[].mutableCopy;
            functionByte =0x23;
            break;
        case OperationTypeEnterRunTimeData:
            //[self performSelector:@selector(isReponsed) withObject:nil afterDelay:5.0];
            functionByte = 0x24;
            break;
        case OperationTypeQuitRunTime:
            functionByte = 0x24;
            break;
        case OperationTypeReadSwingDetailData:
            functionByte = 0x25;
            break;
        case OperationType3DData:
            functionByte = 0x27;
            break;
        case OperationTypeProductionInformation:
            functionByte = 0x28;
            break;
        case OperationTypeDevcieTest:
            functionByte = 0E0;
            break;
        default:
            break;
    }
    return functionByte;
}

+ (SportPoseType)parseActionType:(NSInteger)actionType {
    switch (actionType) {
        case 0x04:
            return SportPoseTypeShaQiu;
            break;
        case 0x05:
            return SportPoseTypeDangQiu;
            break;
        case 0x06:
            return SportPoseTypeTiaoQiu;
            break;
        case 0x07:
            return SportPoseTypeGaoQiu;
            break;
        case 0x08:
            return SportPoseTypeChouQiu;
            break;
        case 0x09:
            return SportPoseTypeCuoQiu;
            break;
        case 0x10:
            return SportPoseTypeDiaoQiu;
            break;
        case 0x11:
            return SportPoseTypeNonstandard;
            break;
        default:
            break;
    }
    return SportPoseTypeShaQiu;
}
// 获得对256求模的值
+ (Byte)modulusValue:(Byte *)bytes countOfBytes:(NSInteger)size
{
    NSUInteger total = 0;
    for (NSInteger index = 0; index < size - 1; index++) {
        total += bytes[index];
    }
    return total % 256;
}
@end
