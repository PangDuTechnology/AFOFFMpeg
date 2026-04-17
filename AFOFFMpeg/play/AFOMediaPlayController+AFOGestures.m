//
//  AFOMediaPlayController+AFOGestures.m
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/1/26.
//  Copyright © 2018年 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOMediaPlayController+AFOGestures.h"
#import "AFOMetalVideoView.h"
#import <objc/runtime.h>
#import <AFOGitHub/AFOGitHub.h>
#import <AFOFoundation/AFOFoundation.h>
#import "AFOMediaView.h"
#import "AFOMediaPlayViewModel.h"

@interface AFOMediaPlayController ()<AFOMediaViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSNumber *afo_controlsVisible;
@property (nonatomic, strong) NSNumber *afo_autoHideToken;
@end

@interface AFOMediaPlayController (AFOViewModelAccess)
- (AFOMediaPlayViewModel *)viewModel;
@end

@implementation AFOMediaPlayController (AFOGestures)
#pragma mark ------------ property
- (void)setMediaView:(AFOMetalVideoView *)mediaView{
    objc_setAssociatedObject(self, @selector(setMediaView:), mediaView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (AFOMetalVideoView *)mediaView{
    return objc_getAssociatedObject(self, @selector(setMediaView:));
}

- (void)setMediaOverlayView:(AFOMediaView *)mediaOverlayView {
    objc_setAssociatedObject(self, @selector(setMediaOverlayView:), mediaOverlayView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (AFOMediaView *)mediaOverlayView {
    return objc_getAssociatedObject(self, @selector(setMediaOverlayView:));
}

- (void)setAfo_controlsVisible:(NSNumber *)afo_controlsVisible{
    objc_setAssociatedObject(self, @selector(setAfo_controlsVisible:), afo_controlsVisible, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSNumber *)afo_controlsVisible{
    return objc_getAssociatedObject(self, @selector(setAfo_controlsVisible:));
}

- (void)setAfo_autoHideToken:(NSNumber *)afo_autoHideToken{
    objc_setAssociatedObject(self, @selector(setAfo_autoHideToken:), afo_autoHideToken, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSNumber *)afo_autoHideToken{
    return objc_getAssociatedObject(self, @selector(setAfo_autoHideToken:));
}
#pragma mark ------
- (void)addMeidaView{
    if (!self.mediaView) {
        AFOMetalVideoView *metalView = [[AFOMetalVideoView alloc] initWithFrame:CGRectZero];
        metalView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:metalView];
        [NSLayoutConstraint activateConstraints:@[
            [metalView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [metalView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            [metalView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [metalView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        ]];
        self.mediaView = metalView;

        // 叠加控制层（播放/暂停/进度），保持旧交互：点击视频切换显隐
        AFOMediaView *overlay = [[AFOMediaView alloc] initWithFrame:CGRectZero delegate:self];
        overlay.translatesAutoresizingMaskIntoConstraints = NO;
        overlay.backgroundColor = UIColor.clearColor;
        [self.view addSubview:overlay];
        [NSLayoutConstraint activateConstraints:@[
            [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        ]];
        self.mediaOverlayView = overlay;

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(afo_toggleControls)];
        tap.delegate = self;
        tap.cancelsTouchesInView = NO; // 不影响 overlay 上按钮点击
        [self.view addGestureRecognizer:tap];

        // 初始进入播放页：默认隐藏控制层（播放按钮/时间条等），点击视频再显示
        self.afo_controlsVisible = @(NO);
        self.afo_autoHideToken = @(0);
        [self.navigationController setNavigationBarHidden:YES animated:NO];
        [self.mediaOverlayView settingBottomViewShowOrHidden:^(UIView *view) {
            view.hidden = YES;
            view.alpha = 0.0;
        }];
    }
}
#pragma mark ------

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // 点击控制层（按钮/进度条）时，不触发“显隐切换”，避免交互混乱
    UIView *view = touch.view;
    if (!view) { return YES; }
    if ([view isKindOfClass:[UIControl class]]) { return NO; }
    if (self.mediaOverlayView) {
        CGPoint p = [touch locationInView:self.mediaOverlayView];
        UIView *hit = [self.mediaOverlayView hitTest:p withEvent:nil];
        if ([hit isKindOfClass:[UIControl class]]) { return NO; }
    }
    return YES;
}

- (void)afo_toggleControls{
    BOOL visible = [self.afo_controlsVisible boolValue];
    [self afo_setControlsVisible:(!visible) animated:YES];
}

- (void)afo_setControlsVisible:(BOOL)visible animated:(BOOL)animated{
    self.afo_controlsVisible = @(visible);
    [self.navigationController setNavigationBarHidden:(!visible) animated:animated];

    if (!self.mediaOverlayView) { return; }

    NSTimeInterval duration = animated ? 0.20 : 0.0;
    if (visible) {
        [self.mediaOverlayView settingBottomViewShowOrHidden:^(UIView *view) {
            view.hidden = NO;
            view.alpha = 0.0;
            [UIView animateWithDuration:duration animations:^{
                view.alpha = 1.0;
            }];
        }];
        [self afo_scheduleAutoHideIfNeeded];
    } else {
        [self.mediaOverlayView settingBottomViewShowOrHidden:^(UIView *view) {
            [UIView animateWithDuration:duration animations:^{
                view.alpha = 0.0;
            } completion:^(__unused BOOL finished) {
                view.hidden = YES;
            }];
        }];
    }
}

- (void)afo_scheduleAutoHideIfNeeded{
    if (![self.afo_controlsVisible boolValue]) { return; }

    NSInteger token = [self.afo_autoHideToken integerValue] + 1;
    self.afo_autoHideToken = @(token);

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (![self.afo_controlsVisible boolValue]) { return; }
        if ([self.afo_autoHideToken integerValue] != token) { return; }
        [self afo_setControlsVisible:NO animated:YES];
    });
}
#pragma mark ------------ AFOMediaViewDelegate
- (void)buttonTouchActionDelegate:(BOOL)isSuspended{
    [self.viewModel setSuspended:isSuspended];
    // 用户主动操作控制层后，保持控件可见并重新计时自动隐藏
    if (![self.afo_controlsVisible boolValue]) {
        [self afo_setControlsVisible:YES animated:YES];
    } else {
        [self afo_scheduleAutoHideIfNeeded];
    }
}
@end
