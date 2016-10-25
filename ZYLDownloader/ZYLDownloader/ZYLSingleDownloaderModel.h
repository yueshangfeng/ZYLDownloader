//
//  ZYLSingleDownloaderModel.h
//  ZYLDownloader
//
//  Created by zyl on 16/9/8.
//  Copyright © 2016年 zyl. All rights reserved.
//

#import <Realm/Realm.h>

@interface ZYLSingleDownloaderModel : RLMObject

@property NSString *downloadUrl;

@property NSString *fileType;

@property NSString *filename;

@property float downloaderProgress;

@property NSString *localUrl;

@property BOOL isExistInRealm;

@end

// This protocol enables typed collections. i.e.:
// RLMArray<ZYLSingleDownloaderModel>
RLM_ARRAY_TYPE(ZYLSingleDownloaderModel)
