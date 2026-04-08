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
#include <libavcodec/videotoolbox.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_videotoolbox.h>
// 辅助函数：从 extradata 中提取 SPS 和 PPS
static void getSPSAndPPSFromExtraData(const uint8_t *extradata, int extradata_size, NSData **spsData, NSData **ppsData) {
    if (!extradata || extradata_size < 4) {
        return;
    }

    const uint8_t *p = extradata;
    const uint8_t *end = extradata + extradata_size;

    while (p + 4 < end) {
        if (p[0] == 0x00 && p[1] == 0x00 && p[2] == 0x00 && p[3] == 0x01) {
            // 找到起始码
            p += 4;
            if ((*p & 0x1F) == 7) { // NAL 单元类型 7 是 SPS
                const uint8_t *nextStartCode = NULL;
                const uint8_t *q = p;
                while (q + 4 < end) {
                    if (q[0] == 0x00 && q[1] == 0x00 && q[2] == 0x00 && q[3] == 0x01) {
                        nextStartCode = q;
                        break;
                    }
                    q++;
                }
                *spsData = [NSData dataWithBytes:p length:(nextStartCode ? (nextStartCode - p) : (end - p))];
                if (nextStartCode) {
                    p = nextStartCode;
                    continue;
                }
            } else if ((*p & 0x1F) == 8) { // NAL 单元类型 8 是 PPS
                const uint8_t *nextStartCode = NULL;
                const uint8_t *q = p;
                while (q + 4 < end) {
                    if (q[0] == 0x00 && q[1] == 0x00 && q[2] == 0x00 && q[3] == 0x01) {
                        nextStartCode = q;
                        break;
                    }
                    q++;
                }
                *ppsData = [NSData dataWithBytes:p length:(nextStartCode ? (nextStartCode - p) : (end - p))];
                if (nextStartCode) {
                    p = nextStartCode;
                    continue;
                }
            }
        }
        p++;
    }
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
                        block:(void(^)(
                                       AVCodec *codec,
                                       AVFormatContext *format, AVCodecContext *context,
                                       NSInteger videoStream,
                                       NSInteger audioStream))block{
    [AFOMediaConditional mediaSesourcesConditionalPath:strPath block:^(NSError *error, NSInteger videoIndex, NSInteger audioIndex) {
        if (error.code == 0) {
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
            block(avCodec,avFormatContext,avCodecContext,videoIndex,audioIndex,spsData,ppsData);
        }else{
            block(NULL,NULL,NULL,0,0,nil,nil);
            return;
        }
    }];
}
@end

enum AVPixelFormat AFOHWVideoToolboxGetFormat(AVCodecContext *s, const enum AVPixelFormat *fmt) {
    const enum AVPixelFormat *p;
    for (p = fmt; *p != AV_PIX_FMT_NONE; p++) {
        if (*p == AV_PIX_FMT_VIDEOTOOLBOX) {
            // 如果尚未初始化,调用 VideoToolbox 初始化函数
            if (s->hwaccel_context == NULL) {
                int result = av_videotoolbox_default_init(s);
                if (result < 0) {
                    NSLog(@"AFOConfigurationManager: av_videotoolbox_default_init failed: %d", result);
                    return s->pix_fmt; // 初始化失败则回退
                }
            }
            return *p;
        }
        ++p;
    }
    return AV_PIX_FMT_NONE;
}
