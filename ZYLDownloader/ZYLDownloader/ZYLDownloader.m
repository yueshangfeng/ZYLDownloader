//
//  ZYLDownloader.m
//  ZYLDownloader
//
//  Created by zyl on 16/9/20.
//  Copyright © 2016年 zyl. All rights reserved.
//

#import "ZYLDownloader.h"

#import "ZYLTool.h"
#import "ZYLJudgeNetworkType.h"
#import <UIKit/UIKit.h>

static ZYLDownloader *_downloader;
static dispatch_once_t onceToken1;
static dispatch_once_t onceToken2;

@interface ZYLDownloader () <ZYLSingleDownloaderDelegate>

//存储下载数据的路径
@property (copy, nonatomic) NSString *directoryStr;

//存储接续下载数据的路径
@property (copy, nonatomic) NSString *resumeDirectoryStr;

//存储未下载完成的数据的路径
@property (copy, nonatomic) NSString *unDownloadStr;

//系统存储未下载完成的数据对应的文件的路径
@property (copy, nonatomic) NSString *libraryUnDownloadStr;

//文件管理器
@property (strong, nonatomic) NSFileManager *fileManager;

//用于存储下载器所有的子下载器
@property (strong, nonatomic) NSMutableArray *singleDownloaderArray;

//用于存储原始的从数据库中读取的下载信息
@property (strong, nonatomic) RLMResults <ZYLSingleDownloaderModel *> *allModels;

//用于存储正在下载的下载器的数组
@property (strong, nonatomic) NSMutableArray *downloadingArray;

//用户存储等待下载的下载器的数组
@property (strong, nonatomic) NSMutableArray *waitingDownlodArray;

@end

@implementation ZYLDownloader

#pragma mark - 创建和销毁下载器单例***********************************************************
#pragma mark - 创建下载器单例
/*************************************************************************/
+ (instancetype)sharedDownloader {
    dispatch_once(&onceToken1, ^{
        if (_downloader == nil) {
            _downloader = [[ZYLDownloader alloc] init];
        }
    });
    return _downloader;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    dispatch_once(&onceToken2, ^{
        if (_downloader == nil) {
            _downloader = [super allocWithZone:zone];
        }
    });
    return _downloader;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return _downloader;
}

- (instancetype)mutableCopyWithZone:(NSZone *)zone {
    return _downloader;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        //创建存储路径
        [self createDirectory];
        //开启网络监测
        [ZYLJudgeNetworkType judgeNetworkTypeIs:^(NSString *networkType) {
            
        }];
        //设置默认的最大的下载数量为3
        self.maxDownloaderNum = 3;
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"总下载器销毁了");
}

#pragma mark - 销毁下载单例
+ (void)destoryDownloader {
    
    for (ZYLSingleDownloader *downloader in _downloader.singleDownloaderArray) {
        [downloader judgeDownloaderStateToHandel];
    }
    
    [_downloader.singleDownloaderArray removeAllObjects];
    
    onceToken1 = 0;
    onceToken2 = 0;
    _downloader = nil;
}

#pragma mark - 关于下载***********************************************************
#pragma mark - 拿到下载链接开始下载
/*************************************************************************/
- (void)startDownloadWithDownloadUrl:(NSString *)downloadUrl filename:(NSString *)filename fileType:(NSString *)fileType isHand:(BOOL)isHand {
    //判断连接是否是合法的http或者https连接
    if ([ZYLTool checkIsUrlAtString:downloadUrl]) {
        //有效
        
    } else {
        //无效
        NSLog(@"链接无效，请输入正确的http或者https链接");
        return;
    }
    
    //判断文件名和文件类型是否为空
    if ([ZYLTool checkIsEmpty:filename] || [ZYLTool checkIsEmpty:fileType]) {
        //空
        NSLog(@"输入的文件名或者文件类型为空");
        return;
    } else {
        //非空
        
    }
    
    //检查下载器是否已经存在
    __block ZYLSingleDownloader *seekDownloader = nil;
    __block BOOL isD = NO;
    [self.singleDownloaderArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([downloadUrl isEqualToString:obj.downloadUrl]) {
            //已经存在这个下载了
            seekDownloader = obj;
            isD = YES;
            *stop = YES;
        }
    }];
    
    if (isD) {
        //已经存在这个下载器了
        NSLog(@"已经存在这个下载器了");
        
        //判断这个下载器是否已经下载完成
        if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderRate:withDownloaderUrl:)]) {
            [self.zylDownloaderDelegate downloaderRate:seekDownloader.downloaderProgress withDownloaderUrl:seekDownloader.downloadUrl];
        }
        
        if (seekDownloader.downloaderProgress >= 1.0) {
            if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderFinishedWithDownloader:)]) {
                [self.zylDownloaderDelegate downloaderFinishedWithDownloader:seekDownloader.downloadUrl];
            }
            
            if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderState:andDownloaderUrl:)]) {
                [self.zylDownloaderDelegate downloaderState:ZYLDownloaderStateSuccess andDownloaderUrl:seekDownloader.downloadUrl];
            }
            
        }
        
        return;
    } else {
        //不存在这个下载器
        //根据用户传入的信息创建一个子下载器
        NSDictionary *downloadDict = @{@"downloadUrl":downloadUrl, @"fileType":fileType, @"filename":filename};
        ZYLSingleDownloader *singleDownloader = [[ZYLSingleDownloader alloc] init];
        singleDownloader.isExistInRealm = NO;
        [singleDownloader setValuesForKeysWithDictionary:downloadDict];
        //设置代理
        singleDownloader.downloaderDelegate = self;
        
        singleDownloader.isHand = isHand;
        
        //添加一个新的下载
        [self addDownloader:singleDownloader isHand:isHand isControl:YES];
        
        //存储子下载器
        [self.singleDownloaderArray addObject:singleDownloader];
    }
}

#pragma mark - 根据下载连接暂停某一个下载
- (void)pauseDownloaderWithDownloadUrl:(NSString *)downloadUrl {
    [self.singleDownloaderArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader  *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.downloadUrl isEqualToString:downloadUrl]) {
            NSLog(@"找到需要暂停下载的任务");
            [obj cancelRorOtherDownloader];
            
            *stop = YES;
        }
    }];
}

#pragma mark - 根据下载连接继续某一个下载
- (void)resumeDownloaderWithDownloadUrl:(NSString *)downloadUrl {
    __weak __typeof(self)(weakSelf) = self;
    [self.singleDownloaderArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader  *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.downloadUrl isEqualToString:downloadUrl]) {
            NSLog(@"找到需要继续下载的任务");
            if (obj.downloaderDelegate == nil) {
                obj.downloaderDelegate = weakSelf;
            }
            [obj resumeisHand:YES];
            *stop = YES;
        }
    }];
}

#pragma mark - 创建存储数据的路径
- (void)createDirectory {
    //创建存储已经下载成功的数据路径
    //首先检查文件路径是否存在
    BOOL isE = [self.fileManager fileExistsAtPath:self.directoryStr];
    if (isE) {
        //存在这个路径，不创建
        NSLog(@"要创建的下载文件路径存在");
    } else {
        //不存在这个路径，创建
        NSLog(@"下载路径不存在");
        BOOL isC = [self.fileManager createDirectoryAtPath:self.directoryStr withIntermediateDirectories:YES attributes:nil error:nil];
        if (isC) {
            //路径创建成功
            NSLog(@"下载路径创建成功");
        } else {
            //路径创建失败
            NSLog(@"下载路径创建失败");
        }
    }
    
    //创建存储resumeData的路径
    BOOL isRE = [self.fileManager fileExistsAtPath:self.resumeDirectoryStr];
    if (isRE) {
        //存在这个路径，不创建
        NSLog(@"要创建的继续下载文件路径存在");
    } else {
        //不存在这个路径，创建
        NSLog(@"继续下载路径不存在");
        BOOL isC = [self.fileManager createDirectoryAtPath:self.resumeDirectoryStr withIntermediateDirectories:YES attributes:nil error:nil];
        if (isC) {
            //路径创建成功
             NSLog(@"继续下载路径创建成功");
        } else {
            //路径创建失败
            NSLog(@"继续下载路径创建失败");
        }
    }
    //创建存储为下载完成的数据的路径
    BOOL isU = [self.fileManager fileExistsAtPath:self.unDownloadStr];
    if (isU) {
        //存在这个路径，不创建
        NSLog(@"要创建的未完成下载文件路径存在");
        NSLog(@"项目路径：%@", self.directoryStr);
    } else {
        //不存在这个路径，创建
        NSLog(@"继续下载路径不存在");
        BOOL isC = [self.fileManager createDirectoryAtPath:self.unDownloadStr withIntermediateDirectories:YES attributes:nil error:nil];
        if (isC) {
            //路径创建成功
             NSLog(@"未完成下载路径创建成功");
            NSLog(@"项目路径：%@", self.directoryStr);
        } else {
            //路径创建失败
            NSLog(@"未完成下载路径创建失败");
        }
    }
}

#pragma mark - 关于控制下载数量***********************************************************
#pragma mark - 开启一个新的下载
/*************************************************************************/
- (void)addDownloader:(ZYLSingleDownloader *)downloader isHand:(BOOL)isHand isControl:(BOOL)isControl{
    //首先判断是不是手动开启新的下载
    if (isHand) {
        //是手动,强行开启下载
        //判断是否达到最大下载数目
        if (self.downloadingArray.count < self.maxDownloaderNum) {
            //没有
            if (![self.downloadingArray containsObject:downloader]) {
                [self.downloadingArray addObject:downloader];
                [self.waitingDownlodArray removeObject:downloader];
            }
        } else {
            if (![self.downloadingArray containsObject:downloader]) {
                [self.downloadingArray addObject:downloader];
                [self.waitingDownlodArray removeObject:downloader];
            }
            //达到了
            //暂停最前面的正在下载
            ZYLSingleDownloader *firstDownloader = [self.downloadingArray firstObject];
            [self removeDownloader:firstDownloader isHand:isHand isControl:YES];
        }
        
        //开启下载
        if (isControl) {
            downloader.isHand = isHand;
            [downloader start];
        }
        
    } else {
        //不是手动
        if (self.downloadingArray.count < self.maxDownloaderNum) {
            //还没有达到最大下载数
            if (![self.downloadingArray containsObject:downloader]) {
                [self.downloadingArray addObject:downloader];
                [self.waitingDownlodArray removeObject:downloader];
            }
            
            //开启下载
            if (isControl) {
                downloader.isHand = isHand;
                [downloader start];
            }
            
        } else {
            //已经达到了最大的下载数
            //判断正在正在下载的数组中是否有此下载器
            if ([self.downloadingArray containsObject:downloader]) {
                
            } else {
                [self.waitingDownlodArray addObject:downloader];
                NSLog(@"达到最大下载数目，已经加入待下载数组");
            }
            
        }
    }
    
}

#pragma mark - 停止一个新的下载
- (void)removeDownloader:(ZYLSingleDownloader *)downloader isHand:(BOOL)isHand isControl:(BOOL)isControl {
    __block BOOL isE = NO;
    [self.downloadingArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.downloadUrl isEqualToString:downloader.downloadUrl]) {
            isE = YES;
            *stop = YES;
        }
    }];
    
    if (isE) {
        //存在
        if (downloader.downloaderProgress >= 1.0) {
            //已经下载完成
            [self.downloadingArray removeObject:downloader];
        } else {
            //还没有下载完成
            if (![self.waitingDownlodArray containsObject:downloader]) {
                //在下载器没有被删除的时候添加到等待下载数组
                if (downloader.downloaderState != ZYLDownloaderStateDeleted) {
                    [self.waitingDownlodArray addObject:downloader];
                } else if (downloader.downloaderState == ZYLDownloaderStateDeleted) {
                    if ([self.waitingDownlodArray containsObject:downloader]) {
                        [self.waitingDownlodArray removeObject:downloader];
                    }
                }
                
            }
            
            [self.downloadingArray removeObject:downloader];
        }
        
        if (isControl == YES) {
            downloader.isHand = isHand;
            [downloader cancelRorOtherDownloader];
            
        }
        
        if (isHand) {
            //是手动
            [self checkDownloadProgressExceptDownloader:downloader];
        } else {
            //不是手动
            //检查下载流程
            [self checkDownloadProgressExceptDownloader:nil];
        }
        
    } else {
        //不存在
        NSLog(@"正在下载的文件中不存在这个下载");
        if (downloader.downloaderState == ZYLDownloaderStateDeleted) {
            //检测等待数组中是否有此数据
            if ([self.waitingDownlodArray containsObject:downloader]) {
                [self.waitingDownlodArray removeObject:downloader];
            }
        }
    }
    
}

#pragma mark - 检查当期下载的流程，判断是否需要开启新的下载
- (void)checkDownloadProgressExceptDownloader:(ZYLSingleDownloader *)downloader {
    //判断正在下载的数组中是否有空缺
    if (self.downloadingArray.count < self.maxDownloaderNum) {
        //有空缺
        //检查等待下载的数组中是否有数据
        if (self.waitingDownlodArray.count > 0) {
            //有
            //寻找第一个需要下载的数据
            __block ZYLSingleDownloader *firstDownloader = nil;
            if (downloader == nil) {
                [self.waitingDownlodArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (obj.isHand == NO) {
                        firstDownloader = obj;
                        *stop = YES;
                    }
                }];
            } else {
                [self.waitingDownlodArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (![obj.downloadUrl isEqualToString:downloader.downloadUrl] && obj.isHand == NO) {
                        firstDownloader = obj;
                        *stop = YES;
                    }
                }];
            }
            
            if (firstDownloader == nil) {
                NSLog(@"没有找到需要开启的下载的任务");
            } else {
                firstDownloader.isHand = NO;
                if (firstDownloader.downloaderProgress > 0) {
                    [firstDownloader resumeisHand:firstDownloader.isHand];
                } else {
                    [firstDownloader start];
                }
                
                if (![self.downloadingArray containsObject:firstDownloader]) {
                    [self.downloadingArray addObject:firstDownloader];
                    [self.waitingDownlodArray removeObject:firstDownloader];
                }
            }
            
        } else {
            //没有
            NSLog(@"已经没有等待下载的数据了");
        }
        
    } else {
        //没有空缺
        NSLog(@"已经达到最大的同时下载数目");
    }
}

#pragma mark - 关于数据库***********************************************************
#pragma mark - 将数据存储到数据库
- (void)saveDownloaderInfoWithSingleDownloader:(ZYLSingleDownloader *)singleDownloader {
    //创建存储对象
    ZYLSingleDownloaderModel *model = [[ZYLSingleDownloaderModel alloc] init];
    model.downloadUrl = singleDownloader.downloadUrl;
    model.fileType = singleDownloader.fileType;
    model.filename = singleDownloader.filename;
    model.downloaderProgress = singleDownloader.downloaderProgress;
    //存储到数据库
    RLMRealm *realm = [RLMRealm defaultRealm];
    [realm beginWriteTransaction];
    [realm addOrUpdateObject:model];
    [realm commitWriteTransaction];
}

#pragma mark - 读取数据库中的内容
/*************************************************************************/
- (NSArray *)readDownloadersFromRealm {
    self.allModels = [ZYLSingleDownloaderModel allObjects];
    _singleDownloaderArray = [[NSMutableArray alloc] init];
    if (self.allModels.count > 0) {
        //数据库有数据
        for (ZYLSingleDownloaderModel *model in self.allModels) {
            ZYLSingleDownloader *singDownloader = [[ZYLSingleDownloader alloc] init];
            singDownloader.downloadUrl = model.downloadUrl;
            singDownloader.fileType = model.fileType;
            singDownloader.filename = model.filename;
            singDownloader.downloaderProgress = model.downloaderProgress;
            [_singleDownloaderArray addObject:singDownloader];
        }
    } else {
        //数据库无数据
        NSLog(@"数据库没有数据");
    }
    
    return _singleDownloaderArray;
}

#pragma mark - 从数据库中读取某一个下载器的信息
- (ZYLSingleDownloaderModel *)getDownloaderInfoWithDownloaderUrl:(NSString *)downloaderUrl {
    //首先判断下载连接是否在数据数组中
    ZYLSingleDownloaderModel *targetModel = [[ZYLSingleDownloaderModel alloc] init];
    __block BOOL isD = NO;
    __block ZYLSingleDownloader *downloaderModel = nil;
    [self.singleDownloaderArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([downloaderUrl isEqualToString:obj.downloadUrl]) {
            //已经存在这个下载了
            downloaderModel = obj;
            isD = YES;
        }
    }];
    
    if (isD) {
        //存在
        //判断是否存在于数据库中
        if (downloaderModel.isExistInRealm == YES) {
            //存在
            //判断这个文件是否下载完成
            if (downloaderModel.downloaderProgress >= 1.0) {
                //下载完成
                //判断沙盒目录是否存在此文件
                
                NSString *localUrl = [self.directoryStr stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", [ZYLTool encodeFilename:downloaderModel.downloadUrl], downloaderModel.fileType]];
                if ([self.fileManager fileExistsAtPath:localUrl]) {
                    //存在
                    targetModel.localUrl = localUrl;
                    targetModel.downloadUrl = downloaderModel.downloadUrl;
                    targetModel.filename = downloaderModel.filename;
                    targetModel.fileType = downloaderModel.fileType;
                    targetModel.downloaderProgress = downloaderModel.downloaderProgress;
                    targetModel.isExistInRealm = YES;
                    
                    return targetModel;
                } else {
                    //不存在
                    NSLog(@"沙盒目录没有对应的文件");
                    targetModel.localUrl = nil;
                    targetModel.downloadUrl = downloaderModel.downloadUrl;
                    targetModel.filename = downloaderModel.filename;
                    targetModel.fileType = downloaderModel.fileType;
                    targetModel.downloaderProgress = downloaderModel.downloaderProgress;
                    targetModel.isExistInRealm = YES;
                    
                    return targetModel;
                }
                
            } else {
                //未下载完成
                NSLog(@"这个下载还没有完成");
                targetModel.localUrl = nil;
                targetModel.downloadUrl = downloaderModel.downloadUrl;
                targetModel.filename = downloaderModel.filename;
                targetModel.fileType = downloaderModel.fileType;
                targetModel.downloaderProgress = downloaderModel.downloaderProgress;
                targetModel.isExistInRealm = YES;
                
                return targetModel;
            }
        } else {
            //不存在
            NSLog(@"这个下载还没有开始");
            targetModel.localUrl = nil;
            targetModel.downloadUrl = downloaderModel.downloadUrl;
            targetModel.filename = downloaderModel.filename;
            targetModel.fileType = downloaderModel.fileType;
            targetModel.downloaderProgress = downloaderModel.downloaderProgress;
            targetModel.isExistInRealm = NO;
            
            return targetModel;
        }
        
    } else {
        //不存在
        NSLog(@"不存在这个下载");
        
        return nil;
    }
}

#pragma mark - 读取数据中所有的信息
- (NSArray<ZYLSingleDownloaderModel *> *)getAllDownloadersInfo {
    __block NSMutableArray *downloaderArray = [[NSMutableArray alloc] init];
    [self.singleDownloaderArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        ZYLSingleDownloaderModel *model = [self getDownloaderInfoWithDownloaderUrl:obj.downloadUrl];
        if (model != nil) {
            [downloaderArray addObject:model];
        }
    }];
    
    return downloaderArray;
}

#pragma mark - 删除某个下载的信息
- (void)deleteDownloaderInfoWithDownloderUrl:(NSString *)downloaderUrl {
    __block BOOL isD = NO;
    __block ZYLSingleDownloader *downloaderModel = nil;
    
    [self.singleDownloaderArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(ZYLSingleDownloader *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([downloaderUrl isEqualToString:obj.downloadUrl]) {
            //已经存在这个下载了
            isD = YES;
            downloaderModel = obj;
            *stop = YES;
        }
    }];
    
    if (isD) {
        //存在
        
        //判断下载器的下载状态，做出相应的处理
        [downloaderModel judgeDownloaderStateToHandel];
        
        //判断是否在数据库中
        if (downloaderModel.isExistInRealm == YES) {
            //存在
            //1️⃣数据源中删除数据
            __weak __typeof(self)(weakSelf) = self;
            
            [self.singleDownloaderArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(ZYLSingleDownloader*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj.downloadUrl isEqualToString:downloaderModel.downloadUrl]) {
                    [weakSelf.singleDownloaderArray removeObject:obj];
                    *stop = YES;
                }
            }];
            
            //2️⃣数据库中删除数据
            [self deleteDownloaderFromReaml:downloaderModel];
            //3️⃣从沙盒目录中删除文件（下载的文件、继续下载数据、未下载完成的数据）
            //①下载的文件
            NSString *localUrl = [self.directoryStr stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", [ZYLTool encodeFilename:downloaderModel.downloadUrl], downloaderModel.fileType]];
            if ([self.fileManager fileExistsAtPath:localUrl]) {
                //存在则删除
                if (![self.fileManager removeItemAtPath:localUrl error:nil]) {
                    NSLog(@"删除下载的文件失败");
                }
            }
            //②继续下载的数据
            NSString *resumeDataStr = [self.resumeDirectoryStr stringByAppendingPathComponent:[@"resume_" stringByAppendingString:[ZYLTool encodeFilename:downloaderModel.downloadUrl]]];
            if ([self.fileManager fileExistsAtPath:resumeDataStr]) {
                NSData *tempData = [NSData dataWithContentsOfFile:resumeDataStr];
                NSString *XMLStr = [[NSString alloc] initWithData:tempData encoding:NSUTF8StringEncoding];
                NSString *tmpStr = nil;
                if ([[[UIDevice currentDevice] systemVersion] floatValue] < 9.0) {
                    //适配iOS 8以及之前的系统，由于resumeData不一样
                    //iOS8包含iOS8以前
                    NSRange tmpRange = [XMLStr rangeOfString:@"NSURLSessionResumeInfoLocalPath"];
                    NSString *tmpString = [XMLStr substringFromIndex:tmpRange.location + tmpRange.length];
                    NSRange oneStringRange = [tmpString rangeOfString:@"CFNetworkDownload_"];
                    NSRange twoStringRange = [tmpString rangeOfString:@".tmp"];
                    tmpStr = [tmpString substringWithRange:NSMakeRange(oneStringRange.location, twoStringRange.location + twoStringRange.length - oneStringRange.location)];
                    
                } else {
                    //iOS8以后
                    NSRange tmpRange = [XMLStr rangeOfString:@"NSURLSessionResumeInfoTempFileName"];
                    NSString *tmpString = [XMLStr substringFromIndex:tmpRange.location + tmpRange.length];
                    NSRange oneStringRange = [tmpString rangeOfString:@"<string>"];
                    NSRange twoStringRange = [tmpString rangeOfString:@"</string>"];
                    //记录tmp文件名
                    tmpStr = [tmpString substringWithRange:NSMakeRange(oneStringRange.location + oneStringRange.length, twoStringRange.location - oneStringRange.location - oneStringRange.length)];
                }
                
//                NSRange tmpRange = [XMLStr rangeOfString:@"NSURLSessionResumeInfoTempFileName"];
//                NSString *tmpStr = [XMLStr substringFromIndex:tmpRange.location + tmpRange.length];
//                NSRange oneStringRange = [tmpStr rangeOfString:@"<string>"];
//                NSRange twoStringRange = [tmpStr rangeOfString:@"</string>"];
                //记录tmp文件名
                downloaderModel.tmpFilename = tmpStr;
                
                //存在则删除
                if (![self.fileManager removeItemAtPath:resumeDataStr error:nil]) {
                    NSLog(@"删除继续下载的数据失败");
                } else {
                    //删除成功
                    //③删除未下载完成的数据
                    NSString *unDownloaderStr = [[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:@"ZYLUnDownloads"] stringByAppendingPathComponent:downloaderModel.tmpFilename];
                    if ([self.fileManager fileExistsAtPath:unDownloaderStr]) {
                        if (![self.fileManager removeItemAtPath:unDownloaderStr error:nil]) {
                            NSLog(@"删除未下载完成的数据失败");
                        }
                    }
                }
            }
            
        } else {
            //不存在
            __weak __typeof(self)(weakSelf) = self;
            [self.singleDownloaderArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader* _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj.downloadUrl isEqualToString:downloaderModel.downloadUrl]) {
                    [weakSelf.singleDownloaderArray removeObject:obj];
                    
                    if ([self.waitingDownlodArray containsObject:obj]) {
                        [self.waitingDownlodArray removeObject:obj];
                    }
                    
                    *stop = YES;
                }
            }];
            NSLog(@"数据库中不存在这个下载，无法在数据库中删除");
        }
        
    } else {
        //不存在
        NSLog(@"不存在这个下载，无法删除");
    }
}

#pragma mark - 从realm中删除某一个对象
- (void)deleteDownloaderFromReaml:(ZYLSingleDownloader *)downloader {
    //创建存储对象
    for (ZYLSingleDownloaderModel *model in self.allModels) {
        if ([model.downloadUrl isEqualToString:downloader.downloadUrl]) {
            //删除对象
            RLMRealm *realm = [RLMRealm defaultRealm];
            [realm beginWriteTransaction];
            [realm deleteObject:model];
            [realm commitWriteTransaction];
        }
    }
}

#pragma mark - 删除所有的下载信息
- (void)deleteAllDownloadersInfo {
    
//    for (ZYLSingleDownloader *downloader in _singleDownloaderArray) {
//        [downloader judgeDownloaderStateToHandel];
//    }
    __block NSMutableArray *urlArray = [[NSMutableArray alloc] init];
    [self.singleDownloaderArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(ZYLSingleDownloader*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [urlArray addObject:obj.downloadUrl];
    }];
    
    __weak __typeof(self)(weakSelf) = self;
    [urlArray enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [weakSelf deleteDownloaderInfoWithDownloderUrl:obj];
    }];
    
}

#pragma mark - 更新数据库中的某条数据
- (void)updateDownloaderInfoWithDownloderUrl:(NSString *)downloaderUrl withFilename:(NSString *)filename fileType:(NSString *)fileType {
    //判断数据源中是否有此数据
    __block BOOL isE = NO;
    __block ZYLSingleDownloader *downloaderModel = nil;
    [self.singleDownloaderArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.downloadUrl isEqualToString:downloaderUrl]) {
            isE = YES;
            downloaderModel = obj;
            *stop = YES;
        }
    }];
    
    if (isE) {
        //存在
        //判断在数据库中是否存在
        if (downloaderModel.isExistInRealm) {
            //存在
            
            NSString *localUrl = [self.directoryStr stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", [ZYLTool encodeFilename:downloaderModel.downloadUrl], downloaderModel.fileType]];
            
            //更新数据源
            if (filename != nil && ![filename isEqualToString:@""]) {
                downloaderModel.filename = filename;
            }
            if (fileType != nil && ![fileType isEqualToString:@""]) {
                downloaderModel.fileType = fileType;
            }
            //更新数据库
            [self saveDownloaderInfoWithSingleDownloader:downloaderModel];
            
            //判断是否下载完成
            if (downloaderModel.downloaderProgress >= 1.0) {
                //下载完成了
                //更新本地的下载好的文件的文件名
                //判断本地文件是否存在
                if ([self.fileManager fileExistsAtPath:localUrl]){
                    //根据新的文件信息更新文件名
                    NSString *newLocalUrl = [self.directoryStr stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", [ZYLTool encodeFilename:downloaderModel.downloadUrl], downloaderModel.fileType]];
                    NSError *error = nil;
                    BOOL isS = [self.fileManager moveItemAtPath:localUrl toPath:newLocalUrl error:&error];
                    if (!isS) {
                        NSLog(@"修改本地下载的文件信息失败：%@", error);
                    }
                    
                } else {
                    //没有本地文件
                    NSLog(@"没有本地缓存文件，无法本地文件");
                }
                
            } else {
                //没有下载完成
                
            }
            
        } else {
            //不存在
            //仅仅更新数据源
            if (filename != nil && ![filename isEqualToString:@""]) {
                downloaderModel.filename = filename;
            }
            if (fileType != nil && ![fileType isEqualToString:@""]) {
                downloaderModel.fileType = fileType;
            }
        }
        
    } else {
        //不存在
        NSLog(@"不存在这个下载器，无法更新数据");
    }
}

#pragma mark - 关于下载状态的代理***********************************************************
#pragma mark - 下载器开始下载
/*************************************************************************/
- (void)downloaderBeginWithDownloader:(ZYLSingleDownloader *)downloader {
    //开始下载后存储或者更新下载数据
    if (downloader.isExistInRealm == NO) {
        //这个下载器并没有存储在这个数据库中,将其存储到数据库
        [self saveDownloaderInfoWithSingleDownloader:downloader];
        downloader.isExistInRealm = YES;
    }
    
    if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderBeginWithDownloader:)]) {
        [self.zylDownloaderDelegate downloaderBeginWithDownloader:downloader.downloadUrl];
    }
}

#pragma mark - 下载器下载完成
- (void)downloaderFinishedWithDownloader:(ZYLSingleDownloader *)downloader {
    //更新数据库
    [self saveDownloaderInfoWithSingleDownloader:downloader];
    
    if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderFinishedWithDownloader:)]) {
        [self.zylDownloaderDelegate downloaderFinishedWithDownloader:downloader.downloadUrl];
    }
}

#pragma mark - 下载器暂停下载
- (void)downloaderPauseWithDownloader:(ZYLSingleDownloader *)downloader {
    //更新数据库
    [self saveDownloaderInfoWithSingleDownloader:downloader];
    
    if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderPauseWithDownloader:)]) {
        [self.zylDownloaderDelegate downloaderPauseWithDownloader:downloader.downloadUrl];
    }
}

#pragma mark - 下载器下载失败
- (void)downloaderFailedWithDownloader:(ZYLSingleDownloader *)downloader {
    //更新数据库
    [self saveDownloaderInfoWithSingleDownloader:downloader];
    
    if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderFailedWithDownloader:)]) {
        [self.zylDownloaderDelegate downloaderFailedWithDownloader:downloader.downloadUrl];
    }
}

#pragma mark - 下载的进度
- (void)downloaderRate:(float)rate withDownloaderUrl:(NSString *)downloaderUrl {
    if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderRate:withDownloaderUrl:)]) {
        [self.zylDownloaderDelegate downloaderRate:rate withDownloaderUrl:downloaderUrl];
    }
    
}

#pragma mark - 下载的状态
- (void)downloaderState:(ZYLDownloaderState)state andDownloaderUrl:(NSString *)downloaderUrl {
    if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderState:andDownloaderUrl:)]) {
        [self.zylDownloaderDelegate downloaderState:state andDownloaderUrl:downloaderUrl];
    }
    
    //找到对应的下载器
    __block ZYLSingleDownloader *downloader = nil;
    [self.singleDownloaderArray enumerateObjectsUsingBlock:^(ZYLSingleDownloader *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.downloadUrl isEqualToString:downloaderUrl]) {
            downloader = obj;
            *stop = YES;
        }
    }];
    
    if (downloader == nil) {
        NSLog(@"没有找到需要操作下载流程的下载器");
        return;
    }
    
    //根据下载状态处理下载流程
    switch (state) {
        case ZYLDownloaderStateFail:
            [self removeDownloader:downloader isHand:downloader.isHand isControl:NO];
            
            break;
            
        case ZYLDownloaderStateRunning:
            [self addDownloader:downloader isHand:downloader.isHand isControl:NO];
            
            break;
            
        case ZYLDownloaderStateSuccess:
            [self removeDownloader:downloader isHand:NO isControl:NO];
            
            break;
            
        case ZYLDownloaderStateDeleted:
            [self removeDownloader:downloader isHand:NO isControl:NO];
            
            break;
            
        case ZYLDownloaderStatePause:
            [self removeDownloader:downloader isHand:downloader.isHand isControl:NO];
            break;
            
        default:
            
            break;
    }
    
}

#pragma mark - 下载的速度
- (void)downloaderSpeed:(NSInteger)speed andDownloaderUrl:(NSString *)downloaderUrl {
    if ([self.zylDownloaderDelegate respondsToSelector:@selector(downloaderSpeed:andDownloaderUrl:)]) {
        [self.zylDownloaderDelegate downloaderSpeed:speed andDownloaderUrl:downloaderUrl];
    }
}

#pragma mark - getter***********************************************************
#pragma mark -
/*************************************************************************/
- (NSString *)directoryStr {
    if (_directoryStr == nil) {
        _directoryStr = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:@"ZYLDownloads"];
    }
    return _directoryStr;
}

- (NSString *)resumeDirectoryStr {
    if (_resumeDirectoryStr == nil) {
        _resumeDirectoryStr = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:@"ZYLResumeDownloads"];
    }
    return _resumeDirectoryStr;
}

- (NSString *)unDownloadStr {
    if (_unDownloadStr == nil) {
        _unDownloadStr = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:@"ZYLUnDownloads"];
    }
    return _unDownloadStr;
}

- (NSString *)libraryUnDownloadStr {
    if (_libraryUnDownloadStr == nil) {
        _libraryUnDownloadStr = [[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"com.apple.nsurlsessiond/Downloads"] stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    }
    return _libraryUnDownloadStr;
}

- (NSFileManager *)fileManager {
    if (_fileManager == nil) {
        _fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}

- (NSMutableArray *)singleDownloaderArray {
    if (_singleDownloaderArray == nil) {
        _singleDownloaderArray = [NSMutableArray arrayWithArray:[self readDownloadersFromRealm]];
    }
    return _singleDownloaderArray;
}

- (NSMutableArray *)downloadingArray {
    if (_downloadingArray == nil) {
        _downloadingArray = [[NSMutableArray alloc] init];
    }
    return _downloadingArray;
}

- (NSMutableArray *)waitingDownlodArray {
    if (_waitingDownlodArray == nil) {
        _waitingDownlodArray = [[NSMutableArray alloc] init];
    }
    return _waitingDownlodArray;
}

- (void)setMaxDownloaderNum:(NSInteger)maxDownloaderNum {
    _maxDownloaderNum = maxDownloaderNum;
    if (maxDownloaderNum > 3) {
        _maxDownloaderNum = 3;
    }
    if (maxDownloaderNum < 1) {
        _maxDownloaderNum = 1;
    }
}

@end
