//
//  AFOPlayMediaViewModel.m
//  AFOFFMpeg
//
//  Created by xueguang xian on 2017/12/28.
//  Copyright © 2017年 AFO Science and technology Ltd. All rights reserved.
//

#import <VideoToolbox/VideoToolbox.h>
#include <libavformat/avformat.h>
#include <string.h>
#include <libavutil/hwcontext.h>
#include <libavutil/opt.h>
#include <libavutil/pixfmt.h>
#include <libavutil/pixdesc.h> // 导入 av_get_pix_fmt_name 函数声明
#include <libswscale/swscale.h> // 导入 libswscale
#include <libavutil/error.h> // 导入 av_make_error_string 函数声明
#import "AFOMediaManager.h"
#import <AFOGitHub/INTUAutoRemoveObserver.h>
#import "AFOMediaTimer.h"
#import "AFOMediaManager.h"
#import "AFOMediaErrorCodeManager.h"
#import "AFOCountdownManager.h"
#import "AFOCountDownManagerDelegate.h"

#include <libavutil/frame.h>
#include <libavcodec/avcodec.h>

/// 是否为 VideoToolbox 硬件帧（含不同 FFmpeg 版本下的 videotoolbox / videotoolbox_vld 等命名）。
static BOOL AFO_AVFrameIsVideoToolboxHardware(AVFrame *frame) {
    if (!frame) {
        return NO;
    }
    if (frame->format == AV_PIX_FMT_VIDEOTOOLBOX || frame->format == AV_PIX_FMT_VDA) {
        return YES;
    }
    const char *name = av_get_pix_fmt_name(frame->format);
    return (name != NULL && strstr(name, "videotoolbox") != NULL);
}

/// VideoToolbox 解码输出：CVPixelBufferRef 以指针宽度保存在 data[3]，需经 uintptr_t 再转为 CVPixelBufferRef。
static CVPixelBufferRef AFO_CVPixelBufferFromVideoToolboxFrame(AVFrame *frame) {
    if (!AFO_AVFrameIsVideoToolboxHardware(frame)) {
        return NULL;
    }
    return (CVPixelBufferRef)(uintptr_t)frame->data[3];
}

@interface AFOMediaManager ()<AFOCountDownManagerDelegate>{
    AVFormatContext     *avFormatContext;
    AVCodecContext      *avCodecContext;
    AVFrame             *avFrame;
    struct SwsContext   *swsContext; // 声明 SwsContext 成员变量
    BOOL                softwareFallbackAttempted;
}
- (nullable NSError *)avReadFrame:(NSInteger)duration;
- (void)freeResources;
- (BOOL)afo_isVideoDecoderHardwareAccelerated;
- (BOOL)afo_reopenVideoDecoderSoftwareOnly;
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
- (void)displayVedioFormatContext:(struct AVFormatContext *)formatContext
                     codecContext:(struct AVCodecContext *)codecContext
                            index:(NSInteger)index
                            block:(displayVedioFrameBlock)block{
    AFOMediaLog(@"AFOMediaManager: displayVedioFormatContext called. Self: %p, formatContext (param): %p, codecContext (param): %p, Video Stream Index: %ld", self, formatContext, codecContext, (long)index);

    self.videoStream = index;
    avCodecContext = codecContext;
    avFormatContext =formatContext;
    AFOMediaLog(@"AFOMediaManager: After assigning avFormatContext. Self: %p, avFormatContext (member): %p", self, self->avFormatContext);

    AFOMediaLog(@"AFOMediaManager: Initial duration: %lld, fps: %f", self.duration, self.fps);
    avFrame = av_frame_alloc();
    softwareFallbackAttempted = NO;
    
    // VideoToolbox 可能只有 hwaccel_context，无 hw_device_ctx；软解时二者均为空。
    self.isHardwareDecoding = [self afo_isVideoDecoderHardwareAccelerated];
    AFOMediaLog(@"AFOMediaManager: hardware decode %s — starting countdown frame pump.", self.isHardwareDecoding ? "yes" : "no (software)");
    (void)self.queueManager;
    AFOMediaLog(@"AFOMediaManager: queueManager is initialized: %p", self.queueManager);
    CGFloat fpsVal = self.fps;
    int64_t durationVal = self.duration;
    __weak AFOMediaManager *weakManager = self;
    AFOMediaLog(@"AFOMediaManager: Calling addCountdownActionFps with fps: %f, duration: %lld", fpsVal, durationVal);
    [self.queueManager addCountdownActionFps:fpsVal duration:durationVal block:^(NSNumber *isEnd) {
            AFOMediaManager *manager = weakManager;
            if (!manager) {
                return;
            }
            if ([isEnd boolValue]) {
                block(NULL,
                      NULL, // 传递 NULL CVPixelBufferRef
                      [AFOMediaTimer timeFormatShort:manager.duration],[AFOMediaTimer currentTime:manager.nowTime + 1],
                      manager.duration,
                      manager.nowTime + 1,
                      YES); // 添加 isVideoEnd 参数
                if ([manager.delegate respondsToSelector:@selector(videoDidPauseDelegate:)]) {
                    [manager.delegate videoDidPauseDelegate:YES];
                }
                return ;
            }else{
                AFOMediaLog(@"AFOMediaManager: Countdown block executing. Attempting to read frame.");
                NSError *readFrameError = [manager avReadFrame:manager.videoStream];
                if (!readFrameError) {
                    CVPixelBufferRef pixelBuffer = nil;
                    BOOL frameIsVT = AFO_AVFrameIsVideoToolboxHardware(manager->avFrame);
                    if (frameIsVT) {
                        // 硬件帧：直接使用 CVPixelBuffer，禁止对 videotoolbox* 走 libswscale（不支持作输入）。
                        pixelBuffer = AFO_CVPixelBufferFromVideoToolboxFrame(manager->avFrame);
                        if (pixelBuffer) {
                            AFOMediaLog(@"AFOMediaManager: VideoToolbox frame -> CVPixelBuffer %p, FourCC: %u, t: %lld", pixelBuffer, (unsigned)CVPixelBufferGetPixelFormatType(pixelBuffer), manager.nowTime);
                        } else {
                            AFOMediaLog(@"AFOMediaManager: VideoToolbox frame but data[3] has no CVPixelBuffer; cannot fall back to sws for this format.");
                            block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeDecoderImageFailure], nil, nil, nil, 0, 0, NO);
                            return;
                        }
                    }

                    if (!frameIsVT) {
                        AFOMediaLog(@"AFOMediaManager: Software frame path (swscale). src fmt: %s", av_get_pix_fmt_name(manager->avFrame->format));
                        if (![manager setupSwsContextWithSrcPixelFormat:manager->avFrame->format]) {
                            AFOMediaLog(@"AFOMediaManager: Failed to setup SwsContext for software decoding.");
                            block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeImageorFormatConversionFailure], nil, nil, nil, 0, 0, NO);
                            return;
                        }
                        
                        // 创建 CVPixelBufferRef 用于软解码输出
                        NSDictionary *pixelBufferAttributes = @{
                            (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), // NV12
                            (id)kCVPixelBufferWidthKey : @(manager->avCodecContext->width),
                            (id)kCVPixelBufferHeightKey : @(manager->avCodecContext->height),
                            (id)kCVPixelBufferBytesPerRowAlignmentKey : @(manager->avCodecContext->width) // 行字节对齐
                        };
                        
                        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                                              manager->avCodecContext->width,
                                                              manager->avCodecContext->height,
                                                              kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, // NV12
                                                              (__bridge CFDictionaryRef)pixelBufferAttributes,
                                                              &pixelBuffer);
                        
                        if (status != kCVReturnSuccess || !pixelBuffer) {
                            AFOMediaLog(@"AFOMediaManager: Failed to create CVPixelBufferRef for software decoding. Status: %d", status);
                            block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeMemoryAllocationFailure], nil, nil, nil, 0, 0, NO);
                            return;
                        }
                        
                        // 获取 CVPixelBufferRef 的数据指针
                        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                        uint8_t *dest[4] = {0};
                        int dest_linesize[4] = {0};
                        
                        dest[0] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
                        dest_linesize[0] = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
                        dest[1] = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
                        dest_linesize[1] = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
                        
                        // 进行像素格式转换
                        sws_scale(manager->swsContext,
                                  (const uint8_t * const *)manager->avFrame->data,
                                  manager->avFrame->linesize,
                                  0,
                                  manager->avCodecContext->height,
                                  dest,
                                  dest_linesize);
                        
                        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                        
                        AFOMediaLog(@"AFOMediaManager: Software decoded frame converted to CVPixelBufferRef. Address: %p, Pixel Format: %u, Timestamp: %lld, Width: %zu, Height: %zu, BytesPerRowOfPlane0: %zu, BytesPerRowOfPlane1: %zu", pixelBuffer, CVPixelBufferGetPixelFormatType(pixelBuffer), manager.nowTime, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0), CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1));
                    }

                    if (pixelBuffer) {
                        // 硬件解码成功或软解码成功产生了 CVPixelBufferRef
                        block(nil,
                              pixelBuffer,
                              [AFOMediaTimer timeFormatShort:manager.duration],
                              [AFOMediaTimer currentTime:manager.nowTime],
                              manager.duration,
                              manager.nowTime,
                              NO // 添加 isVideoEnd 参数
                              );
                    } else {
                        // 硬件解码失败且软解码也未产生 CVPixelBufferRef（或未实现软解码转换）
                        AFOMediaLog(@"AFOMediaManager: No valid pixel buffer for rendering.");
                        block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeDecoderImageFailure], nil, nil, nil, 0, 0, NO);
                    }
                }else{
                    block(readFrameError, nil, nil, nil, 0, 0, NO);
                }
            }
        }];
}

- (void)setSuspended:(BOOL)suspended {
    if (suspended) {
        [self.queueManager pause];
        if ([self.delegate respondsToSelector:@selector(videoDidPauseDelegate:)]) {
            [self.delegate videoDidPauseDelegate:YES];
        }
    } else {
        [self.queueManager resume];
        if ([self.delegate respondsToSelector:@selector(videoDidPauseDelegate:)]) {
            [self.delegate videoDidPauseDelegate:NO];
        }
    }
}

- (void)cancelFramePump {
    [self.queueManager cancel];
}

#pragma mark ------ setup SwsContext
- (BOOL)setupSwsContextWithSrcPixelFormat:(enum AVPixelFormat)srcPixelFormat {
    if (swsContext) {
        sws_freeContext(swsContext);
        swsContext = NULL;
    }
    
    // 设置输出像素格式为 NV12，这是 iOS 硬件加速最常用的 YUV 格式
    enum AVPixelFormat outputPixelFormat = AV_PIX_FMT_NV12; 
    
    swsContext = sws_getContext(avCodecContext->width,
                                avCodecContext->height,
                                srcPixelFormat,
                                avCodecContext->width,
                                avCodecContext->height,
                                outputPixelFormat,
                                SWS_FAST_BILINEAR, // 快速双线性插值
                                NULL, NULL, NULL);
    
    if (!swsContext) {
        AFOMediaLog(@"AFOMediaManager: Could not initialize SwsContext for software scaling.");
        return NO;
    }
    AFOMediaLog(@"AFOMediaManager: SwsContext OK: %s -> %s", av_get_pix_fmt_name(srcPixelFormat), av_get_pix_fmt_name(outputPixelFormat));
    return YES;
}

#pragma mark ------ stepFrame
- (BOOL)afo_isVideoDecoderHardwareAccelerated {
    if (!avCodecContext) {
        return NO;
    }
    if (avCodecContext->hw_device_ctx) {
        return YES;
    }
    if (avCodecContext->hwaccel_context) {
        return YES;
    }
    if (avCodecContext->hwaccel) {
        return YES;
    }
    return NO;
}

/// 释放硬件解码器并按当前流 codecpar 重建纯软解（不设置 get_format / VideoToolbox）。
- (BOOL)afo_reopenVideoDecoderSoftwareOnly {
    if (!avFormatContext || self.videoStream < 0 || (unsigned)self.videoStream >= avFormatContext->nb_streams) {
        return NO;
    }
    AVStream *stream = avFormatContext->streams[self.videoStream];
    if (swsContext) {
        sws_freeContext(swsContext);
        swsContext = NULL;
    }
    avcodec_free_context(&avCodecContext);
    avCodecContext = avcodec_alloc_context3(NULL);
    if (!avCodecContext) {
        return NO;
    }
    if (avcodec_parameters_to_context(avCodecContext, stream->codecpar) < 0) {
        avcodec_free_context(&avCodecContext);
        return NO;
    }
    av_codec_set_pkt_timebase(avCodecContext, stream->time_base);
    const AVCodec *decoder = avcodec_find_decoder(avCodecContext->codec_id);
    if (!decoder) {
        avcodec_free_context(&avCodecContext);
        return NO;
    }
    if (avcodec_open2(avCodecContext, decoder, NULL) < 0) {
        avcodec_free_context(&avCodecContext);
        return NO;
    }
    self.isHardwareDecoding = NO;
    if (avFrame) {
        av_frame_unref(avFrame);
    }
    AFOMediaLog(@"AFOMediaManager: Switched to software decoder. pix_fmt=%s", av_get_pix_fmt_name(avCodecContext->pix_fmt));
    return YES;
}

- (nullable NSError *)avReadFrame:(NSInteger)duration {
    AVPacket  packet;
    AFOMediaLog(@"AFOMediaManager: avReadFrame called for stream: %ld", (long)duration);
    while (av_read_frame(avFormatContext, &packet) >= 0) {
        AFOMediaLog(@"AFOMediaManager: Packet read. Stream Index: %d, Size: %d, PTS: %lld, DTS: %lld", packet.stream_index, packet.size, packet.pts, packet.dts);
        if (packet.stream_index == duration) {
            AFOMediaLog(@"AFOMediaManager: Found video packet. Size: %d, DTS: %lld, PTS: %lld", packet.size, packet.dts, packet.pts);
            int ret = avcodec_send_packet(avCodecContext, &packet);
            if (ret != 0 && ret != AVERROR(EAGAIN)) {
                if (!softwareFallbackAttempted && [self afo_isVideoDecoderHardwareAccelerated]) {
                    AFOMediaLog(@"AFOMediaManager: send_packet failed (%d), trying software decoder fallback.", ret);
                    softwareFallbackAttempted = YES;
                    if ([self afo_reopenVideoDecoderSoftwareOnly]) {
                        ret = avcodec_send_packet(avCodecContext, &packet);
                    }
                }
            }
            if (ret == 0) {
                AFOMediaLog(@"AFOMediaManager: Packet sent to decoder successfully.");
                int frameReceiveRet;
                while ((frameReceiveRet = avcodec_receive_frame(avCodecContext, avFrame)) >= 0) {
                    if (frameReceiveRet < 0 && frameReceiveRet != AVERROR(EAGAIN) && frameReceiveRet != AVERROR_EOF) {
                        char errbuf[AV_ERROR_MAX_STRING_SIZE];
                        av_make_error_string(errbuf, AV_ERROR_MAX_STRING_SIZE, frameReceiveRet);
                        AFOMediaLog(@"AFOMediaManager: avcodec_receive_frame failed with error: %d (%s)", frameReceiveRet, errbuf);
                        av_packet_unref(&packet);
                        return [AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeDecoderFrameFailure];
                    }
                    AFOMediaLog(@"AFOMediaManager: Successfully decoded video frame. PTS: %lld, Width: %d, Height: %d, Pixel Format: %s", avFrame->pts, avFrame->width, avFrame->height, av_get_pix_fmt_name(avFrame->format));
                    double frameRate = av_q2d([self avStream] -> avg_frame_rate);
                    frameRate += avFrame->repeat_pict * (frameRate * 0.5);
                    self.nowTime = self.currentTime;
                    av_packet_unref(&packet);
                    return nil;
                }
                av_packet_unref(&packet);
                continue;
            } else {
                char errbuf[AV_ERROR_MAX_STRING_SIZE];
                av_make_error_string(errbuf, AV_ERROR_MAX_STRING_SIZE, ret);
                AFOMediaLog(@"AFOMediaManager: avcodec_send_packet failed with error: %d (%s)", ret, errbuf);
                av_packet_unref(&packet);
                return [AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeDecoderPacketFailure];
            }
        } else {
            // Unref other stream packets to avoid memory leaks
            av_packet_unref(&packet);
        }
    }
    AFOMediaLog(@"AFOMediaManager: End of file or no more frames to read.");
    return nil;
}
#pragma mark ------ AFOCountDownManagerDelegate
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
    //---
    if (swsContext) {
        sws_freeContext(swsContext);
        swsContext = NULL;
    }

    _isRelease = YES;
}
#pragma mark ------------ property
- (AVStream *)avStream{
    if (!avFormatContext || self.videoStream < 0 || self.videoStream >= avFormatContext->nb_streams) {
        AFOMediaLog(@"AFOMediaManager: avStream is NULL or videoStream index is invalid.");
        return NULL;
    }
    AVStream *stream = avFormatContext -> streams[self.videoStream];
    return stream;
}
- (int64_t)duration{
    AVStream *stream = [self avStream];
    if (!stream) {
        AFOMediaLog(@"AFOMediaManager: avStream is NULL in duration getter. Returning 0.");
        // Fallback to avFormatContext->duration if avStream is not available
        if (avFormatContext) {
             return [AFOMediaTimer totalNumberSeconds:avFormatContext->duration];
        }
        return 0;
    }
    int64_t totalTime = stream -> duration * av_q2d(stream -> time_base);
    if (totalTime > 0) {
          return stream -> duration * av_q2d(stream -> time_base);
    }
    // If stream duration is not reliable, use format context duration
    if (avFormatContext) {
        return  [AFOMediaTimer totalNumberSeconds:avFormatContext->duration];
    }
    return 0; // Default to 0 if all else fails
}
- (int64_t)currentTime{
    AVRational timeBase = avFormatContext->streams[self.videoStream]->time_base;
    return avFrame->pts * (double)timeBase.num / timeBase.den;
}
- (CGFloat)fps{
    AVStream *stream = [self avStream];
    if (!stream) {
        AFOMediaLog(@"AFOMediaManager: avStream is NULL in fps getter. Returning default 30.");
        return 30;
    }
    if(stream ->avg_frame_rate.den && stream ->avg_frame_rate.num){
        return av_q2d(stream -> avg_frame_rate);
    }
    return 30;
}
- (CGSize)outSize{
    return CGSizeMake(avFrame ->width, avFrame -> height);
}
- (AFOCountdownManager *)queueManager{
    if (!_queueManager) {
        AFOMediaLog(@"AFOMediaManager: Initializing queueManager (AFOCountdownManager).");
        _queueManager = [[AFOCountdownManager alloc] init];
        _queueManager.delegate = self;
    }
    AFOMediaLog(@"AFOMediaManager: queueManager getter called. Current instance: %p", _queueManager);
    return _queueManager;
}

#pragma mark - AFOCountDownManagerDelegate

- (void)vedioFilePlayingDelegate {
    if ([self.delegate respondsToSelector:@selector(videoNowPlayingDelegate)]) {
        [self.delegate videoNowPlayingDelegate];
    }
}

- (void)vedioFileSuspendedDelegate {
    if ([self.delegate respondsToSelector:@selector(videoDidPauseDelegate:)]) {
        [self.delegate videoDidPauseDelegate:YES];
    }
}

- (void)vedioFileFinishDelegate {
    if ([self.delegate respondsToSelector:@selector(videoFinishPlayingDelegate)]) {
        [self.delegate videoFinishPlayingDelegate];
    }
}

#pragma mark ------------ dealloc
- (void)dealloc{
    AFOMediaLog(@"AFOMediaManager: Deallocating instance: %p", self); // 添加日志
    [self freeResources];
    AFOMediaLog(@"AFOPlayMediaManager dealloc");
}

@end

