//
//  ZYLTool.h
//  ZYLDownloader
//
//  Created by zyl on 16/9/9.
//  Copyright © 2016年 zyl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZYLTool : NSObject

/**
 * 检查是否是有效的http或者https链接
 */
+ (BOOL)checkIsUrlAtString:(NSString *)url;

/**
 * 检查对象是否为空
 */
+ (BOOL)checkIsEmpty:(id)objective;

/**
 * 编码文件名
 */
+ (NSString *)encodeFilename:(NSString *)filename;

/**
 * 解码文件名
 */
+ (NSString *)decodeFilename:(NSString *)filename;

@end
