//
//  AFOMediaErrorCodeManage.m
//  AFOPlayer
//
//  Created by xueguang xian on 2017/12/30.
//  Copyright © 2017年 AFO. All rights reserved.
//

#import "AFOMediaErrorCodeManager.h"
#import <libavutil/error.h>


static NSDictionary *codeDictionary;
@interface AFOMediaErrorCodeManager ()
@end
@implementation AFOMediaErrorCodeManager
#pragma mark ------ initialize
+ (void)initialize{
    if (self == [AFOMediaErrorCodeManager class]) {
        codeDictionary = @{@(AFOPlayMediaErrorNone): AFOMeidaFaileNone,
                           
                           @(AFOPlayMediaErrorCodeReadFailure) : AFOMeidaFailedReadFile,
                           @(AFOPlayMediaErrorCodeVideoStreamFailure) :
                               AFOMeidaVideoStreamFailure,
                           @(AFOPlayMediaErrorCodeNoneDecoderFailure) :
                               AFOMeidaNoneDecoderFailure,
                           @(AFOPlayMediaErrorCodeOpenDecoderFailure) :
                               AFOPlayMediaOpenDecoderFailure,
                           @(AFOPlayMediaErrorCodeDecoderImageFailure):
                               AFOPlayMediaDecoderImageFailure,
                           @(AFOPlayMediaErrorCodeDecoderPacketFailure):
                               AFOPlayMediaDecoderPacketFailure,
                           @(AFOPlayMediaErrorCodeDecoderFrameFailure):
                               AFOPlayMediaDecoderFrameFailure,
                           @(AFOPlayMediaErrorCodeAllocateCodecContextFailure) :
                               AFOPlayMediaAllocateCodecContextFailure,
                           @(AFOPlayMediaErrorCodeMemoryAllocationFailure):
                               AFOPlayMediaMemoryAllocationFailure,
                           @(AFOPlayMediaErrorCodeImageorFormatConversionFailure) : AFOPlayMediaImageorFormatConversionFailure,
                           @(AFOPlayMediaErrorCodeRetrieveStreamInformationFailure):
                               AFOPlayMediaRetrieveStreamInformationFailure
                           };
    }
}
#pragma mark ------ 根据errorCode返回Error
+ (NSError *)errorCode:(AFOPlayMediaErrorCode)errorCode{
    NSString *message = codeDictionary[@(errorCode)];
    if (message.length == 0) {
        message = [NSString stringWithFormat:@"未注册的错误码: %ld", (long)errorCode];
    }
    // 历史实现把中文说明放在 domain 字段；userInfo 沿用原字典（勿传 nil，否则 NSInvalidArgumentException）。
    return [NSError errorWithDomain:message code:errorCode userInfo:codeDictionary];
}

+ (NSError *)errorCode:(AFOPlayMediaErrorCode)errorCode libavformatOpenReturn:(int)fferr path:(NSString *)path {
    NSString *message = codeDictionary[@(errorCode)];
    if (message.length == 0) {
        message = [NSString stringWithFormat:@"未注册的错误码: %ld", (long)errorCode];
    }
    NSMutableDictionary *ui = [NSMutableDictionary dictionaryWithDictionary:codeDictionary];
    NSMutableString *desc = [NSMutableString stringWithString:message];
    if (errorCode == AFOPlayMediaErrorCodeReadFailure && fferr != 0) {
        char ebuf[256];
        av_strerror(fferr, ebuf, sizeof(ebuf));
        [desc appendFormat:@"（FFmpeg %d：%s）", fferr, ebuf];
    }
    if (path.length > 0) {
        [desc appendFormat:@" — %@", path];
    }
    ui[NSLocalizedDescriptionKey] = desc;
    // domain 勿再用中文：否则部分系统上 -localizedDescription 只有简短 domain，弹窗看不到 FFmpeg 详情。
    return [NSError errorWithDomain:@"com.afo.playback" code:errorCode userInfo:ui];
}
#pragma mark ------------ property
@end
