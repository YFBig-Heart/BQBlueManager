//
//  YFBluetoothConstant_h
//  PaddleTennisDemo
//
//  Created by Coollang on 2017/10/11.
//  Copyright © 2017年 Coollang-YF. All rights reserved.
//

#ifndef YFBluetoothConstant_h
#define YFBluetoothConstant_h

typedef NS_ENUM(NSInteger, OemType) {
    OemTypeSquash = 0,
};

typedef NS_ENUM(NSInteger, HandDirectionType) {
    HandDirectionTypeForeward = 0,   // ForeHand
    HandDirectionTypeBackward = 1,   // BackHand
};

typedef enum : NSInteger {
    SportPoseTypeShaQiu = 4,       // 扣杀
    SportPoseTypeDangQiu = 5,      // 挡球
    SportPoseTypeTiaoQiu = 6,      // 挑
    SportPoseTypeGaoQiu = 7,       // 高球
    SportPoseTypeChouQiu = 8,      // 抽球
    SportPoseTypeCuoQiu = 9,       // 搓球
    SportPoseTypeDiaoQiu = 10,     // 吊球
    SportPoseTypeNonstandard = 11, //非标准
} SportPoseType;

typedef NS_ENUM(NSInteger, ServeDirectionType) {
    ServeDirectionTypeCenter = 0,   //出球方向 - 中
    ServeDirectionTypeLeft,         //出球方向 - 左
    ServeDirectionTypeRight,        //出球方向 - 右
};

typedef NS_ENUM(NSInteger, JCHandBallType) {
    JCHandBallTypeUp ,      // 上手球
    JCHandBallTypeDown      // 下手球
};

typedef NS_ENUM(NSUInteger, RequestType) {
    RequestTypeScan,             // 扫描
    RequestTypeRealTime,         // 实时
    PatternTypetransmission,     // 传输数据
    PatternTypeFree,             // 等待
};

typedef NS_ENUM(NSInteger, YFPeripheralConnectState) {
    YFPeripheralConnectNotReady,
    YFPeripheralConnectNoServie,
    YFPeripheralConnectSuccess,
};

#pragma mark - 设备常规操作
typedef NS_ENUM(NSUInteger, OperationType) {
    OperationTypePowerOff = 1,      // Power Off
    OperationTypeStandby,           // Standby
    OperationTypeRestartDevice,     // Reboot
    OperationTypeCleanData,         // Empty the cache
    OperationTypeResetDevice,       // Restore factory settings
    
    OperationTypeChangeDeviceName,  // Change device name
    OperationTypeBatteryRead,       // Read battery
    OperationTypeUpdateDevice,      // Firmware upgrade
    
    OperationTypeVerify,            // Calibration time
    
    OperationTypeHand,              // Set left and right hand
    OperationTypeDeviceVersion,     // Read the firmware version
    OperationTypeEnterRunTimeData,  // Enter Real-time mode
    OperationTypeQuitRunTime,       // Quit Real-time mode
    OperationTypeReadHomePageData,  // Read the home page data
    OperationTypeReadSwingDetailData, //Read the swing details data
    
    OperationType3DData,                // 3D挥拍轨迹数据读取
    OperationTypeProductionInformation, // 设备生产信息读取
    OperationTypeDevcieTest,            // 测试指令
};


typedef void(^BleCompletionBlock)(BOOL success,NSError *error);
typedef void(^BleHandleCompletionBlock)(BOOL success,id response,NSError *error);



#endif /* YFBluetoothConstant_h */
