//
//  AFOPlayMediaViewModel.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2017/12/28.
//  Copyright © 2017年 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#ifdef DEBUG
#define AFOMediaLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define AFOMediaLog(fmt, ...) 
#endif
#include <UIKit/UIKit.h>

struct AVFormatContext;
struct AVCodecContext;

@protocol AFOPlayMediaManager <NSObject>
@optional
- (void)videoTimeStamp:(float)videoTime
              position:(float)position
             frameRate:(float)frameRate;
- (void)videoNowPlayingDelegate;
- (void)videoFinishPlayingDelegate;
- (void)videoDidPauseDelegate:(BOOL)isPaused;
@end
/**
 <#Description#>

 @param error <#error description#>
 @param image <#image description#>
 @param totalTime <#totalTime description#>
 @param currentTime <#currentTime description#>
 @param totalSeconds <#totalSeconds description#>
 @param cuttentSeconds <#cuttentSeconds description#>
 */
typedef void(^displayVedioFrameBlock)(NSError *error,
                                      CVPixelBufferRef _Nullable pixelBuffer,
                                      NSString *totalTime,
                                      NSString *currentTime,
                                      NSInteger totalSeconds,
                                      NSUInteger cuttentSeconds,
                                      BOOL isVideoEnd);

@interface AFOMediaManager : NSObject
- (instancetype)initWithDelegate:(id<AFOPlayMediaManager>)delegate;
/**
 <#Description#>
 @param formatContext <#avFormatContext description#>
 @param codecContext <#CodecContext description#>
 @param index <#index description#>
 @param block <#block description#>
 */
- (void)displayVedioFormatContext:(struct AVFormatContext *)formatContext
                     codecContext:(struct AVCodecContext *)codecContext
                            index:(NSInteger)index
                            block:(displayVedioFrameBlock)block;

/// 暂停/恢复解码帧泵（仅影响视频帧读取节奏）。
- (void)setSuspended:(BOOL)suspended;
/// 取消帧泵并释放相关 timer（视频停止时调用）。
- (void)cancelFramePump;

@end
