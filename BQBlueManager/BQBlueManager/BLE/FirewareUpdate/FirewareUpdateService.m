//
//  FirewareUpdateService.m
//  PaddleTennisDemo
//
//  Created by Coollang on 2017/10/16.
//  Copyright © 2017年 Coollang-YF. All rights reserved.
//

#import "FirewareUpdateService.h"

@interface FirewareUpdateService ()
@property (nonatomic, strong) NSURL *selectedFileURL;
//@property (nonatomic, copy)NSString *downloadFilePath;
/** 最新的下载地址 */
@property (nonatomic, copy)NSString *filedownloadPath;
@property (nonatomic, copy)NSString *cachePath;
@end

@implementation FirewareUpdateService

static FirewareUpdateService *_firewareUpdateServiceInstance;

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _firewareUpdateServiceInstance = [super allocWithZone:zone];
    });
    return _firewareUpdateServiceInstance;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _firewareUpdateServiceInstance = [[self alloc] init];
    });
    return _firewareUpdateServiceInstance;
}

- (id)copyWithZone:(NSZone *)zone {
    return _firewareUpdateServiceInstance;
}

- (void)getDeviceServerVersionWithOemType:(OemType )oemType callBack:(void(^)(BOOL success, NSString *serviceVersion,NSString *remark,NSString *versionDateTime))callBlock {
    [FirewareUpdateService getDeviceServerVersionWithOemType:oemType callBack:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *errorT = nil;
        id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&errorT];
        if ([result[@"ret"] isEqualToString:@"0"]) {
            NSString *filedownloadPath = result[@"errDesc"][@"Path"];
            NSString *serviceVersion = result[@"errDesc"][@"Version"];
            NSString *Remark = result[@"errDesc"][@"Version"];
            NSString *VersionDateTime = result[@"errDesc"][@"VersionDateTime"];
            self.filedownloadPath = filedownloadPath;
            callBlock(YES,serviceVersion,Remark,VersionDateTime);
        }else {
            callBlock(NO,nil,nil,nil);
        }
    }];
}

+ (void)getDeviceServerVersionWithOemType:(OemType )oemType callBack:(void(^)(NSData *data, NSURLResponse *response, NSError *error))callBack {
    NSURL *downloadurl = [NSURL URLWithString:[NSString stringWithFormat:@"http://pt.coollang-overseas.com/VersionController/getLastVersion?oemType=%@",[FirewareUpdateService PIDwithOemType:oemType]]];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:downloadurl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15];
    urlRequest.HTTPMethod = @"POST";
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataDask = [session dataTaskWithRequest:urlRequest completionHandler:callBack];
    [dataDask resume];
}

+ (NSString *)PIDwithOemType:(OemType)oemType
{
    switch (oemType) {
        case OemTypeSquash:
            return @"SS";
            break;
        default:
            break;
    }
}

- (void)downLoadSensorFileWithCallBack:(void(^)(BOOL downloadSuccess,NSURL *selectedFileURL,NSError *info))block {
    if (self.filedownloadPath == nil || self.filedownloadPath.length == 0) {
        return;
    }
    [self getfirewaveIpdateDataFileWithPath:self.filedownloadPath startUpdate:block];
}

- (void)getfirewaveIpdateDataFileWithPath:(NSString *)downloadPath startUpdate:(void(^)(BOOL downloadSuccess,NSURL *selectedFileURL,NSError *info))startUpdate {
    
    if (downloadPath == nil || downloadPath.length == 0) {
        return;
    }
    NSURL *downloadurl = [NSURL URLWithString:downloadPath];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:downloadurl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15];
    urlRequest.HTTPMethod = @"GET";
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataDask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            if (startUpdate) {
                startUpdate(NO,nil,error);
            }
            return;
        }else {
            NSString *path = NSTemporaryDirectory();
            NSString *fileName = [NSString stringWithFormat:@"PaddleTennis%@",response.URL.lastPathComponent];
            path = [path stringByAppendingPathComponent:fileName];
            self.cachePath = fileName;
            [data writeToFile:path atomically:YES];
            [self onFileSelected:[NSURL fileURLWithPath:path]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                startUpdate(YES,self.selectedFileURL,nil);
            });
        }
    }];
    [dataDask resume];
    
}

- (void)onFileSelected:(NSURL *)filePathUrl {
    if (filePathUrl != nil) {
        NSURL *url = filePathUrl;
        NSString *selectedFileName = url.lastPathComponent;
        NSString *extensionStr = [selectedFileName substringFromIndex: [selectedFileName length] - 3];
        if (!([extensionStr isEqualToString:@"zip"])) {
            return;
        }
        self.selectedFileURL = url;
    }else {
        NSLog(@"Selected file not exist!");
    }
}
- (void)clearInstallationPackage {
    if (self.cachePath != nil && self.cachePath.length != 0) {
        NSFileManager *fileManager =  [NSFileManager defaultManager];
        NSError *error;
        NSString *path = NSTemporaryDirectory();
        path = [path stringByAppendingPathComponent:self.cachePath];
        [fileManager removeItemAtPath:path error:&error];
        self.cachePath = nil;
    }
}


@end
