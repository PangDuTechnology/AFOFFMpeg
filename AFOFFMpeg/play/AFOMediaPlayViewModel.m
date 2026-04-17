//
//  AFOMediaPlayViewModel.m
//  AFOFFMpeg
//
//  Created by Cursor.
//

#import "AFOMediaPlayViewModel.h"
#import "AFOMediaPlaybackEngine.h"
#import <AFOFoundation/AFOFoundation.h>

@interface AFOMediaPlayViewModel ()
@property (nonatomic, strong) AFOMediaPlaybackEngine *engine;
@property (nonatomic, assign, readwrite) UIInterfaceOrientationMask orientationMask;
@property (nonatomic, copy, readwrite, nullable) NSString *path;
@property (nonatomic, copy, readwrite, nullable) NSString *title;
@property (nonatomic, assign) BOOL hasEnded;
@end

@implementation AFOMediaPlayViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _engine = [[AFOMediaPlaybackEngine alloc] init];
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

    self.hasEnded = NO;
    WeakObject(self);
    [self.engine playPath:path callback:^(NSError * _Nullable error,
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
        if (isVideoEnd) {
            self.hasEnded = YES;
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
    [self.engine stop];
}

- (void)setSuspended:(BOOL)suspended {
    // 播放结束后，用户再次点击播放按钮应走“重播”，而不是简单 resume。
    if (self.hasEnded) {
        self.hasEnded = NO;
        [self stop];
        [self play];
        return;
    }
    [self.engine setSuspended:suspended];
}

@end

