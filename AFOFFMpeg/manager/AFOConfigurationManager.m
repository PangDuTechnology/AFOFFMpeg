//
//  AFOConfigurationManager.m
//  AFOFFMpeg
//
//  Created by xianxueguang on 2019/10/4.
//  Copyright © 2019年 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOConfigurationManager.h"
#import "AFOMediaConditional.h"
#import <VideoToolbox/VideoToolbox.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/pixfmt.h>
#include <libavcodec/videotoolbox.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_videotoolbox.h>
#import "AFOMediaManager.h"
// 辅助函数：从 extradata 中提取 SPS 和 PPS
static void getSPSAndPPSFromExtraData(const uint8_t *extradata, int extradata_size, NSData **spsData, NSData **ppsData) {
    if (!extradata || extradata_size < 7) { // Minimum size for AVCC extradata
        return;
    }

    int avcc_version = extradata[0];
    if (avcc_version != 1) {
        NSLog(@"AFOConfigurationManager: Unsupported AVCC version: %d", avcc_version);
        return;
    }

    // extradata[4] holds lengthSizeMinusOne for slice NAL lengths in packed samples; extracting SPS/PPS here uses explicit 16-bit lengths below.

    const uint8_t *p = extradata + 6; // Move past configurationVersion, AVCProfileIndication, profile_compatibility, AVCLevelIndication, lengthSizeMinusOne
    const uint8_t *end = extradata + extradata_size;

    // Read SPS
    uint16_t sps_count = (*p & 0x1F); // Number of SPS NAL units (usually 1)
    p++;

    for (int i = 0; i < sps_count; ++i) {
        if (p + 2 > end) return; // Not enough data for SPS length
        uint16_t sps_length = (p[0] << 8) | p[1];
        p += 2;
        if (p + sps_length > end) return; // Not enough data for SPS
        *spsData = [NSData dataWithBytes:p length:sps_length];
        p += sps_length;
    }

    // Read PPS
    uint8_t pps_count = *p; // Number of PPS NAL units (usually 1)
    p++;

    for (int i = 0; i < pps_count; ++i) {
        if (p + 2 > end) return; // Not enough data for PPS length
        uint16_t pps_length = (p[0] << 8) | p[1];
        p += 2;
        if (p + pps_length > end) return; // Not enough data for PPS
        *ppsData = [NSData dataWithBytes:p length:pps_length];
        p += pps_length;
    }
}

static enum AVPixelFormat AFOHWVideoToolboxGetFormat(AVCodecContext *s, const enum AVPixelFormat *fmt) {
    const enum AVPixelFormat *p;
    for (p = fmt; *p != AV_PIX_FMT_NONE; p++) {
        if (*p == AV_PIX_FMT_VIDEOTOOLBOX) {
            if (s->hwaccel_context == NULL) {
                NSLog(@"AFOConfigurationManager: Attempting to initialize VideoToolbox hardware acceleration.");
                int result = av_videotoolbox_default_init(s);
                if (result < 0) {
                    NSLog(@"AFOConfigurationManager: av_videotoolbox_default_init failed with error code: %d", result);
                    return s->pix_fmt;
                }
                NSLog(@"AFOConfigurationManager: av_videotoolbox_default_init successful. hwaccel_context: %p", s->hwaccel_context);
            }
            return *p;
        }
        ++p;
    }
    return AV_PIX_FMT_NONE;
}

@interface AFOConfigurationManager ()
@end
@implementation AFOConfigurationManager
+ (void)configurationStreamPath:(NSString *)strPath
                          block:(void(^)(NSError *error,
                                         NSInteger videoIndex,
                                         NSInteger audioIndex))block{
    [AFOMediaConditional mediaSesourcesConditionalPath:strPath block:^(NSError *error, NSInteger videoIndex, NSInteger audioIndex){
        if (error.code == 0) {
            block(error,videoIndex, audioIndex);
        }else{
            block(error,0, 0);
            return;
        }
    }];
}
+ (void)configurationForPath:(NSString *)strPath
                      stream:(NSInteger)stream
                       block:(AFOCodecConfiguredBlock)configured{
    [AFOMediaConditional mediaSesourcesConditionalPath:strPath block:^(NSError *error, NSInteger videoIndex, NSInteger audioIndex) {
        AFOMediaLog(@"AFOConfigurationManager: mediaSesourcesConditionalPath callback. Error: %ld, videoIndex: %ld, audioIndex: %ld", (long)error.code, (long)videoIndex, (long)audioIndex);
        if (error.code == 0) {
            AFOMediaLog(@"AFOConfigurationManager: Initializing FFmpeg contexts for stream: %ld", (long)stream);
            ///------------ video
           AVFormatContext *avFormatContext = avformat_alloc_context();
            avformat_open_input(&avFormatContext, [strPath UTF8String], NULL, NULL);
            AVCodecContext *avCodecContext = avcodec_alloc_context3(NULL);
            avcodec_parameters_to_context(avCodecContext, avFormatContext -> streams[stream] -> codecpar);
            AVCodec *avCodec = avcodec_find_decoder(avCodecContext -> codec_id);
            avCodecContext->get_format = AFOHWVideoToolboxGetFormat; // 自定义获取格式回调
            // 查找支持 VideoToolbox 的像素格式
            // 尝试配置硬件加速
            ///------ Find the decoder for the video stream.
            ///------ Open codec
            avcodec_open2(avCodecContext, avCodec, NULL);
            NSData *spsData = nil;
            NSData *ppsData = nil;
            if (avCodecContext->extradata_size > 0 && avCodecContext->extradata != NULL) {
                getSPSAndPPSFromExtraData(avCodecContext->extradata, avCodecContext->extradata_size, &spsData, &ppsData);
            }
            AFOMediaLog(@"AFOConfigurationManager: Calling block with FFmpeg contexts. avFormatContext: %p, avCodecContext: %p", avFormatContext, avCodecContext);
            configured(avCodec, avFormatContext, avCodecContext, videoIndex, audioIndex, spsData, ppsData);
        }else{
            configured(nil, nil, nil, 0, 0, nil, nil);
            return;
        }
    }];
}
@end
