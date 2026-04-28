//
//  AFOGenerateImages.h
//  AFOPlayer
//
//  Created by xueguang xian on 2017/12/30.
//  Copyright © 2017年 AFO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

struct AVFrame;
struct AVCodecContext;
struct SwsContext;

typedef void(^generateSwsContextBlock)(struct SwsContext *context, NSError *error);

typedef void(^generateImageBlock)(UIImage *image, NSError *error);

typedef void(^avframeWithContextBlock)(struct AVFrame *frame, uint8_t *buffer);

@interface AFOGenerateImages : NSObject

- (void)decodingImageWithAVFrame:(struct AVFrame *)avFrame
                    codecContext:(struct AVCodecContext *)avCodecContext
                         outSize:(CGSize)outSize
                       srcFormat:(int)srcFormat
                       dstFormat:(int)dstFormat
                     pixelFormat:(int)format
                bitsPerComponent:(size_t)component
                    bitsPerPixel:(size_t)pixel
                           block:(generateImageBlock)block;

- (void)decoedImageForYUV:(struct AVFrame *)avFrame
                  outSize:(CGSize)outSize
                    block:(generateImageBlock)block;
@end
