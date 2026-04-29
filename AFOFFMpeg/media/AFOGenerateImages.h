//
//  AFOGenerateImages.h
//  AFOPlayer
//
//  Created by xueguang xian on 2017/12/30.
//  Copyright © 2017年 AFO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

struct AVFrame;
struct AVCodecContext;
struct SwsContext;

typedef void (^generateSwsContextBlock)(struct SwsContext * _Nullable context, NSError * _Nullable error);

typedef void (^generateImageBlock)(UIImage * _Nullable image, NSError * _Nullable error);

typedef void (^avframeWithContextBlock)(struct AVFrame * _Nonnull frame, uint8_t * _Nonnull buffer);

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

NS_ASSUME_NONNULL_END
