//
//  AFOConfigurationManager.m
//  AFOFFMpeg
//
//  Created by xianxueguang on 2019/10/4.
//  Copyright © 2019年 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOConfigurationManager.h"
#import "AFOMediaConditional.h"
@interface AFOConfigurationManager (){
    AVCodec             *avCodec;
    AVFormatContext     *avFormatContext;
    AVCodecContext      *avCodecContext;
}
@end
@implementation AFOConfigurationManager
- (void)configurationForPath:(NSString *)strPath
                      stream:(NSInteger)stream
                        block:(void(^)(
                                       AVCodec *codec,
                                       AVFormatContext *format, AVCodecContext *context,
                                       NSInteger videoStream,
                                      NSInteger audioStream))block{
    [AFOMediaConditional mediaSesourcesConditionalPath:strPath block:^(NSError *error, NSInteger videoIndex, NSInteger audioIndex){
        if (error.code == 0) {
            ///------------ video
           self->avFormatContext = avformat_alloc_context();
            avformat_open_input(&self->avFormatContext, [strPath UTF8String], NULL, NULL);
            self->avCodecContext = avcodec_alloc_context3(NULL);
            avcodec_parameters_to_context(self->avCodecContext, self->avFormatContext -> streams[stream] -> codecpar);
            ///------ Find the decoder for the video stream.
            self->avCodec = avcodec_find_decoder(self->avCodecContext -> codec_id);
            ///------ Open codec
            avcodec_open2(self->avCodecContext, self->avCodec, NULL);
            block(self->avCodec,self->avFormatContext,self->avCodecContext,videoIndex,audioIndex);
        }else{
            return;
        }
    }];
}
@end
