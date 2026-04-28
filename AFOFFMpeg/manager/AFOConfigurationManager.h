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

@interface AFOConfigurationManager : NSObject
+ (void)configurationForPath:(NSString *)strPath
                      stream:(NSInteger)stream
                       block:(void(^)(
                                      struct AVCodec * _Nullable codec,
                                      struct AVFormatContext * _Nullable format,
                                      struct AVCodecContext * _Nullable context,
                                      NSInteger videoStream,
                                      NSInteger audioStream,
                                      NSData * _Nullable sps,
                                      NSData * _Nullable pps))block;
+ (void)configurationStreamPath:(NSString *)strPath
                          block:(void(^)(NSError *error,
                                         NSInteger videoIndex,
                                         NSInteger audioIndex))block;
@end

NS_ASSUME_NONNULL_END
