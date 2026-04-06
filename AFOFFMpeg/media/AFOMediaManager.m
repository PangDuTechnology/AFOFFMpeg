//
//  AFOPlayMediaViewModel.m
//  AFOFFMpeg
//
//  Created by xueguang xian on 2017/12/28.
//  Copyright © 2017年 AFO Science and technology Ltd. All rights reserved.
//

#import <VideoToolbox/VideoToolbox.h>
#include <libavutil/hwcontext.h>
#include <libavutil/opt.h>
#include <libavutil/pixfmt.h>
#import "AFOMediaManager.h"
#import <AFOGitHub/INTUAutoRemoveObserver.h>
#import <AFOFoundation/AFOWeakInstance.h>
#import "AFOMediaTimer.h"
#import "AFOMediaManager.h"
#import "AFOMediaErrorCodeManager.h"
#import "AFOCountdownManager.h"
@interface AFOMediaManager (){
    AVFormatContext     *avFormatContext;
    AVCodecContext      *avCodecContext;
    AVFrame             *avFrame;
    VTDecompressionSessionRef _decompressSession;
    CMVideoFormatDescriptionRef _videoFormatDescription;
}

- (BOOL)avReadFrame:(NSInteger)duration;
- (void)freeResources;
/**输出视频Size*/
@property (nonatomic, assign) CGSize         outSize;
/**视频的长度，秒为单位*/
@property (nonatomic, assign) int64_t        duration;
/**视频的当前秒数*/
@property (nonatomic, assign) int64_t        currentTime;
/**视频的当前秒数*/
@property (nonatomic, assign) int64_t        nowTime;
/**视频的帧率*/
@property (nonatomic, assign) CGFloat         fps;
@property (nonatomic, assign)            NSInteger       videoStream;
@property (nonatomic, assign)            CGFloat         videoTimeBase;
@property (nonatomic, assign)            BOOL            isRelease;
@property (nonatomic, assign)            BOOL            isHardwareDecoding; // 标记是否使用硬件解码
@property (nonatomic, strong) AFOCountdownManager      *queueManager;
@property (nonatomic, weak) id<AFOPlayMediaManager>      delegate;
@end

@implementation AFOMediaManager

#pragma mark ------ init
- (instancetype)init{
    if (self = [super init]) {
     [INTUAutoRemoveObserver addObserver:self selector:@selector(freeResources) name:@"AFOPlayMediaManagerFreeResources" object:nil];
    }
    return self;
}
- (instancetype)initWithDelegate:(id<AFOPlayMediaManager>)delegate{
    if (self = [super init]) {
        _delegate = delegate;
        _isRelease = NO;
    }
    return self;
}
#pragma mark ------ displayVedio
- (void)displayVedioFormatContext:(AVFormatContext *)formatContext
                     codecContext:(AVCodecContext *)codecContext
                            index:(NSInteger)index
                            block:(displayVedioFrameBlock)block{
    NSLog(@"AFOMediaManager: displayVedioFormatContext called. Video Stream Index: %ld", (long)index);
    self.videoStream = index;
    avCodecContext = codecContext;
    avFormatContext =formatContext;
    avFrame = av_frame_alloc();

    // 检查是否配置了硬件解码
    self.isHardwareDecoding = (avCodecContext->hw_device_ctx != NULL);
    if (self.isHardwareDecoding) {
        NSLog(@"AFOMediaManager: Hardware decoding enabled.");
        // 如果是硬件解码，需要创建 VTDecompressionSession
        [self setupVideoToolboxDecompressionSessionWithCodecContext:avCodecContext];

    WeakObject(self);
    ///------
    [self.queueManager addCountdownActionFps:self.fps duration:weakself.duration block:^(NSNumber *isEnd) {
        if ([isEnd boolValue]) {
            block(NULL,
                  NULL, // 传递 NULL CVPixelBufferRef
                  [AFOMediaTimer timeFormatShort:weakself.duration],[AFOMediaTimer currentTime:weakself.nowTime + 1],
                  weakself.duration,
                  weakself.nowTime + 1);
            //
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AFOMediaSuspendedManager" object:nil];
            return ;
        }else{
            NSLog(@"AFOMediaManager: Countdown block executing. Attempting to read frame.");
            if ([weakself avReadFrame:weakself.videoStream]) {
                if (weakself.isHardwareDecoding) {
                    // 硬件解码，直接从 avFrame 获取 CVPixelBufferRef
                    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)avFrame->data[3]; // VT 解码后的 CVPixelBufferRef 在 data[3]
                    if (pixelBuffer) {
                        block(nil,
                              pixelBuffer,
                              [AFOMediaTimer timeFormatShort:weakself.duration],
                              [AFOMediaTimer currentTime:weakself.nowTime],
                              weakself.duration,
                              weakself.nowTime
                              );
                    } else {
                        NSLog(@"AFOMediaManager: Hardware decoded frame is nil.");
                        block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeDecoderImageFailure], nil, nil, nil, 0, 0);
                    }

                                }
            }else{
                block(nil, nil, nil, nil, 0, 0);
            }
        }
    }];
}
#pragma mark ------ stepFrame
- (BOOL)avReadFrame:(NSInteger)duration {
    AVPacket  packet;
    NSLog(@"AFOMediaManager: avReadFrame called for stream: %ld", (long)duration);
    while (av_read_frame(avFormatContext, &packet) >= 0) {
        if (packet.stream_index == duration) {
            NSLog(@"AFOMediaManager: Found video packet. Size: %d, DTS: %lld, PTS: %lld", packet.size, packet.dts, packet.pts);
            int ret = avcodec_send_packet(avCodecContext, &packet);
            if (ret == 0) {
                while (!avcodec_receive_frame(avCodecContext, avFrame)) {
                    NSLog(@"AFOMediaManager: Successfully decoded video frame. PTS: %lld", avFrame->pts);
                    double frameRate = av_q2d([self avStream] -> avg_frame_rate);
                    frameRate += avFrame->repeat_pict * (frameRate * 0.5);
                    self.nowTime = self.currentTime;
                    av_packet_unref(&packet);
                    return YES;
                }
            }else{
                NSLog(@"AFOMediaManager: avcodec_send_packet failed with error: %d", ret);
                return NO;
            }
        } else {
            // Unref other stream packets to avoid memory leaks
            av_packet_unref(&packet);
        }
    }
    NSLog(@"AFOMediaManager: End of file or no more frames to read.");
    return YES;
}
#pragma mark ------ AFOCountDownManagerDelegate
- (void)vedioFilePlayingDelegate{
    [self.delegate videoNowPlayingDelegate];
}
- (void)vedioFileFinishDelegate{
    [self.delegate videoFinishPlayingDelegate];
}
#pragma mark ------ 释放资源
- (void)freeResources{
    if (_isRelease) {
        return;
    }
    if (avFrame) {
        av_frame_free(&(avFrame));
    }
    //---
    if (avFormatContext) {
        avformat_close_input(&avFormatContext);
        avFormatContext = NULL;
    }
    //---
    if (avCodecContext) {
        avcodec_close(avCodecContext);
        avcodec_free_context(&avCodecContext);
        avCodecContext = NULL;
    }

    if (_decompressSession) {
        VTDecompressionSessionInvalidate(_decompressSession);
        CFRelease(_decompressSession);
        _decompressSession = NULL;
    }
    if (_videoFormatDescription) {
        CFRelease(_videoFormatDescription);
        _videoFormatDescription = NULL;
    }
    _isRelease = YES;
}}
#pragma mark ------------ property
- (AVStream *)avStream{
    AVStream *stream = avFormatContext -> streams[self.videoStream];
    return stream;
}
- (int64_t)duration{
    int64_t totalTime = [self avStream] -> duration * av_q2d([self avStream] -> time_base);
    if (totalTime > 0) {
          return [self avStream] -> duration * av_q2d([self avStream] -> time_base);
    }
    return  [AFOMediaTimer totalNumberSeconds:avFormatContext->duration];
}
- (int64_t)currentTime{
    AVRational timeBase = avFormatContext->streams[self.videoStream]->time_base;
    return avFrame->pts * (double)timeBase.num / timeBase.den;
}
- (CGFloat)fps{
    if([self avStream] ->avg_frame_rate.den && [self avStream] ->avg_frame_rate.num){
        return av_q2d([self avStream] -> avg_frame_rate);
    }
    return 30;
}
- (CGSize)outSize{
    return CGSizeMake(avFrame ->width, avFrame -> height);
}
- (AFOCountdownManager *)queueManager{
    if (!_queueManager) {
        _queueManager = [[AFOCountdownManager alloc] init];
    }
    return _queueManager;
}
- (void)setupVideoToolboxDecompressionSessionWithCodecContext:(AVCodecContext *)codecContext {
    if (_decompressSession) {
        return;
    }

    // 创建 CMVideoFormatDescriptionRef
    // 这里需要根据 AVCodecContext 的信息构建
    CMVideoFormatDescriptionRef formatDescription = NULL;
    OSStatus status = CMVideoFormatDescriptionCreate(kCFAllocatorDefault,
                                                     kCMVideoCodecType_H264, // 或 kCMVideoCodecType_H265
                                                     codecContext->width,
                                                     codecContext->height,
                                                     NULL, // Removed kCMFormatDescriptionExtension_KeyFrameBoosting
                                                     &formatDescription);
    if (status != noErr || !formatDescription) {
        NSLog(@"AFOMediaManager: Failed to create CMVideoFormatDescriptionRef: %d", (int)status);
        return;
    }
    _videoFormatDescription = formatDescription;

    // 配置 VTDecompressionSession
    NSDictionary *destinationPixelBufferAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), // NV12
        (id)kCVPixelBufferOpenGLESCompatibilityKey : @(YES),
        (id)kCVPixelBufferOpenGLCompatibilityKey : @(YES),
        (id)kCVPixelBufferMetalCompatibilityKey : @(YES)
    };

    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = videoDecompressionOutputCallback;
    callbackRecord.decompressionOutputRefCon = (__bridge void *)self;

    status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                          formatDescription,
                                          NULL, // decoderSpecification
                                          (__bridge CFDictionaryRef)destinationPixelBufferAttributes,
                                          &callbackRecord,
                                          &_decompressSession);

    if (status != noErr || !_decompressSession) {
        NSLog(@"AFOMediaManager: Failed to create VTDecompressionSession: %d", (int)status);
        CFRelease(formatDescription);
        _videoFormatDescription = NULL;
    }
}

#pragma mark ------------ dealloc
- (void)dealloc{
    [self freeResources];
    NSLog(@"AFOPlayMediaManager dealloc");
}
//                    [self.delegate videoTimeStamp:av_frame_get_best_effort_timestamp(avFrame) * av_q2d([self avStream] -> time_base) position:_videoTimeBase frameRate:frameRate];

@end

static void videoDecompressionOutputCallback(void *decompressionOutputRefCon,
                                             void *sourceFrameRefCon,
                                             OSStatus status,
                                             VTDecompressionSessionFlags infoFlags,
                                             CMTime presentationTimeStamp,
                                             CMTime presentationDuration,
                                             CVPixelBufferRef pixelBuffer,
                                             CMVideoFormatDescriptionRef formatDescription) {
    if (status != noErr) {
        NSLog(@"VideoToolbox Decompression failed: %d", (int)status);
        return;
    }

    AFOMediaManager *self = (__bridge AFOMediaManager *)decompressionOutputRefCon;
    if (self && pixelBuffer) {
        // 将 CVPixelBufferRef 传递给渲染层
        // 这里需要修改 AFOMediaManager 的 block 或 delegate 来传递 pixelBuffer
        // 例如：
        // if (self.displayBlock) {
        //     self.displayBlock(nil, pixelBuffer, ..., ...);
        // }
        // 在此示例中，我们假设 displayVedioFrameBlock 可以直接接收 CVPixelBufferRef
        // 注意：这里需要根据实际情况调整 block 的参数传递
        // 目前我们没有直接可用的 displayBlock，所以暂时注释，待后续实现渲染层时处理
        // if (self.videoManager.displayBlock) {
        //     self.videoManager.displayBlock(nil, pixelBuffer, nil, nil, 0, 0);
        // }
    }
    // 不要在此处释放 pixelBuffer，它由 VideoToolbox 管理
}
