//
//  AFOPlayMediaViewModel.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2017/12/28.
//  Copyright © 2017年 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#import <libavformat/avformat.h>
@protocol AFOPlayMediaManager <NSObject>
@optional
- (void)videoTimeStamp:(float)videoTime
              position:(float)position
             frameRate:(float)frameRate;
- (void)videoNowPlayingDelegate;
- (void)videoFinishPlayingDelegate;
@end
/**
 <#Description#>

 @param error <#error description#>
 @param pixelBuffer <#image description#>
 @param totalTime <#totalTime description#>
 @param currentTime <#currentTime description#>
 @param totalSeconds <#totalSeconds description#>
 @param cuttentSeconds <#cuttentSeconds description#>
 */
typedef void(^displayVedioFrameBlock)(NSError * _Nullable error,
                                      CVPixelBufferRef _Nullable pixelBuffer,
                                      NSString * _Nullable totalTime,
                                      NSString * _Nonnull currentTime,
                                      NSInteger totalSeconds,
                                      NSUInteger cuttentSeconds);

@interface AFOMediaManager : NSObject
- (instancetype _Nullable )initWithDelegate:(id<AFOPlayMediaManager>_Nullable)delegate;
/**
 <#Description#>
 @param formatContext <#avFormatContext description#>
 @param codecContext <#CodecContext description#>
 @param index <#index description#>
 @param block <#block description#>
 */
- (void)displayVedioFormatContext:(AVFormatContext *_Nullable)formatContext
                     codecContext:(AVCodecContext *_Nullable)codecContext
                            index:(NSInteger)index
                            block:(displayVedioFrameBlock _Nullable )block;

@end
