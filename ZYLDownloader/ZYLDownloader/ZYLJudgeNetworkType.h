//
//  ZYLJudgeNetworkType.h
//  CNRMobilePhoneTV
//
//  Created by zyl on 16/10/23.
//  Copyright © 2016年 央广视讯. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const networkUnknown;
extern NSString *const networkIsWIFI;
extern NSString *const networkIsWWAN;
extern NSString *const networkINotReachable;
extern NSString *const ZYLCurrentNetworkType;

typedef void(^networkBlock)(NSString *networkType);

@interface ZYLJudgeNetworkType : NSObject

/**
 * 判断当前网络类型，要借助AFN，提前导入
 */
+ (void)judgeNetworkTypeIs:(networkBlock)networkType;

@end
