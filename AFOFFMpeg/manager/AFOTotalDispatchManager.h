//
//  AFOTotalDispatchManager.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/3.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
/**
 <#Description#>
 
 @param error <#error description#>
 @param image <#image description#>
 @param totalTime <#totalTime description#>
 @param currentTime <#currentTime description#>
 @param totalSeconds <#totalSeconds description#>
 @param cuttentSeconds <#cuttentSeconds description#>
 */
typedef void(^displayVedioBlock)(NSError *_Nullable error,
                                CVPixelBufferRef  _Nullable pixelBuffer,
                                NSString *_Nullable totalTime,
                                NSString *_Nullable currentTime,
                                NSInteger totalSeconds,
                                NSUInteger cuttentSeconds,
                                BOOL isVideoEnd);
NS_ASSUME_NONNULL_BEGIN

@interface AFOTotalDispatchManager : NSObject
/**
 <#Description#>
 
 @param strPath <#strPath description#>
 @param block <#block description#>
 */
- (void)displayVedioForPath:(NSString *)strPath
                           block:(displayVedioBlock)block;
- (void)stopAudio;
/// 暂停/恢复音视频（视频帧泵 + 音频）。
- (void)setSuspended:(BOOL)suspended;
/// 停止播放并释放帧泵
- (void)stop;
@end

NS_ASSUME_NONNULL_END
