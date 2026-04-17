//
//  AFOAudioOutPut.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/6.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AFOAudioFillDataDelegate <NSObject>
@optional
- (NSInteger)fillAudioData:(SInt16 *_Nullable)sampleBuffer
                 frames:(NSInteger)frame
               channels:(NSInteger)channel;
@end
NS_ASSUME_NONNULL_BEGIN

@interface AFOAudioOutPut : NSObject <AFOAudioFillDataDelegate>

/**
 <#Description#>

 @param channel <#chanel description#>
 @param sampleRate <#sampleRate description#>
 @param bytesPerSample <#bytesPerSample description#>
 @param delegate <#delegate description#>
 @return <#return value description#>
 */
- (instancetype)initWithChannel:(NSInteger)channel
                     sampleRate:(NSInteger)sampleRate
                 bytesPerSample:(NSInteger)bytesPerSample
                       delegate:(id<AFOAudioFillDataDelegate>)delegate;
- (BOOL)audioPlay;
/// 暂停播放（仅停止 graph，不释放资源，支持后续继续播放）
- (void)audioPause;
/// 停止播放并释放底层 AudioUnit/AUGraph（不可继续播放）
- (void)audioStop;
@end

NS_ASSUME_NONNULL_END
