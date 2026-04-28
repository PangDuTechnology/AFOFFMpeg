//
//  AFOTotalDispatchManager.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/3.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
// 视频解码展示回调类型；参数与下行 block 形参序一致。
typedef void(^displayVedioBlock)(NSError *_Nullable error,
                                CVPixelBufferRef  _Nullable pixelBuffer,
                                NSString *_Nullable totalTime,
                                NSString *_Nullable currentTime,
                                NSInteger totalSeconds,
                                NSUInteger cuttentSeconds,
                                BOOL isVideoEnd);
NS_ASSUME_NONNULL_BEGIN

@interface AFOTotalDispatchManager : NSObject
/// 解码并播放指定路径视频。
- (void)displayVedioForPath:(NSString *)strPath
                           block:(displayVedioBlock)block;
- (void)stopAudio;
/// 暂停/恢复音视频（视频帧泵 + 音频）。
- (void)setSuspended:(BOOL)suspended;
/// 停止播放并释放帧泵
- (void)stop;
@end

NS_ASSUME_NONNULL_END
