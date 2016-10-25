//
//  ZYLSingleDownloaderModel.m
//  ZYLDownloader
//
//  Created by zyl on 16/9/8.
//  Copyright © 2016年 zyl. All rights reserved.
//

#import "ZYLSingleDownloaderModel.h"

@implementation ZYLSingleDownloaderModel

// Specify default values for properties

//将downloadUrl设置为主key
+ (NSString *)primaryKey {
    return @"downloadUrl";
}

//+ (NSDictionary *)defaultPropertyValues
//{
//    return @{};
//}

// Specify properties to ignore (Realm won't persist these)

+ (NSArray *)ignoredProperties
{
    return @[@"localUrl", @"isExistInRealm"];
}

@end
