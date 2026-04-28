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
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>

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
 视频解码回调。

 @param error 解码或读帧出错时非 nil；成功时通常为 nil。
 @param pixelBuffer 解码后的视频帧（CVPixelBuffer）。
 @param totalTime UI 展示的时长文案。
 @param currentTime UI 展示的当前进度文案。
 @param totalSeconds 总时长（秒）。
 @param cuttentSeconds 当前已过秒（与声明中命名一致）。
 @param isVideoEnd 是否为最后一帧/流结束标志。
 */
typedef void(^displayVedioFrameBlock)(NSError * _Nullable error,
                                      CVPixelBufferRef _Nullable pixelBuffer,
                                      NSString * _Nullable totalTime,
                                      NSString * _Nullable currentTime,
                                      NSInteger totalSeconds,
                                      NSUInteger cuttentSeconds,
                                      BOOL isVideoEnd);

NS_ASSUME_NONNULL_BEGIN

@interface AFOMediaManager : NSObject
- (instancetype)initWithDelegate:(nullable id<AFOPlayMediaManager>)delegate;
/**
 <#Description#>
 @param formatContext <#avFormatContext description#>
 @param codecContext <#CodecContext description#>
 @param index <#index description#>
 @param block <#block description#>
 */
- (void)displayVedioFormatContext:(struct AVFormatContext * _Nullable)formatContext
                     codecContext:(struct AVCodecContext * _Nullable)codecContext
                            index:(NSInteger)index
                            block:(displayVedioFrameBlock _Nonnull)block;

/// 暂停/恢复解码帧泵（仅影响视频帧读取节奏）。
- (void)setSuspended:(BOOL)suspended;
/// 取消帧泵并释放相关 timer（视频停止时调用）。
- (void)cancelFramePump;

@end

NS_ASSUME_NONNULL_END
