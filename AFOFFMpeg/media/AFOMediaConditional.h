//
//  AFOMediaConditional.h
//  AFOMediaPlay
//
//  Created by xueguang xian on 2018/1/5.
//  Copyright © 2018年 AFO Science Technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// FFmpeg `AVFormatContext`：勿在公开头中包含 libavformat（静态 framework 会因非模块化 include 导致 lint/trunk 失败）。
struct AVFormatContext;

typedef void (^MediaConditionalBlock)(NSError * _Nonnull error,
                                      NSInteger videoIndex,
                                      NSInteger audioIndex);

@interface AFOMediaConditional : NSObject

/// 打开本地媒体：先 POSIX 路径，再 file:// URL；勿复用失败后的 out 指针。
+ (int)openLocalPathToFormatContext:(NSString *)path outContext:(struct AVFormatContext * _Nullable * _Nonnull)outCtx;

+ (void)mediaSesourcesConditionalPath:(NSString *)path
                                block:(MediaConditionalBlock _Nonnull)block;
@end

NS_ASSUME_NONNULL_END
