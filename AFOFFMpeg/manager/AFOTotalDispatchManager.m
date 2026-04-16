//
//  AFOTotalDispatchManager.m
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/3.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOTotalDispatchManager.h"
#import <AFOFoundation/AFOWeakInstance.h>
#import "AFOConfigurationManager.h"
#import "AFOMediaManager.h"
#import "AFOAudioManager.h"

@interface AFOTotalDispatchManager ()<AFOPlayMediaManager>
@property (nonatomic, assign)            NSInteger  videoStream;
@property (nonatomic, assign)            NSInteger  audioStream;
@property (nonatomic, assign)            BOOL       isFinish;
@property (nonnull, nonatomic, strong)   AFOAudioManager      *audioManager;
@property (nonnull, nonatomic, strong)   AFOMediaManager  *videoManager;
@end
@implementation AFOTotalDispatchManager
+ (void)initialize{
    av_register_all();
}
#pragma mark ------ init
- (instancetype)init{
    if (self = [super init]) {
        NSLog(@"AFOTotalDispatchManager: init called. Self address: %p", self);
    }
    return self;
}
- (void)displayVedioForPath:(NSString *)strPath
                      block:(displayVedioFrameBlock)block{
    NSLog(@"AFOTotalDispatchManager: displayVedioForPath called for path: %@", strPath);
    if (strPath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:strPath]) {
        NSError *pathError = [NSError errorWithDomain:@"AFOTotalDispatchManager"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"视频文件不存在或路径为空"}];
        if (block) {
            block(pathError, nil, nil, nil, 0, 0, NO);
        }
        return;
    }
    WeakObject(self);
    [AFOConfigurationManager configurationStreamPath:strPath block:^(NSError * _Nonnull error, NSInteger videoIndex, NSInteger audioIndex) {
        StrongObject(self);
        if (!self) {
            return;
        }
        if (error.code != 0) {
            if (block) {
                block(error, nil, nil, nil, 0, 0, NO);
            }
            return;
        }
        self.videoStream = videoIndex;
        self.audioStream = audioIndex;
        NSLog(@"AFOTotalDispatchManager: Video stream index: %ld, Audio stream index: %ld", (long)videoIndex, (long)audioIndex);

        AFOMediaLog(@"AFOTotalDispatchManager: configurationStreamPath finished, start codec setup with resolved streams.");
        ///--- play audio
        if (self.audioStream >= 0) {
            [AFOConfigurationManager configurationForPath:strPath stream:self.audioStream block:^(AVCodec * _Nullable codec, AVFormatContext * _Nullable format, AVCodecContext * _Nullable context, NSInteger videoStream, NSInteger audioStream, NSData * _Nullable sps, NSData * _Nullable pps) {
                if (!format || !context) {
                    return;
                }
                [self.audioManager audioFormatContext:format codecContext:context index:self.audioStream];
                [self playAudio];
            }];
        }

        if (self.videoStream < 0) {
            NSError *videoStreamError = [NSError errorWithDomain:@"AFOTotalDispatchManager"
                                                             code:-2
                                                         userInfo:@{NSLocalizedDescriptionKey: @"未找到可播放的视频流"}];
            if (block) {
                block(videoStreamError, nil, nil, nil, 0, 0, NO);
            }
            return;
        }

        ///------ display video
        [AFOConfigurationManager configurationForPath:strPath stream:self.videoStream block:^(AVCodec * _Nonnull codec, AVFormatContext * _Nonnull format, AVCodecContext * _Nonnull context, NSInteger videoStream, NSInteger audioStream, NSData * _Nullable sps, NSData * _Nullable pps) {
            AFOMediaLog(@"AFOTotalDispatchManager: Received AFOConfigurationManager video callback. format: %p, context: %p", format, context);
            StrongObject(self);
            if (!self) {
                return;
            }
            if (!format || !context) {
                NSError *videoInitError = [NSError errorWithDomain:@"AFOTotalDispatchManager"
                                                               code:-3
                                                           userInfo:@{NSLocalizedDescriptionKey: @"视频解码器初始化失败"}];
                if (block) {
                    block(videoInitError, nil, nil, nil, 0, 0, NO);
                }
                return;
            }
            AFOMediaLog(@"AFOTotalDispatchManager: Calling videoManager displayVedioFormatContext. format: %p, context: %p", format, context);
            [self.videoManager displayVedioFormatContext:format codecContext:context index:self.videoStream block:^(NSError *error, CVPixelBufferRef pixelBuffer, NSString *totalTime, NSString *currentTime, NSInteger totalSeconds, NSUInteger cuttentSeconds, BOOL isVideoEnd) {
                AFOMediaLog(@"AFOTotalDispatchManager: AFOConfigurationManager callback for video. format: %p, context: %p", format, context);
                NSLog(@"AFOTotalDispatchManager: pixelBuffer received: %p", pixelBuffer);
                if (block) {
                    block(error,pixelBuffer,totalTime,currentTime,totalSeconds,cuttentSeconds, isVideoEnd);
                }
            }];
        }];
    }];
}
- (void)playAudio{
    [self.audioManager playAudio];
}
- (void)stopAudio{
    [self.audioManager stopAudio];
}

- (void)setSuspended:(BOOL)suspended {
    [self.videoManager setSuspended:suspended];
    if (suspended) {
        [self stopAudio];
    } else {
        [self playAudio];
    }
}

- (void)stop {
    [self stopAudio];
    [self.videoManager cancelFramePump];
}
#pragma mark ------ AFOPlayMediaManager
- (void)videoNowPlayingDelegate{
    // 帧泵恢复/开始时确保音频处于播放状态
    [self playAudio];
}

- (void)videoFinishPlayingDelegate{
    [self stopAudio];
}

- (void)videoDidPauseDelegate:(BOOL)isPaused {
    if (isPaused) {
        [self stopAudio];
    }
}
#pragma mark ------ property
- (AFOAudioManager *)audioManager{
    if (!_audioManager) {
        _audioManager = [[AFOAudioManager alloc] init];
    }
    return _audioManager;
}
- (AFOMediaManager *)videoManager{
    if (!_videoManager) {
        _videoManager = [[AFOMediaManager alloc] initWithDelegate:self];
    }
    return _videoManager;
}
#pragma mark ------ dealloc
- (void)dealloc{
    AFOMediaLog(@"AFOTotalDispatchManager: Deallocating instance: %p", self); // 添加日志
    NSLog(@"AFOTotalDispatchManager dealloc");
    // 尝试停止音视频管理器中的相关 dispatch 对象
    [self.audioManager stopAudio]; // 假设 AFOAudioManager 有 stopAudio 方法
    // TODO: 检查 AFOMediaManager 和 AFOCountdownManager 的 dealloc，确保所有 dispatch 对象都被正确取消或停止。

    // 假设 AFOMediaManager 有一个 stopVideo 方法来清理其内部资源
    // [self.videoManager stopVideo]; // 已注释掉，因为编译错误
    NSLog(@"AFOTotalDispatchManager: Deallocating. Please ensure AFOMediaManager and AFOCountdownManager are properly cleaned.");
}
@end
//@property (nonatomic, assign)            float      audioTimeStamp;
//@property (nonatomic, assign)            float      videoTimeStamp;
//@property (nonatomic, assign)            float      videoPosition;
//@property (nonatomic, assign)            CGFloat    tickCorrectionTime;
//@property (nonatomic, assign)            float      tickCorrectionPosition;
//@property (nonatomic, assign)            float      frameRate;

//- (void)correctionTime{
//    const NSTimeInterval correction = [self tickCorrection];
//    const NSTimeInterval time = MAX(self.videoPosition + correction, 0.01);
//    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
//    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//        [self correctionTime];
//    });
//    [self playAudio];
//}
//- (CGFloat)tickCorrection{
//    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
//    if (!_tickCorrectionTime) {
//        _tickCorrectionTime = now;
//        _tickCorrectionPosition = _videoTimeStamp;
//        return 0;
//    }
//    NSTimeInterval dPosition = _videoTimeStamp - _tickCorrectionPosition;
//    NSTimeInterval dTime = now - _tickCorrectionTime;
//    NSTimeInterval correction = dPosition - dTime;
//    if (correction > 1.f || correction < -1.f) {
//        correction = 0;
//        _tickCorrectionTime = 0;
//    }
//    return correction;
//}
//#pragma mark ------ delegate
//- (void)audioTimeStamp:(float)audioTime{
//    self.audioTimeStamp = audioTime;
//}
//- (void)videoTimeStamp:(float)videoTime
//position:(float)position
//frameRate:(float)frameRate{
//    self.videoTimeStamp = videoTime;
//    self.videoPosition = position;
//    self.frameRate = frameRate;
//    [self correctionTime];
//}
