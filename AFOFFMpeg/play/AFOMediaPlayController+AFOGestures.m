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

@interface AFOMediaPlayController ()<AFOMediaViewDelegate>
@property (nonatomic, strong) NSNumber *isShow;
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
        self.mediaView = [[AFOMetalVideoView alloc] initWithFrame:self.view.frame]; // AFOMetalVideoView 不需要 delegate
        [self.view addSubview:self.mediaView];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaQueueManagerTimerNotifaction:" object:@(!isSuspended)];
}
@end
