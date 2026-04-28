//
//  AFOMediaYUV.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/10.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

struct AVFrame;

@interface AFOMediaYUV : NSObject
+ (void)makeYUVToRGB:(struct AVFrame *)avFrame
                    width:(int)inWidth
                   height:(int)inHeight
                    scale:(int)scale
                    block:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))block;
- (void)dispatchAVFrame:(struct AVFrame*) frame
                  block:(void (^)(UIImage *image))block;
@end

NS_ASSUME_NONNULL_END
