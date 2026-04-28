//
//  AFOAudioDecoder.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/3.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^audioTimeStampBlock)(float timeStamp);

struct AVFormatContext;
struct AVCodecContext;

NS_ASSUME_NONNULL_BEGIN
@interface AFOAudioDecoder : NSObject
- (void)audioDecoder:(nonnull struct AVFormatContext *)avFormatContext
        codecContext:(nonnull struct AVCodecContext *)avCodecContext
               index:(NSInteger)index
          packetSize:(int)packetSize;
- (int)readAudioSamples:(short *)samples
                   size:(int)size
                  block:(audioTimeStampBlock)block;
@end
NS_ASSUME_NONNULL_END
