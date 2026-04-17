//
//  AFOMediaYUV.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/10.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <libswresample/swresample.h>
NS_ASSUME_NONNULL_BEGIN

@interface AFOMediaYUV : NSObject
+ (void)makeYUVToRGB:(AVFrame *)avFrame
                    width:(int)inWidth
                   height:(int)inHeight
                    scale:(int)scale
                    block:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))block;
- (void)dispatchAVFrame:(AVFrame*) frame
                  block:(void (^)(UIImage *image))block;
@end

NS_ASSUME_NONNULL_END
