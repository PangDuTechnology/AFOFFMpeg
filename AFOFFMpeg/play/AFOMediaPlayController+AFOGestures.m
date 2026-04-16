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

@interface AFOMediaPlayController ()<AFOMediaViewDelegate>
@property (nonatomic, strong) NSNumber *isShow;
@end

@interface AFOMediaPlayController (AFOViewModelAccess)
- (AFOMediaPlayViewModel *)viewModel;
@end

@implementation AFOMediaPlayController (AFOGestures)
#pragma mark ------------ property
- (void)setMediaView:(AFOMediaView *)mediaView{
    objc_setAssociatedObject(self, @selector(setMediaView:), mediaView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (AFOMediaView *)mediaView{
    return objc_getAssociatedObject(self, @selector(setMediaView:));
}
- (void)setIsShow:(NSNumber *)isShow{
    objc_setAssociatedObject(self, @selector(setIsShow:), isShow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSNumber *)isShow{
    return objc_getAssociatedObject(self, @selector(setIsShow:));
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
        ///------
        self.isShow = @(NO);
        [self.navigationController setNavigationBarHidden:[self.isShow boolValue] animated:YES];
    }
}
#pragma mark ------
#pragma mark ------ touchesBegan
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self showOrHiddenNavigationBar];
}
- (void)showOrHiddenNavigationBar{
    WeakObject(self);
}
#pragma mark ------------ AFOMediaViewDelegate
- (void)buttonTouchActionDelegate:(BOOL)isSuspended{
    [self.viewModel setSuspended:isSuspended];
}
@end
