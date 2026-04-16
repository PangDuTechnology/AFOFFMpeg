//
//  AFOMediaPlayViewModel.m
//  AFOFFMpeg
//
//  Created by Cursor.
//

#import "AFOMediaPlayViewModel.h"
#import "AFOTotalDispatchManager.h"
#import <AFOFoundation/AFOFoundation.h>

@interface AFOMediaPlayViewModel ()
@property (nonatomic, strong) AFOTotalDispatchManager *dispatchManager;
@property (nonatomic, assign, readwrite) UIInterfaceOrientationMask orientationMask;
@property (nonatomic, copy, readwrite, nullable) NSString *path;
@property (nonatomic, copy, readwrite, nullable) NSString *title;
@end

@implementation AFOMediaPlayViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _dispatchManager = [[AFOTotalDispatchManager alloc] init];
        _orientationMask = UIInterfaceOrientationMaskPortrait;
    }
    return self;
}

- (void)configureWithPath:(NSString *)path
                    title:(nullable NSString *)title
           orientationMask:(UIInterfaceOrientationMask)mask {
    self.path = path;
    self.title = title;
    self.orientationMask = mask;

    if (title.length > 0 && self.onTitleChanged) {
        self.onTitleChanged(title);
    }
}

- (void)onViewDidLoad {
    // 若已注入 path，则在 viewDidLoad 后自动开始
    if (self.path.length > 0) {
        [self play];
    }
}

- (void)onViewWillAppear {
    // UI 相关（TabBar/导航栏显隐）由 Controller 负责，此处不做副作用
}

- (void)onViewDidDisappear {
    [self stop];
}

- (void)play {
    NSString *path = self.path ?: @"";
    if (path.length == 0) {
        if (self.onError) {
            self.onError(@"视频路径为空");
        }
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (self.onError) {
            self.onError(@"视频文件不存在");
        }
        return;
    }

    WeakObject(self);
    [self.dispatchManager displayVedioForPath:path block:^(NSError * _Nullable error,
                                                           CVPixelBufferRef  _Nullable pixelBuffer,
                                                           NSString * _Nullable totalTime,
                                                           NSString * _Nullable currentTime,
                                                           NSInteger totalSeconds,
                                                           NSUInteger cuttentSeconds,
                                                           BOOL isVideoEnd) {
        StrongObject(self);
        if (!self) {
            return;
        }
        if (error) {
            if (self.onError) {
                self.onError(error.localizedDescription ?: @"播放器解码失败");
            }
            return;
        }
        if (self.onTime) {
            self.onTime(totalTime, currentTime, totalSeconds, cuttentSeconds, isVideoEnd);
        }
        if (pixelBuffer && self.onFrame) {
            self.onFrame(pixelBuffer);
        }
    }];
}

- (void)restart {
    [self play];
}

- (void)stop {
    [self.dispatchManager stopAudio];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaQueueManagerTimerCancel" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaSuspendedManager" object:nil];
}

- (void)setSuspended:(BOOL)suspended {
    // 保持现有机制：通过通知驱动帧泵暂停/恢复，避免大范围改动
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaQueueManagerTimerNotifaction:" object:@(!suspended)];
    if (suspended) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaSuspendedManager" object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaStartManagerNotifacation" object:nil];
    }
}

@end

