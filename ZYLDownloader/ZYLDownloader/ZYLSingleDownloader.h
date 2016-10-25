//
//  ZYLSingleDownloader.h
//  ZYLDownloader
//
//  Created by zyl on 16/9/20.
//  Copyright © 2016年 zyl. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ZYLDownloaderState) {
    ZYLDownloaderStateUnStart,
    ZYLDownloaderStateRunning,
    ZYLDownloaderStatePause,
    ZYLDownloaderStateFail,
    ZYLDownloaderStateSuccess,
    ZYLDownloaderStateDeleted
};

@class ZYLSingleDownloader;

@protocol ZYLSingleDownloaderDelegate <NSObject>

@optional

/**
 * 文件开始下载
 */
- (void)downloaderBeginWithDownloader:(ZYLSingleDownloader *)downloader;

/**
 * 文件下载失败
 */
- (void)downloaderFailedWithDownloader:(ZYLSingleDownloader *)downloader;

/**
 * 文件下载暂停
 */
- (void)downloaderPauseWithDownloader:(ZYLSingleDownloader *)downloader;

/**
 * 文件下载完成
 */
- (void)downloaderFinishedWithDownloader:(ZYLSingleDownloader *)downloader;

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

@interface ZYLSingleDownloader : NSObject

/**
 * 下载链接
 */
@property (copy, nonatomic) NSString *downloadUrl;

/**
 * 文件类型
 */
@property (copy, nonatomic) NSString *fileType;

/**
 * 文件名
 */
@property (copy, nonatomic) NSString *filename;

/**
 * 记录存储在tmp路径的文件名
 */
@property (copy, nonatomic) NSString *tmpFilename;

/**
 * 下载进度
 */
@property (assign, nonatomic) float downloaderProgress;

/**
 * 记录下载器是否已经存储到数据库
 */
@property (assign, nonatomic) BOOL isExistInRealm;

/**
 * 记录是否被强制下载，暂停或者继续下载
 */
@property (assign, nonatomic) BOOL isHand;

/**
 * 标记下载器的状态
 */
@property (assign, nonatomic) ZYLDownloaderState downloaderState;

/**
 * 下载状态的代理
 */
@property (weak, nonatomic) id <ZYLSingleDownloaderDelegate> downloaderDelegate;

/**
 * 开始下载
 */
- (void)start;

/**
 * 暂停下载
 */
- (void)pauseisHand:(BOOL)isHand;

/**
 * 继续下载
 */
- (void)resumeisHand:(BOOL)isHand;

/**
 * 删除下载器前判断下载器的下载状态，根据不同的状态处理下载器
 */
- (void)judgeDownloaderStateToHandel;

/**
 * 取消当前的下载线程
 */
- (void)cancelRorOtherDownloader;

@end
