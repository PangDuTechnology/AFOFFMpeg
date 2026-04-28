//
//  AFOMediaConditional.m
//  AFOMediaPlay
//
//  Created by xueguang xian on 2018/1/5.
//  Copyright © 2018年 AFO Science Technology Ltd. All rights reserved.
//
#import "AFOMediaConditional.h"
#import <libavformat/avformat.h>
#import <libavformat/version.h>
#import <libavutil/error.h>
#import <errno.h>
#import "AFOMediaErrorCodeManager.h"

/// 静态库 FFmpeg：避免 demuxer 目标文件被链接器裁剪；并做网络子系统初始化（本地 file 也建议调一次）。
static void AFOFFmpegEnsureFormatsLoaded(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        avformat_network_init();
#if LIBAVFORMAT_VERSION_MAJOR >= 58
        void *opaque = NULL;
        const AVInputFormat *fmt;
        while ((fmt = av_demuxer_iterate(&opaque))) {
            (void)fmt;
        }
#else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        av_register_all();
#pragma clang diagnostic pop
#endif
    });
}

/// FFmpeg/POSIX 应使用与文件系统一致的 C 路径；仅用 UTF8String 在部分含特殊字符/规范化路径下会导致 avformat_open_input 失败，而 NSFileManager 仍认为文件存在。
static const char *AFOFFmpegOpenPathCString(NSString *path) {
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

@implementation AFOMediaConditional

+ (int)openLocalPathToFormatContext:(NSString *)path outContext:(AVFormatContext *__nullable *__nonnull)outCtx {
    if (!outCtx || path.length == 0) {
        return AVERROR(EINVAL);
    }
    *outCtx = NULL;
    AFOFFmpegEnsureFormatsLoaded();

    NSString *std = path.stringByStandardizingPath;
    NSMutableOrderedSet<NSString *> *posixPaths = [NSMutableOrderedSet orderedSet];
    if (std.length > 0) {
        [posixPaths addObject:std];
    }
    NSString *resolved = (std.length > 0)
        ? [NSURL fileURLWithPath:std].URLByResolvingSymlinksInPath.path
        : nil;
    if (resolved.length > 0 && ![resolved isEqualToString:std]) {
        [posixPaths addObject:resolved];
    }
    NSString *pathForURL = (resolved.length > 0) ? resolved : std;

    AVFormatContext *ctx = NULL;
    int ret = AVERROR(EINVAL);
    for (NSString *tryPath in posixPaths) {
        const char *pathC = AFOFFmpegOpenPathCString(tryPath);
        if (!pathC) {
            ret = AVERROR(ENOENT);
            continue;
        }
        ctx = NULL;
        ret = avformat_open_input(&ctx, pathC, NULL, NULL);
        if (ret == 0) {
            *outCtx = ctx;
            return 0;
        }
        char ebuf[128];
        av_strerror(ret, ebuf, sizeof(ebuf));
        NSLog(@"[AFOFFmpeg] open POSIX (%d) %s — %@", ret, ebuf, tryPath);
        if (ctx) {
            avformat_close_input(&ctx);
            ctx = NULL;
        }
    }

    if (pathForURL.length > 0) {
        NSURL *fileURL = [NSURL fileURLWithPath:pathForURL];
        NSString *urlString = fileURL.absoluteString;
        const char *urlUtf8 = urlString.UTF8String;
        if (urlUtf8 && urlUtf8[0]) {
            ret = avformat_open_input(&ctx, urlUtf8, NULL, NULL);
            if (ret == 0) {
                *outCtx = ctx;
                return 0;
            }
            char ebuf[128];
            av_strerror(ret, ebuf, sizeof(ebuf));
            NSLog(@"[AFOFFmpeg] open file URL (%d) %s — %@", ret, ebuf, urlString);
            if (ctx) {
                avformat_close_input(&ctx);
                ctx = NULL;
            }
        }
    }

    return ret;
}

#pragma mark ------------ 
+ (void)mediaSesourcesConditionalPath:(NSString *)path
                            block:(MediaConditionalBlock) block{
    AVFormatContext   *avFormatContext = NULL;
    AVCodecContext    *avCodecContext;
    AVCodec           *avCodec;
   __block NSInteger videoStream = -1;
   __block NSInteger audioStream = -1;
    int openRet = [self openLocalPathToFormatContext:path outContext:&avFormatContext];
    if (openRet != 0){
        char errbuf[128];
        av_strerror(openRet, errbuf, sizeof(errbuf));
        NSLog(@"AFOMediaConditional: 无法打开媒体文件 (%d) %s — path=%@", openRet, errbuf, path);
        if (avFormatContext) {
            avformat_close_input(&avFormatContext);
        }
        block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeReadFailure libavformatOpenReturn:openRet path:path],0,0);
        return;
    }
    ///------ Retrieve stream information.
    if (avformat_find_stream_info(avFormatContext, NULL) < 0) {
        avformat_close_input(&avFormatContext);
        block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeRetrieveStreamInformationFailure],0,0);
        return;
    }
    ///------ Dump information about file onto standard error.
#if DEBUG
    const char *pathC = AFOFFmpegOpenPathCString(path);
    av_dump_format(avFormatContext, 0, pathC ? pathC : "", 0);
#endif
    ///------
    [self audioVideoStreamFormat:avFormatContext block:^(NSInteger video, NSInteger audio) {
        if (video == -1 && audio == -1){
            block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeAllocateCodecContextFailure],0,0);
            return ;
        }
        videoStream = video;
        audioStream = audio;
    }];
    ///------ Get a pointer to the codec context for the video stream.
    avCodecContext = avcodec_alloc_context3(NULL);
    ///------
    [self avCodecDecoder:avCodecContext format:avFormatContext videoIndex:videoStream audioIndex:audioStream block:^(BOOL isTrue, BOOL isOpen) {
        if (!isTrue && isOpen) {
            block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeAllocateCodecContextFailure],videoStream,audioStream);
            return;
        }
        if (isTrue && !isOpen) {
            block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorCodeOpenDecoderFailure],videoStream,audioStream);
            return;
        }
    }];
    ///------- return ture
    block([AFOMediaErrorCodeManager errorCode:AFOPlayMediaErrorNone],videoStream,audioStream);
    //------ 关闭解码器
    if (avCodecContext){
        avcodec_close(avCodecContext);
    };
    avCodecContext = NULL;
    //------ 关闭文件
    if (avFormatContext){
        avformat_close_input(&avFormatContext);
    };
    avFormatContext = NULL;
    ///------
    avcodec_free_context(&avCodecContext);
    avCodecContext = NULL;
    ///------
    avCodec = NULL;
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
                        block:(void(^)(NSInteger video, NSInteger audio))block{
    NSInteger resultV = [self audioVideoStream:AVMEDIA_TYPE_VIDEO format:avFormatContext];
    NSInteger resultA = [self audioVideoStream:AVMEDIA_TYPE_AUDIO format:avFormatContext];
    block(resultV,resultA);
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
            audioIndex:(NSInteger)audio
                 block:(void (^)(BOOL isTrue, BOOL isOpen))block{
    AVCodec *avCodecV = NULL;
    AVCodec *avCodecAu = NULL;
    if (video != -1 && audio == -1) {
        avCodecV = [self avCodec:avCodecContext format:avFormatContext index:video];
        if (avCodecV == NULL) {
            block(NO,YES);
        }
        ///------ Open codec
        if(avcodec_open2(avCodecContext, avCodecV, NULL) < 0){
            block(YES,NO);
        }
    }else if(video == -1 && audio != -1){
        avCodecAu = [self avCodec:avCodecContext format:avFormatContext index:audio];
        if (avCodecV == NULL) {
            block(NO,YES);
        }
        ///------ Open codec
        if(avcodec_open2(avCodecContext, avCodecV, NULL) < 0){
            block(YES,NO);
        }
    }else if(video != -1 && audio != -1){
        ///---
        AVCodecContext *avCodecContextV = avcodec_alloc_context3(NULL);
        avCodecV = [self avCodec:avCodecContextV format:avFormatContext index:video];
        ///---
        AVCodecContext *avCodecContextAu= avcodec_alloc_context3(NULL);
        avCodecAu = [self avCodec:avCodecContextAu format:avFormatContext index:audio];
        ///---
        if (avCodecV == NULL && avCodecAu == NULL) {
            block(NO,YES);
        }
        ///------ Open codec
        if(avcodec_open2(avCodecContextV, avCodecV, NULL) < 0 && avcodec_open2(avCodecContextAu, avCodecAu, NULL) < 0){
            block(YES,NO);
        }
    }
}
#pragma mark ------ dealloc
- (void)dealloc{
    NSLog(@"AFOMediaConditional dealloc");
}
@end
