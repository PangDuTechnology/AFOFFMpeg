//
//  AFOAudioThreadDecoder.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/7.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

struct AVFormatContext;
struct AVCodecContext;

@interface AFOAudioThreadDecoder : NSObject
- (void)audioDecoder:(nonnull struct AVFormatContext *)avFormatContext
        codecContext:(nonnull struct AVCodecContext *)avCodecContext
               index:(NSInteger)index;
- (void)packetBufferTimePercent:(float)timePercent;
- (void)readAudioPacket:(short *)samples
                   size:(int)size
                  block:(void (^)(float timeStamp))block;
@end

NS_ASSUME_NONNULL_END
