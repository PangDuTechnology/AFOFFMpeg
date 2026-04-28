//
//  AFOMediaSeekFrame+Conditional.m
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/18.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOMediaSeekFrame+Conditional.h"
#import "AFOMediaErrorCodeManager.h"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/error.h>
#include <errno.h>

static const char *AFOFFmpegOpenPathCStringSeek(NSString *path) {
    if (path.length == 0) {
        return NULL;
    }
    NSString *standard = path.stringByStandardizingPath;
    const char *fs = standard.fileSystemRepresentation;
    if (fs && fs[0] != '\0') {
        return fs;
    }
    return standard.UTF8String;
}

@implementation AFOMediaSeekFrame (Conditional)
+ (void)mediaSesourcesConditionalPath:(NSString *)path
                        formatContext:(struct AVFormatContext *)avFormatContext
                         codecContext:(struct AVCodecContext *)avCodecContext
                                block:(MediaSeekFrameBlock) block{
    (void)avFormatContext;
    AVFormatContext *fmt_ctx = NULL;
    __block NSInteger videoStream = -1;
    const char *pathC = AFOFFmpegOpenPathCStringSeek(path);
    int openRet = (!pathC) ? AVERROR(ENOENT) : avformat_open_input(&fmt_ctx, pathC, NULL, NULL);
    if (openRet != 0) {
        char errbuf[128];
        av_strerror(openRet, errbuf, sizeof(errbuf));
        NSLog(@"AFOMediaSeekFrame+Conditional: avformat_open_input failed (%d) %s — path=%@", openRet, errbuf, path);
        if (fmt_ctx) {
            avformat_close_input(&fmt_ctx);
        }
        block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeReadFailure], 0, NULL);
        return;
    }
    ///------ Retrieve stream information.
    if (avformat_find_stream_info(fmt_ctx, NULL) < 0) {
        avformat_close_input(&fmt_ctx);
        block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeRetrieveStreamInformationFailure], 0, NULL);
        return;
    }
    ///------ Dump information about file onto standard error.
#if DEBUG
    av_dump_format(fmt_ctx, 0, pathC, 0);
#endif
    ///------
    [self audioVideoStreamFormat:fmt_ctx block:^(NSInteger video) {
        if (video == -1){
            block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeAllocateCodecContextFailure], 0, fmt_ctx);
            return ;
        }
        videoStream = video;
    }];
    ///------
    [self avCodecDecoder:avCodecContext format:fmt_ctx videoIndex:videoStream block:^(BOOL isTrue, BOOL isOpen) {
        if (!isTrue && isOpen) {
            block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeAllocateCodecContextFailure], videoStream, fmt_ctx);
            return;
        }
        if (isTrue && !isOpen) {
            block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeOpenDecoderFailure], videoStream, fmt_ctx);
            return;
        }
    }];
    block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorNone], videoStream, fmt_ctx);
}
#pragma mark ------ first video or audio Fault tolerance
+ (NSInteger)audioVideoStream:(enum AVMediaType)type
                       format:(AVFormatContext *)avFormatContext{
    NSInteger result = av_find_best_stream(avFormatContext,
                                           type,
                                           -1,
                                           -1,
                                           NULL,
                                           0);
    return result;
}
+ (void)audioVideoStreamFormat:(AVFormatContext *)avFormatContext
                         block:(void(^)(NSInteger video))block{
    NSInteger resultV = [self audioVideoStream:AVMEDIA_TYPE_VIDEO format:avFormatContext];
    block(resultV);
}
#pragma mark ------ codec context Fault tolerance
+ (AVCodec *)avCodec:(AVCodecContext *)avCodecContext
              format:(AVFormatContext *)avFormatContext
               index:(NSInteger)index{
    avcodec_parameters_to_context(avCodecContext, avFormatContext -> streams[index] -> codecpar);
    return avcodec_find_decoder(avCodecContext -> codec_id);
}
+ (void)avCodecDecoder:(AVCodecContext *)avCodecContext
                format:(AVFormatContext *)avFormatContext
            videoIndex:(NSInteger)video
                 block:(void (^)(BOOL isTrue, BOOL isOpen))block{
    AVCodec *avCodecV = NULL;
    if (video != -1) {
        avCodecV = [self avCodec:avCodecContext format:avFormatContext index:video];
        if (avCodecV == NULL) {
            block(NO,YES);
        }
        ///------ Open codec
        if(avcodec_open2(avCodecContext, avCodecV, NULL) < 0){
            block(YES,NO);
        }
    }
}
+ (NSString *)vedioAddress:(NSString *)path
                      name:(NSString *)name{
    NSString *string = [NSString stringWithFormat:@"%@/%@",path,name];
    return string;
}
@end
