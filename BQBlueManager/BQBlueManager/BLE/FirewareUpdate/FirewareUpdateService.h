//
//  FirewareUpdateService.h
//  PaddleTennisDemo
//
//  Created by Coollang on 2017/10/16.
//  Copyright © 2017年 Coollang-YF. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YFBluetoothConstant.h"

@interface FirewareUpdateService : NSObject

+ (instancetype)sharedInstance;

/**
 * zh:从网络上获取最新硬件版本号，用于检测或更新
 * en:Get the latest hardware version number from the network for detection or updating
 */
- (void)getDeviceServerVersionWithOemType:(OemType )oemType callBack:(void(^)(BOOL success, NSString *serviceVersion,NSString *remark,NSString *versionDateTime))callBlock;

/**
 * zh:从网络上下载最新的安装包,用于升级硬件
 * en:Download the latest installation package from the network for upgrading hardware
 */
- (void)downLoadSensorFileWithCallBack:(void(^)(BOOL downloadSuccess,NSURL *selectedFileURL,NSError *info))block;

@end
