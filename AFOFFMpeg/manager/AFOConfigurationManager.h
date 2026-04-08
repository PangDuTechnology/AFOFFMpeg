//
//  AFOConfigurationManager.h
//  AFOFFMpeg
//
//  Created by xianxueguang on 2019/10/4.
//  Copyright © 2019年 AFO Science and technology Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libavformat/avformat.h>
NS_ASSUME_NONNULL_BEGIN
enum AVPixelFormat AFOHWVideoToolboxGetFormat(AVCodecContext *s, const enum AVPixelFormat *fmt);


@interface AFOConfigurationManager : NSObject
+ (void)configurationForPath:(NSString *)strPath
                      stream:(NSInteger)stream
                       block:(void(^)(
                                      AVCodec * _Nullable codec,
                                      AVFormatContext * _Nullable format, AVCodecContext * _Nullable context,
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
