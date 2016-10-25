//
//  ZYLTool.m
//  ZYLDownloader
//
//  Created by zyl on 16/9/9.
//  Copyright © 2016年 zyl. All rights reserved.
//

#import "ZYLTool.h"

@implementation ZYLTool

+ (BOOL)checkIsUrlAtString:(NSString *)url {
    NSString *pattern = @"http(s)?://([\\w-]+\\.)+[\\w-]+(/[\\w- ./?%&=]*)?";
    
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:nil];
    NSArray *regexArray = [regex matchesInString:url options:0 range:NSMakeRange(0, url.length)];
    
    if (regexArray.count > 0) {
        return YES;
    }else {
        return NO;
    }
}

+ (BOOL)checkIsEmpty:(id)objective {
    BOOL isE = YES;
    if (objective == nil || [objective isEqual:[NSNull null]] || [[NSString stringWithFormat:@"%@", objective] isEqualToString:@""]) {
        isE = YES;
    } else {
        isE = NO;
    }
    
    return isE;
}

+ (NSString *)encodeFilename:(NSString *)filename {
    NSData *data = [filename dataUsingEncoding:NSUTF8StringEncoding];
    NSString *encodeFilename = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    
    return encodeFilename;
}

+ (NSString *)decodeFilename:(NSString *)filename {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:filename options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSString *decodeFilename = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return decodeFilename;
}

@end
