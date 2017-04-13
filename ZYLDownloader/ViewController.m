//
//  ViewController.m
//  ZYLDownloader
//
//  Created by zyl on 16/9/20.
//  Copyright © 2016年 zyl. All rights reserved.
//

//http://sbslive.cnrmobile.com/storage/storage2/18/01/18/46eeb50b3f21325a6f4bd0e8ba4d2357.3gp
//http://sbslive.cnrmobile.com/storage/storage4/24/04/24/1af32d3589806d136895accd817af288.3gp

#import "ViewController.h"

#import "ZYLDownloader.h"

@interface ViewController () <ZYLDownloaderDelegate>

- (IBAction)start:(UIButton *)sender;
- (IBAction)pause:(UIButton *)sender;
- (IBAction)resume:(UIButton *)sender;
- (IBAction)get:(UIButton *)sender;
- (IBAction)getAll:(UIButton *)sender;
- (IBAction)delete:(UIButton *)sender;
- (IBAction)deleteAll:(UIButton *)sender;
- (IBAction)update:(UIButton *)sender;
- (IBAction)destory:(UIButton *)sender;

- (IBAction)one:(UIButton *)sender;
- (IBAction)two:(UIButton *)sender;
- (IBAction)three:(UIButton *)sender;
- (IBAction)four:(UIButton *)sender;
- (IBAction)five:(UIButton *)sender;

- (IBAction)resumeOne:(UIButton *)sender;
- (IBAction)resumeTwo:(UIButton *)sender;
- (IBAction)resumeThree:(UIButton *)sender;
- (IBAction)resumeFour:(UIButton *)sender;
- (IBAction)resumeFive:(UIButton *)sender;

- (IBAction)pauseOne:(UIButton *)sender;
- (IBAction)pauseTwo:(UIButton *)sender;
- (IBAction)pauseThree:(UIButton *)sender;
- (IBAction)pauseFour:(UIButton *)sender;
- (IBAction)pauseFive:(UIButton *)sender;

- (IBAction)deleteOne:(UIButton *)sender;
- (IBAction)deleteTwo:(UIButton *)sender;
- (IBAction)deleteThree:(UIButton *)sender;
- (IBAction)deleteFour:(UIButton *)sender;
- (IBAction)deleteFive:(UIButton *)sender;

@property (strong, nonatomic) IBOutlet UILabel *one;
@property (strong, nonatomic) IBOutlet UILabel *two;
@property (strong, nonatomic) IBOutlet UILabel *three;
@property (strong, nonatomic) IBOutlet UILabel *four;
@property (strong, nonatomic) IBOutlet UILabel *five;

@property (strong, nonatomic) ZYLDownloader *dowl;

@property (copy, nonatomic) NSString *downloadUrl;

@property (strong, nonatomic) NSArray *urlArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.downloadUrl = @"http://jlzg.cnrmobile.com/resource/index/sp/jlzg0226.mp4";
    
    self.dowl = [ZYLDownloader sharedDownloader];
    
    self.dowl.maxDownloaderNum = 3;
    
    self.dowl.zylDownloaderDelegate = self;
    
    self.urlArray = @[@"http://jlzg.cnrmobile.com/resource/index/sp/jlzg0226.mp4", @"http://sbslive.cnrmobile.com/storage/storage2/51/34/18/3e59db9bb51802c2ef7034793296b724.3gp", @"http://sbslive.cnrmobile.com/storage/storage2/05/61/05/f2609b3b964bbbcfb3e3703dde59a994.3gp", @"http://sbslive.cnrmobile.com/storage/storage2/28/11/28/689f8a52fbef0fbbf51db19ee3276ae5.3gp", @"http://sbslive.cnrmobile.com/storage/storage2/71/28/05/512551c6fcf71615ad5f8ae9bd524069.3gp"];
}

#pragma mark - 开始下载
- (IBAction)start:(UIButton *)sender {
    [self.dowl startDownloadWithDownloadUrl:self.downloadUrl filename:@"吃饭睡觉打豆豆" fileType:@"3gp" isHand:NO];
}

#pragma mark - 暂停下载
- (IBAction)pause:(UIButton *)sender {
    [self.dowl pauseDownloaderWithDownloadUrl:self.downloadUrl];
}

#pragma mark - 继续下载
- (IBAction)resume:(UIButton *)sender {
    [self.dowl resumeDownloaderWithDownloadUrl:self.downloadUrl];
}

#pragma mark - 读取某一个下载数据信息
- (IBAction)get:(UIButton *)sender {
    ZYLSingleDownloaderModel *model = [self.dowl getDownloaderInfoWithDownloaderUrl:self.downloadUrl];
    NSLog(@"%@, %@", model.localUrl, model.filename);
}

#pragma mark - 读取所有的下载数据
- (IBAction)getAll:(UIButton *)sender {
    NSLog(@"%@", [self.dowl getAllDownloadersInfo]);
}

#pragma mark - 删除某一个下载
- (IBAction)delete:(UIButton *)sender {
    [self.dowl deleteDownloaderInfoWithDownloderUrl:self.downloadUrl];
}

#pragma mark - 删除所有数据
- (IBAction)deleteAll:(UIButton *)sender {
    
    [self.urlArray enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.dowl deleteDownloaderInfoWithDownloderUrl:obj];
    }];
    //[self.dowl deleteAllDownloadersInfo];
    self.one.text = @"0";
    self.two.text = @"0";
    self.three.text = @"0";
    self.four.text = @"0";
    self.five.text = @"0";
    
}

#pragma mark - 修改文件信息
- (IBAction)update:(UIButton *)sender {
    [self.dowl updateDownloaderInfoWithDownloderUrl:self.downloadUrl withFilename:@"测试文件名" fileType:@"mp4"];
}

#pragma mark - 销毁总下载器
- (IBAction)destory:(UIButton *)sender {
    self.dowl = nil;
    [ZYLDownloader destoryDownloader];
}

#pragma mark - 多个数据同时下载
- (IBAction)one:(UIButton *)sender {
    [self.dowl startDownloadWithDownloadUrl:self.urlArray[0] filename:@"吃饭睡觉打豆豆1" fileType:@"3gp" isHand:NO];
}

- (IBAction)two:(UIButton *)sender {
    [self.dowl startDownloadWithDownloadUrl:self.urlArray[1] filename:@"吃饭睡觉打豆豆2" fileType:@"3gp" isHand:NO];
}

- (IBAction)three:(UIButton *)sender {
    [self.dowl startDownloadWithDownloadUrl:self.urlArray[2] filename:@"吃饭睡觉打豆豆3" fileType:@"3gp" isHand:NO];
}

- (IBAction)four:(UIButton *)sender {
    [self.dowl startDownloadWithDownloadUrl:self.urlArray[3] filename:@"吃饭睡觉打豆豆4" fileType:@"3gp" isHand:NO];
}

- (IBAction)five:(UIButton *)sender {
    [self.dowl startDownloadWithDownloadUrl:self.urlArray[4] filename:@"吃饭睡觉打豆豆5" fileType:@"3gp" isHand:NO];
}

- (IBAction)resumeOne:(UIButton *)sender {
    [self.dowl resumeDownloaderWithDownloadUrl:self.urlArray[0]];
}

- (IBAction)resumeTwo:(UIButton *)sender {
    [self.dowl resumeDownloaderWithDownloadUrl:self.urlArray[1]];
}

- (IBAction)resumeThree:(UIButton *)sender {
    [self.dowl resumeDownloaderWithDownloadUrl:self.urlArray[2]];
}

- (IBAction)resumeFour:(UIButton *)sender {
    [self.dowl resumeDownloaderWithDownloadUrl:self.urlArray[3]];
}

- (IBAction)resumeFive:(UIButton *)sender {
    [self.dowl resumeDownloaderWithDownloadUrl:self.urlArray[4]];
}

- (IBAction)pauseOne:(UIButton *)sender {
    [self.dowl pauseDownloaderWithDownloadUrl:self.urlArray[0]];
}

- (IBAction)pauseTwo:(UIButton *)sender {
    [self.dowl pauseDownloaderWithDownloadUrl:self.urlArray[1]];
}

- (IBAction)pauseThree:(UIButton *)sender {
    [self.dowl pauseDownloaderWithDownloadUrl:self.urlArray[2]];
}

- (IBAction)pauseFour:(UIButton *)sender {
    [self.dowl pauseDownloaderWithDownloadUrl:self.urlArray[3]];
}

- (IBAction)pauseFive:(UIButton *)sender {
    [self.dowl pauseDownloaderWithDownloadUrl:self.urlArray[4]];
}

- (IBAction)deleteOne:(UIButton *)sender {
    [self.dowl deleteDownloaderInfoWithDownloderUrl:self.urlArray[0]];
}

- (IBAction)deleteTwo:(UIButton *)sender {
    [self.dowl deleteDownloaderInfoWithDownloderUrl:self.urlArray[1]];
}

- (IBAction)deleteThree:(UIButton *)sender {
    [self.dowl deleteDownloaderInfoWithDownloderUrl:self.urlArray[2]];
}

- (IBAction)deleteFour:(UIButton *)sender {
    [self.dowl deleteDownloaderInfoWithDownloderUrl:self.urlArray[3]];
}

- (IBAction)deleteFive:(UIButton *)sender {
    [self.dowl deleteDownloaderInfoWithDownloderUrl:self.urlArray[4]];
}

#pragma mark - 下载器的代理***********************************************************
#pragma mark - 下载的速度
/*************************************************************************/
- (void)downloaderSpeed:(NSInteger)speed andDownloaderUrl:(NSString *)downloaderUrl {
    NSString *speedStr = nil;
    if (speed >= 0 && speed < 1024) {
        //B
        speedStr = [NSString stringWithFormat:@"下载速度为：%ldb/s", (long)speed];
    } else if (speed >= 1024 && speed < 1024 * 1024) {
        //KB
        speedStr = [NSString stringWithFormat:@"下载速度为：%.2lfkb/s", (long)speed / 1024.0];
    } else if (speed >= 1024 * 1024) {
        //MB
        speedStr = [NSString stringWithFormat:@"下载速度为：%.2lfmb/s", (long)speed / 1024.0 / 1024.0];
    }
    
    NSLog(@"文件：%@的下载速度：%@", downloaderUrl,speedStr);
}

- (void)downloaderRate:(float)rate withDownloaderUrl:(NSString *)downloaderUrl {
    NSInteger index = [self.urlArray indexOfObject:downloaderUrl];
    switch (index) {
        case 0:
            self.one.text = [NSString stringWithFormat:@"%lf", rate];
            break;
        case 1:
            self.two.text = [NSString stringWithFormat:@"%lf", rate];
            break;
        case 2:
            self.three.text = [NSString stringWithFormat:@"%lf", rate];
            break;
        case 3:
            self.four.text = [NSString stringWithFormat:@"%lf", rate];
            break;
        case 4:
            self.five.text = [NSString stringWithFormat:@"%lf", rate];
            break;
        default:
            
            break;
    }
}

- (void)downloaderState:(ZYLDownloaderState)state andDownloaderUrl:(NSString *)downloaderUrl {
    NSLog(@"下载器的状态%lu", (unsigned long)state);
}

@end
