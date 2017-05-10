//
//  ZYLDownloader.h
//  ZYLDownloader
//
//  Created by zyl on 16/9/20.
//  Copyright © 2016年 zyl. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ZYLSingleDownloader.h"
#import "ZYLSingleDownloaderModel.h"

@protocol ZYLDownloaderDelegate <NSObject>

@optional

/**
 * 文件开始下载
 */
- (void)downloaderBeginWithDownloader:(NSString *)downloaderUrl;

/**
 * 文件下载失败
 */
- (void)downloaderFailedWithDownloader:(NSString *)downloaderUrl;

/**
 * 文件下载暂停
 */
- (void)downloaderPauseWithDownloader:(NSString *)downloaderUrl;

/**
 * 文件下载完成
 */
- (void)downloaderFinishedWithDownloader:(NSString *)downloaderUrl;

/**
 * 文件的下载进度
 */
- (void)downloaderRate:(float)rate withDownloaderUrl:(NSString *)downloaderUrl;

/**
 * 文件下载的状态
 */
- (void)downloaderState:(ZYLDownloaderState)state andDownloaderUrl:(NSString *)downloaderUrl;

/**
 * 文件下载的速度,这里返回的当前每秒下载的数据量，单位是B
 */
- (void)downloaderSpeed:(NSInteger)speed andDownloaderUrl:(NSString *)downloaderUrl;

@end

@interface ZYLDownloader : NSObject

/**
 * 创建下载器单例
 */
+ (instancetype)sharedDownloader;

/**
 * 销毁下载器单例
 */
+ (void)destoryDownloader;

/**
 * 拿到下载链接开始下载，要求传入文件名称和文件类型(mp4/3gp/mp3/doc/zip...)，isHand表示是否优先下载
 */
- (void)startDownloadWithDownloadUrl:(NSString *)downloadUrl filename:(NSString *)filename fileType:(NSString *)fileType isHand:(BOOL)isHand;

/**
 * 暂停下载某一个
 */
- (void)pauseDownloaderWithDownloadUrl:(NSString *)downloadUrl;

/**
 * 继续下载某一个
 */
- (void)resumeDownloaderWithDownloadUrl:(NSString *)downloadUrl;

/**
 * 获取某一个下载的文件信息
 */
- (ZYLSingleDownloaderModel *)getDownloaderInfoWithDownloaderUrl:(NSString *)downloaderUrl;

/**
 * 获取数据库中所有的下载信息
 */
- (NSArray<ZYLSingleDownloaderModel *> *)getAllDownloadersInfo;

/**
 * 删除某一个下载的信息
 */
- (void)deleteDownloaderInfoWithDownloderUrl:(NSString *)downloaderUrl;

/**
 * 更新数据库中的某个数据的文件名或者文件类型
 */
- (void)updateDownloaderInfoWithDownloderUrl:(NSString *)downloaderUrl withFilename:(NSString *)filename fileType:(NSString *)fileType;

/**
 * 下载器的代理
 */
@property (weak, nonatomic) id <ZYLDownloaderDelegate> zylDownloaderDelegate;

/**
 * 同时下载的最大的文件数量
 */
@property (assign, nonatomic) NSInteger maxDownloaderNum;

@end
