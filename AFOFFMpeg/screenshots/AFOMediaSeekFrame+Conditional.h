//
//  AFOMediaSeekFrame+Conditional.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/12/18.
//  Copyright © 2018 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOMediaSeekFrame.h"

NS_ASSUME_NONNULL_BEGIN

struct AVFormatContext;
struct AVCodecContext;

typedef void (^MediaSeekFrameBlock)(NSError * _Nonnull error,
                                   NSInteger videoIndex,
                                   struct AVFormatContext * _Nullable formatContext);

@interface AFOMediaSeekFrame (Conditional)
+ (void)mediaSesourcesConditionalPath:(NSString *)path
                        formatContext:(struct AVFormatContext *)avFormatContext
                         codecContext:(struct AVCodecContext *)avCodecContext
                                block:(MediaSeekFrameBlock) block;
+ (NSString *)vedioAddress:(NSString *)path
                      name:(NSString *)name;
@end

NS_ASSUME_NONNULL_END
