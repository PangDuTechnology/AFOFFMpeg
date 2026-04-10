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
@end
@implementation AFOCountdownManager
#pragma mark ------------ init
- (instancetype)init{
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AFOMediaQueueManagerTimerNotifaction:) name:NSStringFromSelector(@selector(AFOMediaQueueManagerTimerNotifaction:)) object:nil];
        ///------
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AFOMediaQueueManagerTimerCancel) name:NSStringFromSelector(@selector(AFOMediaQueueManagerTimerCancel)) object:nil];
    }
    return self;
}
- (void)AFOMediaQueueManagerTimerNotifaction:(NSNotification *)object{
    NSNumber *number = object.object;
    if ([object.object isKindOfClass:[NSNumber class]]) {
        BOOL isPause = [number boolValue];
        if (isPause) {
            // 只有在计时器存在且未暂停时才暂停
            if (_sourceTimer && !self.isSuspend) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaSuspendedManager" object:nil];
                self.isSuspend = YES;
            }
        }else{
            // 只有在计时器存在且已暂停时才恢复
            if (_sourceTimer && self.isSuspend) {
                self.isSuspend = NO;
                if (!self.isFinish) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaStartManagerNotifacation" object:nil];
                }
                else{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"AFORestartMeidaFileNotification" object:nil];
                }
            }
        }
    }
}
- (void)AFOMediaQueueManagerTimerCancel{
    if (_sourceTimer) {
        // 在取消之前，确保 dispatch source 不处于暂停状态。
        // 如果 self.isSuspend 为 YES，表示我们手动暂停了它，需要恢复。
        // dispatch_resume 对非暂停的源调用是安全的。
        dispatch_source_cancel(_sourceTimer);
        _sourceTimer = nil; // 取消后将计时器置空
    }
}
#pragma mark ------ 倒计时
- (void)addCountdownActionFps:(float)fps
                     duration:(int64_t)time
                        block:(void (^)(NSNumber *isEnd))block{
    AFOMediaLog(@"AFOCountdownManager: addCountdownActionFps called. Initial fps: %f, duration: %lld", fps, time);
    // 每次重新配置前取消旧 source，否则末尾 dispatch_resume 会对已激活的 source 再次 resume（Over-resume 崩溃）。
    if (_sourceTimer) {
        dispatch_source_cancel(_sourceTimer);
        _sourceTimer = nil;
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
            // 确保在暂停之前，计时器是恢复状态，避免过度暂停
            // 计时器结束时，直接取消，不再进行 suspend/resume 操作
            [self AFOMediaQueueManagerTimerCancel]; // 调用取消方法进行清理
        } else {
            self.isFinish = NO;
            timeout--;
            AFOMediaLog(@"AFOCountdownManager: Timeout remaining: %d. Calling block with isEnd: NO", timeout);
            block(@(NO));
        }
        });
        dispatch_resume(self.sourceTimer); // 确保在设置事件处理后启动或恢复计时器
        AFOMediaLog(@"AFOCountdownManager: Timer resumed after setting event handler.");
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
    [[NSNotificationCenter defaultCenter] removeObserver:self]; // 移除所有通知观察者

    if (_sourceTimer) {
        // 确保在 dealloc 中只取消 dispatch source，不进行 resume 操作。
        // 如果它在此时仍然是暂停状态，它的取消处理程序将会在其暂停计数归零时执行。
        // 这可以避免“过度恢复”的崩溃。
        dispatch_source_cancel(_sourceTimer);
        _sourceTimer = nil;
    }
}
@end
