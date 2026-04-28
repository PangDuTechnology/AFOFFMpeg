//
//  AFOVideoFrame.m
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/2/2.
//  Copyright © 2018年 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOVideoFrame.h"
#include <libavutil/frame.h>
#include <libavcodec/avcodec.h>
#import "AFOVideoFrameYUV.h"
#import "AFOVideoFrameRGB.h"

@interface AFOVideoFrame ()
@property (nonatomic, assign, readwrite) AFOVideoFrameFormatType    formatType;
@property (nonatomic, assign, readwrite) NSInteger                  width;
@property (nonatomic, assign, readwrite) NSInteger                  hight;
@end

@implementation AFOVideoFrame
+ (id)videoFrame:(struct AVFrame *)frame
    codecContext:(struct AVCodecContext *)codecContext
            type:(AFOVideoFrameFormatType)formatType{
    switch (formatType) {
        case AFOVideoFrameFormatRGB:
            break;
        case AFOVideoFrameFormatYUV:{
           return  [AFOVideoFrameYUV videoFrameYUV:frame codecContext:codecContext];
        }
            break;
        default:
            break;
    }
    return [[AFOVideoFrame alloc] init];
}
@end
