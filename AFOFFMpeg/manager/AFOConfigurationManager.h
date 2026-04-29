//
//  AFOConfigurationManager.h
//  AFOFFMpeg
//
//  Created by xianxueguang on 2019/10/4.
//  Copyright © 2019年 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

struct AVCodec;
struct AVFormatContext;
struct AVCodecContext;

/// 供嵌套调用处书写，避免出现 `nested block ^(struct ... *)` 在部分 Clang 下的解析歧义。
typedef void (^AFOCodecConfiguredBlock)(
    struct AVCodec * _Nullable codec,
    struct AVFormatContext * _Nullable formatCtx,
    struct AVCodecContext * _Nullable codecCtx,
    NSInteger resolvedVideoStream,
    NSInteger resolvedAudioStream,
    NSData * _Nullable sps,
    NSData * _Nullable pps);

@interface AFOConfigurationManager : NSObject
+ (void)configurationForPath:(NSString *)strPath
                      stream:(NSInteger)stream
                       block:(AFOCodecConfiguredBlock)configured;
+ (void)configurationStreamPath:(NSString *)strPath
                          block:(void (^)(NSError * _Nonnull error,
                                          NSInteger videoIndex,
                                          NSInteger audioIndex))block;
@end

NS_ASSUME_NONNULL_END
