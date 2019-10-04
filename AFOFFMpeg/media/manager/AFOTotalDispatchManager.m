//
//  AFOTotalDispatchManager.m
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/3.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOTotalDispatchManager.h"
#import <AFOGitHub/AFOGitHub.h>
#import <AFOFoundation/AFOFoundation.h>
#import "AFOConfigurationManager.h"
#import "AFOMediaConditional.h"

@interface AFOTotalDispatchManager ()<AFOAudioManagerDelegate,AFOPlayMediaManager>
@property (nonatomic, assign)            NSInteger  videoStream;
@property (nonatomic, assign)            NSInteger  audioStream;
@property (nonatomic, assign)            float      audioTimeStamp;
@property (nonatomic, assign)            float      videoTimeStamp;
@property (nonatomic, assign)            float      videoPosition;
@property (nonatomic, assign)            CGFloat    tickCorrectionTime;
@property (nonatomic, assign)            float      tickCorrectionPosition;
@property (nonatomic, assign)            float      frameRate;
@property (nonnull, nonatomic, strong)   AFOAudioManager      *audioManager;
@property (nonnull, nonatomic, strong)   AFOMediaManager  *videoManager;
@property (nonnull, nonatomic, strong) dispatch_queue_t queue_t;
@end
@implementation AFOTotalDispatchManager
#pragma mark ------ display Vedio
- (void)displayVedioForPath:(NSString *)strPath
                      block:(displayVedioFrameBlock)block{
    [INTUAutoRemoveObserver addObserver:self selector:@selector(stopAudioNotifacation:) name:@"AFOMediaStopManager" object:nil];
    ///---
    dispatch_barrier_async(self.queue_t, ^{
        WeakObject(self);
        [AFOMediaConditional mediaSesourcesConditionalPath:strPath block:^(NSError *error, NSInteger videoIndex, NSInteger audioIndex){
            StrongObject(self);
            if (error.code == 0) {
                self.videoStream = videoIndex;
                self.audioStream = audioIndex;
            }else{
                block(error, NULL, NULL, NULL, 0, 0);
                return;
            }
        }];
    });
    ///------ play audio
    dispatch_async(self.queue_t, ^{
        [AFOConfigurationManager configurationForPath:strPath stream:self.audioStream block:^(AVCodec * _Nonnull codec, AVFormatContext * _Nonnull format, AVCodecContext * _Nonnull context) {
            [self.audioManager audioFormatContext:format codecContext:context index:self.audioStream];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self playAudio];
            });
        }];
    });
    ///------ display video
    dispatch_async(self.queue_t, ^{
        [AFOConfigurationManager configurationForPath:strPath stream:self.videoStream block:^(AVCodec * _Nonnull codec, AVFormatContext * _Nonnull format, AVCodecContext * _Nonnull context) {
            [self.videoManager displayVedioFormatContext:format codecContext:context index:self.videoStream block:^(NSError *error, UIImage *image, NSString *totalTime, NSString *currentTime, NSInteger totalSeconds, NSUInteger cuttentSeconds) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(error,image,totalTime,currentTime,totalSeconds,cuttentSeconds);
                });
            }];
        }];
    });
}
- (void)playAudio{
    [self.audioManager playAudio];
}
- (void)stopAudio{
    [self.audioManager stopAudio];
}
- (void)stopAudioNotifacation:(NSNotification *)notification{
    [self stopAudio];
}
- (void)correctionTime{
    const NSTimeInterval correction = [self tickCorrection];
    const NSTimeInterval time = MAX(self.videoPosition + correction, 0.01);
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self correctionTime];
    });
    [self playAudio];
}
- (CGFloat)tickCorrection{
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (!_tickCorrectionTime) {
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _videoTimeStamp;
        return 0;
    }
    NSTimeInterval dPosition = _videoTimeStamp - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    if (correction > 1.f || correction < -1.f) {
        correction = 0;
        _tickCorrectionTime = 0;
    }
    return correction;
}
#pragma mark ------ delegate
- (void)audioTimeStamp:(float)audioTime{
    self.audioTimeStamp = audioTime;
}
- (void)videoTimeStamp:(float)videoTime
              position:(float)position
             frameRate:(float)frameRate{
    self.videoTimeStamp = videoTime;
    self.videoPosition = position;
    self.frameRate = frameRate;
   [self correctionTime];
}
#pragma mark ------ attribute
- (AFOAudioManager *)audioManager{
    if (!_audioManager) {
        _audioManager = [[AFOAudioManager alloc] initWithDelegate:self];
    }
    return _audioManager;
}
- (AFOMediaManager *)videoManager{
    if (!_videoManager) {
        _videoManager = [[AFOMediaManager alloc] initWithDelegate:self];
    }
    return _videoManager;
}
- (dispatch_queue_t)queue_t{
    if (!_queue_t) {
        _queue_t = dispatch_queue_create("com.AFOFFMpeg.totalDispatchManager", DISPATCH_QUEUE_CONCURRENT);
    }
    return _queue_t;
}
#pragma mark ------ dealloc
- (void)dealloc{
    NSLog(@"AFOVideoAudioManager dealloc");
}
@end
