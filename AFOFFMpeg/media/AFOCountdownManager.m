//
//  AFOMediaQueueManager.m
//  AFOPlayer
//
//  Created by xueguang xian on 2017/12/31.
//  Copyright © 2017年 AFO. All rights reserved.
//

#import "AFOCountdownManager.h"
#import <AFOGitHub/AFOGitHub.h>
#import "AFOMediaManager.h" // 导入 AFOMediaManager.h 以使用 AFOMediaLog
#import <AFOFoundation/AFOFoundation.h>
@interface AFOCountdownManager ()
@property (nonatomic, strong)     dispatch_source_t    sourceTimer;
@property (nonatomic, assign)       BOOL               isFinish;
@property (nonatomic, assign)       BOOL               isSuspend;
@property (nonatomic, assign)       BOOL               isResumedOnce;
@end
@implementation AFOCountdownManager
#pragma mark ------------ init
- (instancetype)init{
    if (self = [super init]) {
    }
    return self;
}

- (void)pause {
    if (!_sourceTimer || self.isSuspend) {
        return;
    }
    if (self.isResumedOnce) {
        dispatch_suspend(_sourceTimer);
        self.isSuspend = YES;
        if ([self.delegate respondsToSelector:@selector(vedioFileSuspendedDelegate)]) {
            [self.delegate vedioFileSuspendedDelegate];
        }
    }
}

- (void)resume {
    if (!_sourceTimer || !self.isSuspend) {
        return;
    }
    // 仅对确实 suspend 过的 timer resume，避免 over-resume 崩溃
    dispatch_resume(_sourceTimer);
    self.isSuspend = NO;
    if ([self.delegate respondsToSelector:@selector(vedioFilePlayingDelegate)]) {
        [self.delegate vedioFilePlayingDelegate];
    }
}

- (void)cancel {
    if (!_sourceTimer) {
        return;
    }
    // cancel 前若处于 suspend，需要先 resume 一次保证 cancel handler 能执行，避免资源泄露
    if (self.isSuspend) {
        dispatch_resume(_sourceTimer);
        self.isSuspend = NO;
    }
    dispatch_source_cancel(_sourceTimer);
    _sourceTimer = nil;
    self.isResumedOnce = NO;
}
#pragma mark ------ 倒计时
- (void)addCountdownActionFps:(float)fps
                     duration:(int64_t)time
                        block:(void (^)(NSNumber *isEnd))block{
    AFOMediaLog(@"AFOCountdownManager: addCountdownActionFps called. Initial fps: %f, duration: %lld", fps, time);
    // 每次重新配置前取消旧 source，否则末尾 dispatch_resume 会对已激活的 source 再次 resume（Over-resume 崩溃）。
    if (_sourceTimer) {
        [self cancel];
    }
    __block int timeout = time * fps;
    AFOMediaLog(@"AFOCountdownManager: Initial timeout (time * fps): %d", timeout);
    if (fps / 100 >= 1) {
        AFOMediaLog(@"AFOCountdownManager: Adjusting fps. Original fps: %f", fps);
        fps = fps / 100;
        AFOMediaLog(@"AFOCountdownManager: Adjusted fps: %f", fps);
    }
    dispatch_source_set_timer(self.sourceTimer,dispatch_walltime(NULL, 0),(1.0 / fps) * NSEC_PER_SEC, 0); //每秒执行
    AFOMediaLog(@"AFOCountdownManager: Timer interval: %f seconds", (1.0 / fps));
    WeakObject(self);
    dispatch_source_set_event_handler(self.sourceTimer, ^{
        StrongObject(self);
        AFOMediaLog(@"AFOCountdownManager: Timer event handler executing. Current timeout: %d", timeout);
        if(timeout <= 0){ //倒计时结束，关闭
            self.isFinish = YES;
            AFOMediaLog(@"AFOCountdownManager: Timeout reached. Calling block with isEnd: YES");
            block(@(YES));
            if ([self.delegate respondsToSelector:@selector(vedioFileFinishDelegate)]) {
                [self.delegate vedioFileFinishDelegate];
            }
            [self cancel];
        } else {
            self.isFinish = NO;
            timeout--;
            AFOMediaLog(@"AFOCountdownManager: Timeout remaining: %d. Calling block with isEnd: NO", timeout);
            block(@(NO));
        }
        });
        if (!self.isResumedOnce) {
            dispatch_resume(self.sourceTimer); // 新建 timer 初始为 suspend，需要 resume 一次
            self.isResumedOnce = YES;
            self.isSuspend = NO;
            AFOMediaLog(@"AFOCountdownManager: Timer resumed after setting event handler.");
        }
    }
#pragma mark ------------ property
- (dispatch_source_t)sourceTimer{
    if (!_sourceTimer) {
        AFOMediaLog(@"AFOCountdownManager: Creating new sourceTimer (created suspended; resume once after set_timer/event_handler).");
        _sourceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    }
    return _sourceTimer;
}
- (void)dealloc{
    AFOMediaLog(@"AFOCountdownManager dealloc");
    [self cancel];
}
@end
