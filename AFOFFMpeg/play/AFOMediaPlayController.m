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
#import "AFOMediaPlayViewModel.h"

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
@property (nonatomic, strong) AFOMediaPlayViewModel *viewModel;
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
    [self.viewModel onViewDidDisappear];
}
#pragma mark ------------ viewDidLoad
// 2. 确保 mediaManager 是强持有，且在 viewDidLoad 中立即创建
- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"AFOMediaPlayController: viewDidLoad called. Self address: %p", self);
    NSLog(@"AFOMediaPlayController: Custom viewDidLoad code executed.");
    self.view.backgroundColor = [UIColor whiteColor];

    [self bindViewModel];
    [self addMeidaView];
    
    [self.viewModel onViewDidLoad];
}
#pragma mark ------
- (void)viewWillLayoutSubviews{
   [self addMeidaView];
}
- (void)restartMediaFile{
    [self.viewModel restart];
}
#pragma mark ------ AFOSchedulerPassValueDelegate
- (void)schedulerReceiverRouterManagerDelegate:(id)model{
    NSDictionary *parameters = model;
    NSString *value = parameters[@"value"];
    self.orientation = [[parameters objectForKey:@"direction"] integerValue];
    self.strPath = value;
    self.title = parameters[@"title"];
    [self.viewModel configureWithPath:value ?: @""
                               title:parameters[@"title"]
                      orientationMask:self.orientation];
    /// 播放改到 `viewDidLoad`（已 `addMeidaView`）之后；若将来在已展示页面上再次注入参数，可立即开播。
    if (self.isViewLoaded) {
        [self addMeidaView];
        [self.viewModel play];
    }
}
#pragma mark ------
- (void)playerVedioWithPath:(NSString *)path{
    // 兼容旧 API：外部仍可直接调用 controller 播放
    [self.viewModel configureWithPath:path ?: @""
                               title:self.title
                      orientationMask:self.orientation];
    [self.viewModel play];
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

- (AFOMediaPlayViewModel *)viewModel {
    if (!_viewModel) {
        _viewModel = [[AFOMediaPlayViewModel alloc] init];
    }
    return _viewModel;
}

- (void)bindViewModel {
    WeakObject(self);
    self.viewModel.onTitleChanged = ^(NSString * _Nonnull title) {
        StrongObject(self);
        if (!self) { return; }
        self.title = title;
        self.navigationItem.title = title;
    };
    self.viewModel.onFrame = ^(CVPixelBufferRef  _Nullable pixelBuffer) {
        StrongObject(self);
        if (!self) { return; }
        if (pixelBuffer) {
            [self.mediaView displayPixelBuffer:pixelBuffer];
        }
    };
    self.viewModel.onError = ^(NSString * _Nonnull message) {
        StrongObject(self);
        if (!self) { return; }
        [self showPlaybackError:message];
    };
}
- (void)dealloc{
 //   [self.mediaManager stopAudio];
    NSLog(@"AFOMediaPlayController dealloc");
}
@end
