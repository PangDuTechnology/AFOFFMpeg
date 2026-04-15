//
//  AFOPlayMediaController.m
//  AFOPlayer
//
//  Created by xueguang xian on 2017/12/28.
//  Copyright © 2017年 AFO. All rights reserved.
//

#import "AFOMediaPlayController.h"
#import "AFOMetalVideoView.h"
#import <AFORouter/AFORouter.h>
#import <AFOFoundation/AFOFoundation.h>
#import <AFOGitHub/INTUAutoRemoveObserver.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AFOSchedulerCore/AFOSchedulerPassValueDelegate.h>
#import "AFOMediaPlayControllerCategory.h"
#import "AFOTotalDispatchManager.h"

/// Pod 实际指向的 `../../AFORouter` 头文件未必包含扩展属性；在播放器内用静态池延长调度器生命周期，避免依赖 AFORouter 私有 API。
static NSMutableArray<AFOTotalDispatchManager *> *AFOMediaPlayController_retainedDispatchManagers(void) {
    static NSMutableArray<AFOTotalDispatchManager *> *pool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pool = [NSMutableArray array];
    });
    return pool;
}

@interface AFOMediaPlayController ()<AFOSchedulerPassValueDelegate>
@property (nonatomic, strong) AFOTotalDispatchManager       *mediaManager;
@property (nonatomic, copy)   NSString                   *strPath;
@property (nonatomic, assign) UIInterfaceOrientationMask  orientation;
@property (nonatomic, strong) AVPlayerViewController *systemPlayerController;
@end

@implementation AFOMediaPlayController

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    NSLog(@"AFOMediaPlayController: viewWillAppear called. Hiding TabBar.");
    [self settingControllerOrientation];
}
- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    NSLog(@"AFOMediaPlayController: viewDidDisappear called. Showing TabBar.");
    self.tabBarController.tabBar.hidden = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaQueueManagerTimerCancel" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaSuspendedManager" object:nil];
    
    // 关键：不要立即释放 mediaManager，只停止播放
    [self.mediaManager stopAudio];
}
#pragma mark ------------ viewDidLoad
// 2. 确保 mediaManager 是强持有，且在 viewDidLoad 中立即创建
- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"AFOMediaPlayController: viewDidLoad called. Self address: %p", self);
    NSLog(@"AFOMediaPlayController: Custom viewDidLoad code executed.");
    self.view.backgroundColor = [UIColor whiteColor];
    [INTUAutoRemoveObserver addObserver:self selector:@selector(restartMediaFile) name:@"AFORestartMeidaFileNotification" object:nil];
    
    // 强制创建 mediaManager
    [self mediaManager];
    
    [self addMeidaView];
    
    if (self.strPath.length > 0) {
        NSLog(@"AFOMediaPlayController: Starting playback in viewDidLoad with path: %@", self.strPath);
        [self playerVedioWithPath:self.strPath];
    }
}
#pragma mark ------
- (void)viewWillLayoutSubviews{
   [self addMeidaView];
}
- (void)restartMediaFile{
    [self playerVedioWithPath:self.strPath];
}
#pragma mark ------ AFOSchedulerPassValueDelegate
- (void)schedulerReceiverRouterManagerDelegate:(id)model{
    NSDictionary *parameters = model;
    NSString *value = parameters[@"value"];
    self.orientation = [[parameters objectForKey:@"direction"] integerValue];
    self.strPath = value;
    self.title = parameters[@"title"];
    /// 播放改到 `viewDidLoad`（已 `addMeidaView`）之后；若将来在已展示页面上再次注入参数，可立即开播。
    if (self.isViewLoaded) {
        [self addMeidaView];
        [self playerVedioWithPath:value];
    }
}
#pragma mark ------
- (void)playerVedioWithPath:(NSString *)path{
    if (path.length == 0) {
        NSLog(@"AFOMediaPlayController: playerVedioWithPath called with empty path!");
        [self showPlaybackError:@"视频路径为空"];
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"AFOMediaPlayController: file not found at path: %@", path);
        [self showPlaybackError:@"视频文件不存在"];
        return;
    }
    
    NSLog(@"AFOMediaPlayController: playerVedioWithPath called with path: %@", path);
    NSLog(@"AFOMediaPlayController: mediaView address before playback: %p", self.mediaView);

#if TARGET_OS_SIMULATOR
    [self playWithSystemPlayer:path];
    return;
#endif
    
    WeakObject(self);
    (void)self.mediaManager;
    
    // ... 现有静态池代码 ...
    
    [self.mediaManager displayVedioForPath:path block:^(NSError * _Nullable error, CVPixelBufferRef  _Nullable pixelBuffer, NSString * _Nullable totalTime, NSString * _Nullable currentTime, NSInteger totalSeconds, NSUInteger cuttentSeconds, BOOL isVideoEnd) {
        StrongObject(self);
        
        NSLog(@"AFOMediaPlayController: Video callback received. Error: %@, pixelBuffer: %p, isVideoEnd: %d",
              error, pixelBuffer, isVideoEnd);
        
        if (error) {
            NSLog(@"AFOMediaPlayController: ERROR - %@", error.localizedDescription);
            [self showPlaybackError:error.localizedDescription ?: @"播放器解码失败"];
            return;
        }
        
        if (pixelBuffer) {
            NSLog(@"AFOMediaPlayController: ✅ Got valid pixelBuffer, sending to mediaView (%p)", self.mediaView);
            [self.mediaView displayPixelBuffer:pixelBuffer];
        } else {
            NSLog(@"AFOMediaPlayController: WARNING - pixelBuffer is nil!");
        }
    }];
}

- (void)playWithSystemPlayer:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    AVPlayer *player = [AVPlayer playerWithURL:url];
    if (!player) {
        [self showPlaybackError:@"系统播放器初始化失败"];
        return;
    }
    self.systemPlayerController = [[AVPlayerViewController alloc] init];
    self.systemPlayerController.player = player;
    [self presentViewController:self.systemPlayerController animated:YES completion:^{
        [player play];
    }];
}

- (void)showPlaybackError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"播放失败"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
#pragma mark ------------ system
- (BOOL)shouldAutorotate{
    return YES;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return self.orientation;
}
- (UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}
#pragma mark ------ didReceiveMemoryWarning
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
#pragma mark ------------ property
- (AFOTotalDispatchManager *)mediaManager{
    if (!_mediaManager){
        _mediaManager = [[AFOTotalDispatchManager alloc] init];
    }
    return _mediaManager;
}
- (void)dealloc{
 //   [self.mediaManager stopAudio];
    NSLog(@"AFOMediaPlayController dealloc");
}
@end
