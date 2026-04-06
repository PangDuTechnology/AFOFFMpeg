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
#include <libavutil/hwcontext_videotoolbox.h>
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
    [AFOMediaConditional mediaSesourcesConditionalPath:strPath block:^(NSError *error, NSInteger videoIndex, NSInteger audioIndex){
        if (error.code == 0) {
            ///------------ video
           AVFormatContext *avFormatContext = avformat_alloc_context();
            avformat_open_input(&avFormatContext, [strPath UTF8String], NULL, NULL);
            AVCodecContext *avCodecContext = avcodec_alloc_context3(NULL);
            avcodec_parameters_to_context(avCodecContext, avFormatContext -> streams[stream] -> codecpar);

            // 尝试配置硬件加速
            enum AVHWDeviceType type = av_hwdevice_find_type_by_name("videotoolbox");
            if (type != AV_HWDEVICE_TYPE_NONE) {
                AVBufferRef *hw_device_ctx = NULL;
                int err = av_hwdevice_create_by_type(&hw_device_ctx, type, NULL, NULL, 0);
                if (err == 0) {
                    avCodecContext->hw_device_ctx = hw_device_ctx;
                    avCodecContext->get_format = AFOHWVideoToolboxGetFormat; // 自定义获取格式回调
                    // 查找支持 VideoToolbox 的像素格式
                    for (int i = 0; i < avCodec->num_data_formats; i++) {
                        if (avCodec->data_formats[i] == AV_PIX_FMT_VIDEOTOOLBOX) {
                            avCodecContext->opaque = (__bridge void*)@(AV_PIX_FMT_VIDEOTOOLBOX);
                            break;
                        }
                    }
                } else {
                    NSLog(@"AFOConfigurationManager: Failed to create hardware device context for VideoToolbox, error: %d", err);
                }
            } else {
                NSLog(@"AFOConfigurationManager: VideoToolbox hardware device type not found.");
            }

            ///------ Find the decoder for the video stream.
            AVCodec *avCodec = avcodec_find_decoder(avCodecContext -> codec_id);
            ///------ Open codec
            avcodec_open2(avCodecContext, avCodec, NULL);
            block(avCodec,avFormatContext,avCodecContext,videoIndex,audioIndex);
        }else{
            return;
        }
    }];
}
@end

static enum AVPixelFormat AFOHWVideoToolboxGetFormat(AVCodecContext *s, const enum AVPixelFormat *fmt) {
    const enum AVPixelFormat *p;
    for (p = fmt; *p != AV_PIX_FMT_NONE; p++) {
        if (*p == AV_PIX_FMT_VIDEOTOOLBOX) {
            return *p;
        }
    }
    return AV_PIX_FMT_NONE;
}
