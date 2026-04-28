//
//  AFOMediaSeekFrame.m
//  AFOMediaPlay
//
//  Created by xueguang xian on 2018/1/5.
//  Copyright © 2018年 AFO Science Technology Ltd. All rights reserved.
//

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/frame.h>
#include <libavutil/imgutils.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>

#import "AFOMediaSeekFrame.h"
#import <AFOFoundation/AFOFoundation.h>
#import "AFOMediaSeekFrame+Conditional.h"
#import "AFOMediaThumbnail.h"
#import "AFOMediaConditional.h"
#import "AFOMediaYUV.h"
#import "AFOMediaErrorString.h"

@interface AFOMediaSeekFrame (){
    AVCodec *avcodec;
    AVFormatContext *avFormatContext;
    AVCodecContext *avCodecContext;
    AVFrame *avFrame;
}
@property (nonatomic, assign)  NSInteger              videoStream;
@property (nonatomic, assign)  int                    zoomFacto;
@property (nonatomic, assign)  int                    outWidth;
@property (nonatomic, assign)  int                    outHeight;
@property (nonatomic, strong)  AFOMediaConditional   *conditonal;
@property (nonnull, nonatomic, strong) AFOMediaYUV   *meidaYUV;
@end
@implementation AFOMediaSeekFrame
#pragma mark ------------ init
- (instancetype)init{
    if (self = [super init]) {
        ///---
        _videoStream = -1;
        avFormatContext = NULL;
        avCodecContext = avcodec_alloc_context3(NULL);
    }
    return self;
}
#pragma mark ------------
+ (instancetype)vedioName:(NSString *)name
                     path:(NSString *)path
                imagePath:(NSString *)imagePath
                    plist:(NSString *)plist
                    block:(mediaSeekFrameDetailBlock)detailCompletion{
    AFOMediaSeekFrame *seekFrame = NULL;
    if (name.length > 0){
        AFOMediaSeekFrame *temp = [[AFOMediaSeekFrame alloc] init];
        [temp avInitialize:path name:name imagePath:imagePath plist:plist block:^(BOOL isWrite,
                                                                                  BOOL isCutting,
                                                                                  NSString *createTime,
                                                                                  NSString *vedioName,
                                                                                  NSString *imageName,
                                                                                  int width,
                                                                                  int height) {
            if (detailCompletion) {
                detailCompletion(isWrite, isCutting, createTime, vedioName, imageName, width, height);
            }
        }];
        seekFrame = temp;
    }
    return seekFrame;
}
#pragma mark ------ 初始化
- (void)avInitialize:(NSString *)path
                name:(NSString *)name
           imagePath:(NSString *)imagePath
               plist:(NSString *)plist
               block:(mediaSeekFrameDetailBlock)detailCompletion{
    void (^notifyFail)(void) = ^{
        if (!detailCompletion) {
            return;
        }
        detailCompletion(NO, NO, @"0", name ?: @"", @"", 0, 0);
    };

    __block NSError *pathError = nil;
    WeakObject(self);
    [AFOMediaConditional mediaSesourcesConditionalPath:[AFOMediaSeekFrame vedioAddress:path name:name] block:^(NSError *error, NSInteger videoIndex, NSInteger audioIndex) {
        StrongObject(self);
        self.videoStream = videoIndex;
        pathError = error;
    }];
    if (pathError.code != AFOPlayMediaErrorNone) {
        notifyFail();
        return;
    }
    if (self.videoStream < 0) {
        notifyFail();
        return;
    }
    ///------ Open video file（由 avformat_open_input 内部分配 context，勿预先 alloc）    
    NSString *fullMediaPath = [AFOMediaSeekFrame vedioAddress:path name:name];
    if (avFormatContext) {
        avformat_close_input(&avFormatContext);
        avFormatContext = NULL;
    }
    int openRet = [AFOMediaConditional openLocalPathToFormatContext:fullMediaPath outContext:&avFormatContext];
    if (openRet != 0) {
        char errbuf[128];
        av_strerror(openRet, errbuf, sizeof(errbuf));
        NSLog(@"AFOMediaSeekFrame: 无法打开 (%d) %s — path=%@", openRet, errbuf, fullMediaPath);
        notifyFail();
        return;
    }
    ///------ Retrieve stream information.
    if (avformat_find_stream_info(avFormatContext, NULL) < 0) {
        notifyFail();
        return;
    }
    if (self.videoStream >= (NSInteger)avFormatContext->nb_streams) {
        notifyFail();
        return;
    }
    avcodec_parameters_to_context(avCodecContext, avFormatContext->streams[self.videoStream]->codecpar);
    ///------ Find the decoder for the video stream.
    avcodec = avcodec_find_decoder(avCodecContext->codec_id);
    if (!avcodec) {
        notifyFail();
        return;
    }
    ///------ Open codec
    if (avcodec_open2(avCodecContext, avcodec, NULL) < 0) {
        notifyFail();
        return;
    }
    ///------ 正常流程，分配视频帧
    avFrame = av_frame_alloc();
    if (!avFrame) {
        notifyFail();
        return;
    }
    [self firstFrameToCover:[AFOMediaThumbnail vedioAddress:path name:name] name:name imagePath:imagePath completion:^(BOOL isWrite, BOOL isCutting) {
        if (!detailCompletion) {
            return;
        }
        detailCompletion(isWrite, isCutting, [self createTime], name ?: @"", [AFOMediaThumbnail imageName:name], self.outWidth, self.outHeight);
    }];
}
#pragma mark ------ 将第一帧作为封面
- (void)firstFrameToCover:(NSString *)path
                     name:(NSString *)name
                imagePath:(NSString *)imagePath
                completion:(mediaSeekFrameBlock)completion{
    AVPacket packet;
    av_init_packet(&packet);
    int readRet;
    while ((readRet = av_read_frame(avFormatContext, &packet)) >= 0) {
        if (packet.stream_index != self.videoStream) {
            av_packet_unref(&packet);
            continue;
        }
        if (avcodec_send_packet(avCodecContext, &packet) < 0) {
            av_packet_unref(&packet);
            continue;
        }
        av_packet_unref(&packet);

        int frm;
        while ((frm = avcodec_receive_frame(avCodecContext, avFrame)) == 0) {
            if (avFrame->width <= 0 || avFrame->height <= 0) {
                continue;
            }
            // H.264/HEVC 等常不把 key_frame 置 1；旧逻辑只在 key_frame==1 时出图会导致无回调。
            [AFOMediaYUV makeYUVToRGB:avFrame width:avFrame->width height:avFrame->height scale:1.0 block:^(UIImage * _Nullable image, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"AFOMediaSeekFrame: Error converting YUV to RGB for thumbnail: %@", error.localizedDescription);
                    completion(NO, NO);
                    return;
                }
                NSString *strPath = [NSString stringWithFormat:@"%@/%@", imagePath, [AFOMediaThumbnail imageName:name]];
                BOOL result = [UIImagePNGRepresentation(image) writeToFile:strPath atomically:YES];
                completion(result, result);
            }];
            return;
        }
        if (frm != AVERROR(EAGAIN) && frm < 0) {
            break;
        }
    }

    if (readRet < 0 && readRet != AVERROR_EOF) {
        NSLog(@"AFOMediaSeekFrame: av_read_frame failed: %d", readRet);
    }
    completion(NO, NO);
}
#pragma mark ------------ free
- (void)freeResources{
    ///------
    if (avFrame) {
        av_frame_free(&avFrame);
    }
    //------ 关闭解码器
    if (avCodecContext){
        avcodec_close(avCodecContext);
    };
    //------ 关闭文件
    if (avFormatContext) {
        avformat_close_input(&(avFormatContext));
        avFormatContext = NULL;
    }
    ///------
    avcodec_free_context(&avCodecContext);
    avCodecContext = NULL;
    ///------
    avcodec = NULL;
}
#pragma mark ------------ property
- (AFOMediaYUV *)meidaYUV{
    if (!_meidaYUV) {
        _meidaYUV = [[AFOMediaYUV alloc] init];
    }
    return _meidaYUV;
}
#pragma mark ------ zoomFacto
- (int)zoomFacto{
    _zoomFacto = 2;
    return _zoomFacto;
}
#pragma mark ------ outWidth
- (int)outWidth{
    _outWidth = avCodecContext->width / self.zoomFacto;
    return _outWidth;
}
#pragma mark ------ outHeight
- (int)outHeight{
    _outHeight = avCodecContext->height / self.zoomFacto;
    return _outHeight;
}
#pragma mark ------
- (NSString *)createTime{
    AVDictionaryEntry *entry = NULL;
    entry = av_dict_get(avFormatContext -> metadata, "creation_time", NULL, AV_DICT_IGNORE_SUFFIX);
    if (!entry) {
        return @"0";
    }
    return [NSString stringWithUTF8String:entry -> value];
}
#pragma mark ------
- (AFOMediaConditional *)conditonal{
    if (!_conditonal) {
        _conditonal = [[AFOMediaConditional alloc] init];
    }
    return _conditonal;
}
#pragma mark ------ dealloc
- (void)dealloc{
    [self freeResources];
    NSLog(@"AFOMediaSeekFrame dealloc");
}
@end
