//
//  AFOVideoFrame.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/2/2.
//  Copyright © 2018年 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOMediaFrame.h"

struct AVFrame;
struct AVCodecContext;
typedef NS_ENUM(NSInteger, AFOVideoFrameFormatType) {
    AFOVideoFrameFormatRGB       =   0,
    AFOVideoFrameFormatYUV       =   1,
};
@interface AFOVideoFrame : AFOMediaFrame
@property (nonatomic, assign, readonly) AFOVideoFrameFormatType    formatType;
@property (nonatomic, assign, readonly) NSInteger                  width;
@property (nonatomic, assign, readonly) NSInteger                  hight;
+ (id)videoFrame:(struct AVFrame *)frame
    codecContext:(struct AVCodecContext *)codecContext
            type:(AFOVideoFrameFormatType)formatType;
@end
