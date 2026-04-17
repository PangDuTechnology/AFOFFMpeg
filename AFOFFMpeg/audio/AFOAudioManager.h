//
//  AFOAudioManager.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/3/20.
//  Copyright © 2018年 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libavformat/avformat.h>
@protocol AFOAudioManagerDelegate <NSObject>
@optional
- (void)audioTimeStamp:(float)audioTime;
@end
@interface AFOAudioManager : NSObject
- (instancetype)initWithDelegate:(id<AFOAudioManagerDelegate>)delegate;
- (void)audioFormatContext:(AVFormatContext *)formatContext
              codecContext:(AVCodecContext *)codecContext
                     index:(NSInteger)index;
- (void)playAudio;
/// 暂停音频（可恢复）
- (void)pauseAudio;
/// 停止并释放音频资源（不可直接恢复，需重新配置）
- (void)stopAudio;
@end
