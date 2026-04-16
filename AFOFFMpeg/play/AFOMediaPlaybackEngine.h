//
//  AFOMediaPlaybackEngine.h
//  AFOFFMpeg
//
//  Created by Cursor.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^AFOMediaPlaybackFrameCallback)(NSError * _Nullable error,
                                            CVPixelBufferRef _Nullable pixelBuffer,
                                            NSString * _Nullable totalTime,
                                            NSString * _Nullable currentTime,
                                            NSInteger totalSeconds,
                                            NSUInteger currentSeconds,
                                            BOOL isVideoEnd);

/// 播放引擎：封装解码调度与通知副作用，给上层 ViewModel 一个“纯方法”接口。
@interface AFOMediaPlaybackEngine : NSObject

- (void)playPath:(NSString *)path callback:(AFOMediaPlaybackFrameCallback)callback;
- (void)stop;
- (void)setSuspended:(BOOL)suspended;

@end

NS_ASSUME_NONNULL_END

