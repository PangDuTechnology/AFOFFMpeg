//
//  AFOMediaErrorCodeManage.m
//  AFOPlayer
//
//  Created by xueguang xian on 2017/12/30.
//  Copyright © 2017年 AFO. All rights reserved.
//

#import "AFOMediaErrorCodeManager.h"


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
#pragma mark ------------ property
@end
