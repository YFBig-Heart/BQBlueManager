//
//  YFBTHandler.h
//  PaddleTennisDemo
//
//  Created by Coollang on 2017/10/11.
//  Copyright © 2017年 Coollang-YF. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YFBluetoothConstant.h"

typedef void(^GetBatteryBlock)(NSInteger batteryValue);

#define DEBUG_yf 0
#if DEBUG_yf == 0 // 调式阶段
#define YFPTLog(...)  NSLog(__VA_ARGS__)
#elif DEBUG_yf == 1 // 发布阶段
#define YFPTLog(...)
#endif


@interface YFBTHandler : NSObject

+ (NSString *)toValueStringWithValue:(u_int8_t)value;
+ (Byte)modulusValue:(Byte *)bytes countOfBytes:(NSInteger)size;
+ (Byte)getFunctionCodeByOperationType:(OperationType)operationType;

#pragma mark - private method
+ (void)handleVerifyData:(id)data withOperationType:(OperationType)type withCompletion:(BleHandleCompletionBlock)block;

@end
