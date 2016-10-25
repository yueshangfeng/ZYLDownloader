//
//  ZYLJudgeNetworkType.m
//  CNRMobilePhoneTV
//
//  Created by zyl on 16/10/23.
//  Copyright © 2016年 zyl. All rights reserved.
//

#import "ZYLJudgeNetworkType.h"
#import "AFNetworkReachabilityManager.h"

NSString *const networkUnknown = @"Unknown";
NSString *const networkIsWIFI = @"WIFI";
NSString *const networkIsWWAN = @"WWAN";
NSString *const networkINotReachable = @"NotReachable";
NSString *const ZYLCurrentNetworkType = @"currentNetworkType";

@implementation ZYLJudgeNetworkType

+ (void)judgeNetworkTypeIs:(networkBlock)networkType {
    __block BOOL isCheck = YES;//判断是否在请求当前网络类型，YES是，NO不是
    __block __weak AFNetworkReachabilityManager * manager = [AFNetworkReachabilityManager sharedManager];
    [manager startMonitoring];
    [manager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        NSString *netWorkTypeStr = nil;
        if (status ==  AFNetworkReachabilityStatusUnknown) {
            netWorkTypeStr = networkUnknown;
        } else if (status == AFNetworkReachabilityStatusNotReachable) {
            netWorkTypeStr = networkINotReachable;
            
        } else if (status == AFNetworkReachabilityStatusReachableViaWWAN) {
            netWorkTypeStr = networkIsWWAN;
            //使用手机流量
        } else if (status == AFNetworkReachabilityStatusReachableViaWiFi) {
            netWorkTypeStr = networkIsWIFI;
            //WIFI
        } else {
            netWorkTypeStr = networkUnknown;
            //未知
        }
        
        [self setNetworkType:netWorkTypeStr];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isCheck == YES) {
                networkType(netWorkTypeStr);
                
                isCheck = NO;
            }
        });
    }];
}

+ (void)setNetworkType:(NSString *)type {
    [[NSUserDefaults standardUserDefaults] setObject:type forKey:ZYLCurrentNetworkType];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
