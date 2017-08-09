//
//  ZYLSingleDownloader.m
//  ZYLDownloader
//
//  Created by zyl on 16/9/20.
//  Copyright © 2016年 zyl. All rights reserved.
//  http://stackoverflow.com/questions/39346231/answer/submit
//  https://forums.developer.apple.com/thread/24770

#import "ZYLSingleDownloader.h"

#import "ZYLTool.h"
#import <CoreGraphics/CoreGraphics.h>
#import "ZYLJudgeNetworkType.h"
#import <UIKit/UIKit.h>

@interface ZYLSingleDownloader () <NSURLSessionDelegate, NSURLSessionDownloadDelegate>

//下载任务
@property (strong, nonatomic) NSURLSessionDownloadTask *downloadTask;

//下载设置
@property (weak, nonatomic) NSURLSession *downloadSession;

//文件管理器
@property (strong, nonatomic) NSFileManager *fileManager;

//标记是否开始下载
@property (assign, nonatomic) BOOL isBeginDownload;

//继续下载数据
@property (strong, nonatomic) NSData *resumeData;

//标记是否取得了继续下载的数据
@property (assign, nonatomic) BOOL isGetResumeData;

//记录tmp文件的范围
@property (assign, nonatomic) NSRange libraryFilenameRange;

//记录当前继续下载的数据
@property (strong, nonatomic) NSMutableString *resumeString;

//记录上一次下载的数据大小
@property (assign, nonatomic) int64_t lastDownloadSize;

//存储未下载完成的数据的路径
@property (copy, nonatomic) NSString *unDownloadStr;

//系统存储未下载完成的数据对应的文件的路径
@property (copy, nonatomic) NSString *libraryUnDownloadStr;

//存储接续下载数据的路径
@property (copy, nonatomic) NSString *resumeDirectoryStr;

//计算下载速度的定时器
@property (strong, nonatomic) NSTimer *speedTimer;

//记录当前下载的数据量
@property (assign, nonatomic) NSInteger currentWriten;

//记录上一次下载的数据量
@property (assign, nonatomic) NSInteger lastWritten;

//标记是否发送下载器的各种状态
@property (assign, nonatomic) BOOL isSendState;

//记录是否是让出线程而暂停
@property (assign, nonatomic) BOOL isConcede;

@end

@implementation ZYLSingleDownloader

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.isBeginDownload = NO;
        self.isExistInRealm = YES;
        self.downloaderProgress = 0.0;
        self.downloaderState = ZYLDownloaderStateUnStart;
        [self.downloaderDelegate downloaderState:self.downloaderState andDownloaderUrl:self.downloadUrl];
        self.isGetResumeData = NO;
        self.lastDownloadSize = 0;
        self.isHand = NO;
        self.isSendState = YES;
        self.isConcede = NO;
    }
    return self;
}

-(void)dealloc {
    NSLog(@"单个下载器销毁了");
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    
}

- (instancetype)valueForUndefinedKey:(NSString *)key {
    return nil;
}

#pragma mark - 关于下载***********************************************************
#pragma mark - 开始下载***********************************************************
- (void)start {
    //判断网络状况
    if ([[self judgeNetworkType] isEqualToString:networkUnknown] || [[self judgeNetworkType] isEqualToString:networkINotReachable]) {
        //没有网络
        NSLog(@"没有网络无法下载");
    } else {
        //有网络
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.downloadUrl]];
        self.downloadTask = [self.downloadSession downloadTaskWithRequest:request];
        [self.downloadTask resume];
    }
    
}

#pragma mark - 暂停下载***********************************************************
- (void)pauseisHand:(BOOL)isHand {
    if (self.downloadTask == nil || [self.downloadTask isEqual:[NSNull null]]) {
        NSLog(@"这个任务还没有创建");
        return;
    }
    
    if (self.downloadTask.state == NSURLSessionTaskStateRunning) {
        self.isHand = isHand;
        [self.downloadTask suspend];
        if (self.downloaderState != ZYLDownloaderStateDeleted) {
            self.downloaderState = ZYLDownloaderStatePause;
            [self.downloaderDelegate downloaderState:self.downloaderState andDownloaderUrl:self.downloadUrl];
        }
        [self.downloaderDelegate downloaderPauseWithDownloader:self];
    } else if (self.downloadTask.state == NSURLSessionTaskStateSuspended || self.downloadTask.state == NSURLSessionTaskStateCanceling || self.downloadTask.state == NSURLSessionTaskStateCompleted) {
        NSLog(@"这个任务已经处于暂停状态、取消状态或者完成状态，无法暂停下载");
    }
}

#pragma mark - 继续下载***********************************************************
- (void)resumeisHand:(BOOL)isHand {
    if ([[self judgeNetworkType] isEqualToString:networkUnknown] || [[self judgeNetworkType] isEqualToString:networkINotReachable]) {
        //没有网络
        NSLog(@"没有网络，无法继续下载");
    } else {
        //首先判断下载进度，已经下载完成的不执行继续下载
        if (self.downloaderProgress >= 1.0) {
            //下载已经完成
            NSLog(@"此下载已经完成，无法继续下载");
            return;
        }
        
        if (self.downloaderProgress == 0) {
            NSLog(@"此任务还没有开启，无法下载");
            return;
        }
        
        if (self.isConcede == YES) {
            self.isHand = isHand;
            self.downloaderState = ZYLDownloaderStateRunning;
            [self.downloaderDelegate downloaderState:self.downloaderState andDownloaderUrl:self.downloadUrl];
            self.downloadTask = [self.downloadSession downloadTaskWithResumeData:[self getCorrectResumeData:self.resumeData]];
            [self.downloadTask resume];
            self.isConcede = NO;
            
            return;
        }
        
        if (self.downloadTask == nil || [self.downloadTask isEqual:[NSNull null]]) {
            NSLog(@"这个任务还没有创建");
            //数据库里有数据但是任务还没有被创建，可以判定为是继续下载的任务，此时应该重新创建任务，获取继续下载此任务的信息
            //创建继续下载的任务
            self.isHand = isHand;
            [self createResumeDownloadTask];
            
            return;
        }
        
        //判断下载任务的状态
        if (self.downloadTask.state == NSURLSessionTaskStateRunning || self.downloadTask.state == NSURLSessionTaskStateCompleted || self.downloadTask.state == NSURLSessionTaskStateCanceling) {
            //正在进行或者已经完成
            
            //判断下载器当前的下载状态，决定继续下载的方案
            if (self.downloaderState == ZYLDownloaderStateFail) {
                //数据下载失败了，是在没有继续下载数据的前提下
                //继续下载任务
                self.isHand = YES;
                [self resumeAtNoResumeData];
            } else {
                NSLog(@"这个下载任务正在进行、已经完成或者已经被取消，无法继续下载");
            }
            
        } else if (self.downloadTask.state == NSURLSessionTaskStateSuspended) {
            self.isHand = YES;
            [self.downloadTask resume];
        }
    }
    
}

#pragma mark - 判断网络类型
- (NSString *)judgeNetworkType {
    return [[NSUserDefaults standardUserDefaults] objectForKey:ZYLCurrentNetworkType];
}

#pragma mark - 在没有系统提供的继续下载数据的情况下继续下载
- (void)resumeAtNoResumeData {
    [_downloadSession invalidateAndCancel];
    _downloadSession = nil;
    //去本地读取继续下载数据
    self.resumeData = [NSData dataWithContentsOfFile:self.resumeDirectoryStr];
    //将继续下载的数据移动到对应的目录下
    NSError *error = nil;
    if ([self.fileManager fileExistsAtPath:self.libraryUnDownloadStr]) {
        BOOL isS = [self.fileManager removeItemAtPath:self.libraryUnDownloadStr error:&error];
        if (!isS) {
            //移除失败
            NSLog(@"移除library下的继续下载数据对应的文件失败:%@", error);
        }
    }
    
    BOOL isS = [self.fileManager copyItemAtPath:self.unDownloadStr toPath:self.libraryUnDownloadStr error:&error];
    if (!isS) {
        //拷贝失败
        NSLog(@"拷贝继续下载文件到library下失败:%@", error);
    } else {
        //拷贝成功后开启继续下载
        if ([[[UIDevice currentDevice] systemVersion] floatValue] < 9.0) {
            //创建下载任务，继续下载
            self.downloadTask = [self.downloadSession downloadTaskWithResumeData:self.resumeData];
        } else {
            NSData *newData = [self getCorrectResumeData:self.resumeData];
            //创建下载任务，继续下载
            self.downloadTask = [self.downloadSession downloadTaskWithResumeData:newData];
        }
        
        [self.downloadTask resume];
    }
}

#pragma mark - 创建继续下载的任务
- (void)createResumeDownloadTask {
    if (self.downloadTask) {
        self.downloadTask = nil;
    }
    self.resumeData = nil;
    [_downloadSession invalidateAndCancel];
    NSURLSessionConfiguration *sessionCon = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:self.downloadUrl];
    _downloadSession = [NSURLSession sessionWithConfiguration:sessionCon delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    __weak __typeof(self)(weakSelf) = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //检查resumeData
        if (weakSelf.resumeData == nil) {
            //没有获取到系统提供的resumeData
            [weakSelf resumeAtNoResumeData];
        }
    });
}

#pragma mark - 删除下载前根据下载的状态处理下载器
- (void)judgeDownloaderStateToHandel {
    self.isSendState = NO;
    [self destorySpeedTimer];
    [self.downloadTask cancel];
    [_downloadSession invalidateAndCancel];
    self.isBeginDownload = NO;
    
    self.downloaderState = ZYLDownloaderStateDeleted;
    [self.downloaderDelegate downloaderState:self.downloaderState andDownloaderUrl:self.downloadUrl];
}

#pragma mark - 取消当前下载的线程，让路其他线程
- (void)cancelRorOtherDownloader {
    if (self.downloaderState != ZYLDownloaderStateRunning) {
        NSLog(@"此状态不允许暂停");
        return;
    }
    self.isConcede = YES;
    self.isHand = YES;
    [_downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        
    }];
}

#pragma mark - 关于下载的定时器***********************************************************
#pragma mark - 开启定时器
/*************************************************************************/
- (void)openSpeedTimer {
    self.speedTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(calculateSpeed) userInfo:nil repeats:YES];
}

#pragma mark - 销毁定时器
- (void)destorySpeedTimer {
    [self.speedTimer invalidate];
    self.speedTimer = nil;
}

#pragma mark - 计算下载速度
- (void)calculateSpeed {
    if (self.isSendState == YES) {
        [self.downloaderDelegate downloaderSpeed:self.currentWriten - self.lastWritten andDownloaderUrl:self.downloadUrl];
        self.lastWritten = self.currentWriten;
    }
}

#pragma mark - 关于下载代理***********************************************************
#pragma mark - 文件下载完成
/*************************************************************************/
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSLog(@"文件下载完成");
    NSString *path = [NSString stringWithFormat:@"%@.%@", [[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:@"ZYLDownloads"]stringByAppendingPathComponent:[ZYLTool encodeFilename:self.downloadUrl]], self.fileType];
    NSLog(@"文件路径是:%@", path);
    NSURL *documentsDirectoryURL = [NSURL fileURLWithPath:path isDirectory:NO];
    BOOL isS = [self.fileManager moveItemAtURL:location toURL:documentsDirectoryURL error:nil];
    if (isS) {
        //移动成功
        NSLog(@"下载完成的文件已经成功移动到documents路径下");
    } else {
        //移动失败
        NSLog(@"下载完成的文件移动到documents路径下失败");
    }
    
    //告知下载控制器已经系在完成
    self.downloaderState = ZYLDownloaderStateSuccess;
    self.downloaderProgress = 1.000000;
    [self.downloaderDelegate downloaderState:self.downloaderState andDownloaderUrl:self.downloadUrl];
    [self.downloaderDelegate downloaderFinishedWithDownloader:self];
    [self.downloaderDelegate downloaderRate:1.000000 withDownloaderUrl:self.downloadUrl];
}

#pragma mark - 下载进度
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.currentWriten = (NSInteger)totalBytesWritten;
    self.downloaderProgress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    if (self.isSendState == YES) {
        [self.downloaderDelegate downloaderRate:self.downloaderProgress withDownloaderUrl:self.downloadUrl];
    }
    
    if (self.isBeginDownload == NO) {
        //还没有开始下载
        self.isBeginDownload = YES;
        [self.downloaderDelegate downloaderBeginWithDownloader:self];
        //判断本地是否有继续下载的数据，只有在本地没有resumeData数据的时候才硬性获取继续下载的数据备用
        if ([self.fileManager fileExistsAtPath:self.resumeDirectoryStr]) {
            //存在
            NSLog(@"此下载存在继续下载数据，不再获取继续下载数据");
            [self parseResumeData:self.resumeData];
        } else {
            //不存在
            //在这里取得继续下载的数据
            [self getOriginalResumeData];
        }
        
        [self openSpeedTimer];
        
    } else {
        //已经开始下载了
        
    }
    
    if (self.downloaderState != ZYLDownloaderStateDeleted) {
        
        
        if (self.downloaderState != ZYLDownloaderStateRunning) {
            if (self.isSendState == YES) {
                [self.downloaderDelegate downloaderState:ZYLDownloaderStateRunning andDownloaderUrl:self.downloadUrl];
            }
        }
        
        self.downloaderState = ZYLDownloaderStateRunning;
    }
    
    
    //每下载1M的文件则迁移一次未下载完成的数据到Document
    if (self.isSendState == YES) {
        CGFloat addSize = (totalBytesWritten - self.lastDownloadSize) / 1024.0 / 1024.0;
        if (addSize >= 1.0) {
            //下载的量大于1M,迁移
            NSError *error = nil;
            if ([self.fileManager fileExistsAtPath:self.unDownloadStr]) {
                //存在则删除
                [self.fileManager removeItemAtPath:self.unDownloadStr error:nil];
            }
            BOOL isS = [self.fileManager copyItemAtPath:self.libraryUnDownloadStr toPath:self.unDownloadStr error:&error];
            if (isS) {
                //NSLog(@"移动成功");
            } else {
                NSLog(@"移动失败%@", error);
            }
            
            self.lastDownloadSize = totalBytesWritten;
        }
    }
    
    //下载完成后移除本地的文件
    if (self.isSendState == YES) {
        if (totalBytesWritten == totalBytesExpectedToWrite) {
            //下载完成后通知
            [self.downloaderDelegate downloaderFinishedWithDownloader:self];
            self.downloaderState = ZYLDownloaderStateSuccess;
            [self.downloaderDelegate downloaderState:self.downloaderState andDownloaderUrl:self.downloadUrl];
            [self destorySpeedTimer];
            
            NSError *error = nil;
            BOOL isS = [self.fileManager removeItemAtPath:self.unDownloadStr error:&error];
            if (!isS) {
                //移除失败
                NSLog(@"移除继续下载的数据文件失败:%@", error);
            }
            //移除继续下载数据
            isS = [self.fileManager removeItemAtPath:self.resumeDirectoryStr error:&error];
            if (!isS) {
                //移除失败
                NSLog(@"移除继续下载的数据失败:%@", error);
            }
        }
    }
}

#pragma mark - 获取首次继续下载的数据
- (void)getOriginalResumeData {
    [self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        //到代理中获取resumeData，此处获取的resumeData在iOS10和Xcode8中有可能无法使用，shit！
    }];
}

#pragma mark - 继续下载时已经下载的数据和总数据大小
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    NSLog(@"继续下载已经下载的数据：%lld,数据总量：%lld", fileOffset, expectedTotalBytes);
}

#pragma mark - URLSession任务完成
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        
        if (self.isConcede == YES) {
            //是否存在继续下载数据
            if ([error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData]){
                self.resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
                self.downloaderState = ZYLDownloaderStatePause;
                [self.downloaderDelegate downloaderState:self.downloaderState andDownloaderUrl:self.downloadUrl];
            } else {
                
            }
            
            return;
        }
        
        NSLog(@"URLSession任务失败");
        [self.downloaderDelegate downloaderFailedWithDownloader:self];
        //告知下载控制器下载失败
        if (self.downloadTask == nil || [self.downloadTask isEqual:[NSNull null]]) {
            //是否存在继续下载数据
            if ([error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData]) {
                //有继续下载的数据
                self.resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
                //判断系统版本
                if ([[[UIDevice currentDevice] systemVersion] floatValue] < 9.0) {
                    //创建下载任务，继续下载
                    self.downloadTask = [self.downloadSession downloadTaskWithResumeData:self.resumeData];
                } else {
                    //获取正确的resumeData
                    NSData *newData = [self getCorrectResumeData:self.resumeData];
                    //创建下载任务，继续下载
                    self.downloadTask = [self.downloadSession downloadTaskWithResumeData:newData];
                }
                
                [self.downloadTask resume];
                
                //分析继续下载数据
                [self parseResumeData:self.resumeData];
            } else {
                //由于网络故障导致的下载失败
                //没有继续下载的数据
                if (self.downloaderState != ZYLDownloaderStateDeleted) {
                    self.downloaderState = ZYLDownloaderStateFail;
                    self.isHand = YES;
                    [self.downloaderDelegate downloaderState:self.downloaderState andDownloaderUrl:self.downloadUrl];
                }
                NSLog(@"没有继续下载的数据");
                //更新本地继续下载数据
                [self updateLocalResumeData];
            }
            
        } else {
            //由于主动取消下载导致的下载失败，在这里获取resumeData并保存在沙盒目录中
            if (self.downloaderState != ZYLDownloaderStateDeleted) {
                self.downloaderState = ZYLDownloaderStateFail;
            }
            
            if ([error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData]) {
                //有继续下载的数据
                self.resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
                
                if ([[[UIDevice currentDevice] systemVersion] floatValue] < 9.0) {
                    //创建下载任务，继续下载
                    self.downloadTask = [self.downloadSession downloadTaskWithResumeData:self.resumeData];
                } else {
                    //获取正确的resumeData
                    NSData *newData = [self getCorrectResumeData:self.resumeData];
                    //创建下载任务，继续下载
                    self.downloadTask = [self.downloadSession downloadTaskWithResumeData:newData];
                }
                
                [self.downloadTask resume];
                
                //分析继续下载的数据
                [self parseResumeData:self.resumeData];
                
            } else {
                //没有继续下载的数据
                if (self.downloaderState != ZYLDownloaderStateDeleted) {
                    self.downloaderState = ZYLDownloaderStateFail;
                    self.isHand = YES;
                    [self.downloaderDelegate downloaderState:self.downloaderState andDownloaderUrl:self.downloadUrl];
                }
                
                NSLog(@"没有继续下载的数据");
                //更新本地继续下载数据
                if (self.downloaderState != ZYLDownloaderStateDeleted) {
                    [self updateLocalResumeData];
                }
                
            }
        }
    } else {
        
    }
}

#pragma mark - 分析继续下载数据
- (void)parseResumeData:(NSData *)resumeData {
    NSString *XMLStr = [[NSString alloc] initWithData:resumeData encoding:NSUTF8StringEncoding];
    self.resumeString = [NSMutableString stringWithFormat:@"%@", XMLStr];
    
    //判断系统，iOS8以前和以后
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 9.0) {
        //iOS8包含iOS8以前
        NSRange tmpRange = [XMLStr rangeOfString:@"NSURLSessionResumeInfoLocalPath"];
        NSString *tmpStr = [XMLStr substringFromIndex:tmpRange.location + tmpRange.length];
        NSRange oneStringRange = [tmpStr rangeOfString:@"CFNetworkDownload_"];
        NSRange twoStringRange = [tmpStr rangeOfString:@".tmp"];
        self.tmpFilename = [tmpStr substringWithRange:NSMakeRange(oneStringRange.location, twoStringRange.location + twoStringRange.length - oneStringRange.location)];
        
    } else {
        //iOS8以后
        NSRange tmpRange = [XMLStr rangeOfString:@"NSURLSessionResumeInfoTempFileName"];
        NSString *tmpStr = [XMLStr substringFromIndex:tmpRange.location + tmpRange.length];
        NSRange oneStringRange = [tmpStr rangeOfString:@"<string>"];
        NSRange twoStringRange = [tmpStr rangeOfString:@"</string>"];
        //记录tmp文件名
        self.tmpFilename = [tmpStr substringWithRange:NSMakeRange(oneStringRange.location + oneStringRange.length, twoStringRange.location - oneStringRange.location - oneStringRange.length)];
    }
    
    //有数据，保存到本地
    //存储数据
    BOOL isS = [resumeData writeToFile:self.resumeDirectoryStr atomically:NO];
    if (isS) {
        //继续存储数据成功
        NSLog(@"继续存储数据成功");
    } else {
        //继续存储数据失败
        NSLog(@"继续存储数据失败");
    }
    
}

#pragma mark - 更新沙盒目录缓存的继续下载数据
- (void)updateLocalResumeData {
    if (self.downloaderState == ZYLDownloaderStateDeleted) {
        return;
    }
    
    if (self.resumeString == nil) {
        return;
    }
    
    //在这创建resumeData
    //首先取出沙盒目录下的缓存文件
    NSData *libraryData = [NSData dataWithContentsOfFile:self.unDownloadStr];
    NSInteger libraryLength = libraryData.length;
    
    //计算当期表示resumeData数据大小的range
    //记录tmp文件大小范围
    NSRange integerRange = [self.resumeString rangeOfString:@"NSURLSessionResumeBytesReceived"];
    NSString *integerStr = [self.resumeString substringFromIndex:integerRange.location + integerRange.length];
    NSRange oneIntegerRange = [integerStr rangeOfString:@"<integer>"];
    NSRange twonIntegerRange = [integerStr rangeOfString:@"</integer>"];
    self.libraryFilenameRange = NSMakeRange(oneIntegerRange.location + oneIntegerRange.length + integerRange.location + integerRange.length, twonIntegerRange.location - oneIntegerRange.location - oneIntegerRange.length);
    //用新的数据替换
    [self.resumeString replaceCharactersInRange:self.libraryFilenameRange withString:[NSString stringWithFormat:@"%ld", (long)libraryLength]];
    
    NSData *newResumeData = [self.resumeString dataUsingEncoding:NSUTF8StringEncoding];
    self.resumeData = newResumeData;
    
    //同时保存在本地一份
    //获取存储路径
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:@"ZYLResumeDownloads"];
    //获取文件名
    NSString *resumeFileName = [path stringByAppendingPathComponent:[@"resume_" stringByAppendingString:[ZYLTool encodeFilename:self.downloadUrl]]];
    //存储数据
    BOOL isS = [self.resumeData writeToFile:resumeFileName atomically:NO];
    if (isS) {
        //继续存储数据成功
        NSLog(@"继续存储数据成功");
    } else {
        //继续存储数据失败
        NSLog(@"继续存储数据失败");
    }
}

#pragma mark - 获取正确的resumeData 
- (NSData *)getCorrectResumeData:(NSData *)resumeData {
    NSData *newData = nil;
    NSString *kResumeCurrentRequest = @"NSURLSessionResumeCurrentRequest";
    NSString *kResumeOriginalRequest = @"NSURLSessionResumeOriginalRequest";
    //获取继续数据的字典
    NSMutableDictionary* resumeDictionary = [NSPropertyListSerialization propertyListWithData:resumeData options:NSPropertyListMutableContainers format:NULL error:nil];
    //重新编码原始请求和当前请求
    resumeDictionary[kResumeCurrentRequest] = [self correctRequestData:resumeDictionary[kResumeCurrentRequest]];
    resumeDictionary[kResumeOriginalRequest] = [self correctRequestData:resumeDictionary[kResumeOriginalRequest]];
    newData = [NSPropertyListSerialization dataWithPropertyList:resumeDictionary format:NSPropertyListBinaryFormat_v1_0 options:NSPropertyListMutableContainers error:nil];
    
    return newData;
}

#pragma mark - 编码继续请求字典中的当前请求数据和原始请求数据
- (NSData *)correctRequestData:(NSData *)data {
    NSData *resultData = nil;
    NSData *arData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (arData != nil) {
        return data;
    }
    
    NSMutableDictionary *archiveDict = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:nil error:nil];
    
    int k = 0;
    NSMutableDictionary *oneDict = [NSMutableDictionary dictionaryWithDictionary:archiveDict[@"$objects"][1]];
    while (oneDict[[NSString stringWithFormat:@"$%d", k]] != nil) {
        k += 1;
    }
    
    int i = 0;
    while (oneDict[[NSString stringWithFormat:@"__nsurlrequest_proto_prop_obj_%d", i]] != nil) {
        NSString *obj = oneDict[[NSString stringWithFormat:@"__nsurlrequest_proto_prop_obj_%d", i]];
        if (obj != nil) {
            [oneDict setObject:obj forKey:[NSString stringWithFormat:@"$%d", i + k]];
            [oneDict removeObjectForKey:obj];
            archiveDict[@"$objects"][1] = oneDict;
        }
        i += 1;
    }
    
    if (oneDict[@"__nsurlrequest_proto_props"] != nil) {
        NSString *obj = oneDict[@"__nsurlrequest_proto_props"];
        [oneDict setObject:obj forKey:[NSString stringWithFormat:@"$%d", i + k]];
        [oneDict removeObjectForKey:@"__nsurlrequest_proto_props"];
        archiveDict[@"$objects"][1] = oneDict;
    }
    
    NSMutableDictionary *twoDict = [NSMutableDictionary dictionaryWithDictionary:archiveDict[@"$top"]];
    if (twoDict[@"NSKeyedArchiveRootObjectKey"] != nil) {
        [twoDict setObject:twoDict[@"NSKeyedArchiveRootObjectKey"] forKey:[NSString stringWithFormat:@"%@", NSKeyedArchiveRootObjectKey]];
        [twoDict removeObjectForKey:@"NSKeyedArchiveRootObjectKey"];
        archiveDict[@"$top"] = twoDict;
    }
    
    resultData = [NSPropertyListSerialization dataWithPropertyList:archiveDict format:NSPropertyListBinaryFormat_v1_0 options:NSPropertyListMutableContainers error:nil];
    
    return resultData;
}

#pragma mark - getter***********************************************************
#pragma mark -
/*************************************************************************/
- (NSURLSession *)downloadSession {
    if (_downloadSession == nil) {
        NSURLSessionConfiguration *sessionCon = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:self.downloadUrl];
        
        self.downloadSession = [NSURLSession sessionWithConfiguration:sessionCon delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return _downloadSession;
}

- (NSFileManager *)fileManager {
    if (_fileManager == nil) {
        _fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}

- (NSString *)unDownloadStr {
    if (_unDownloadStr == nil) {
        _unDownloadStr = [[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:@"ZYLUnDownloads"] stringByAppendingPathComponent:self.tmpFilename];
    }
    return _unDownloadStr;
}

- (NSString *)libraryUnDownloadStr {
    if (_libraryUnDownloadStr == nil) {
        _libraryUnDownloadStr = [[[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"com.apple.nsurlsessiond/Downloads"] stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]] stringByAppendingPathComponent:self.tmpFilename];
    }
    return _libraryUnDownloadStr;
}

- (NSString *)resumeDirectoryStr {
    if (_resumeDirectoryStr == nil) {
        _resumeDirectoryStr = [[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:@"ZYLResumeDownloads"] stringByAppendingPathComponent:[@"resume_" stringByAppendingString:[ZYLTool encodeFilename:self.downloadUrl]]];
    }
    return _resumeDirectoryStr;
}

@end
