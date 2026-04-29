//
//  AFOMediaErrorCodeManage.h
//  AFOPlayer
//
//  Created by xueguang xian on 2017/12/30.
//  Copyright © 2017年 AFO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFOMediaErrorString.h"

NS_ASSUME_NONNULL_BEGIN

@interface AFOMediaErrorCodeManager : NSObject

/**
 <#Description#>

 @param errorCode <#errorCode description#>
 @return <#return value description#>
 */
+ (NSError *)errorCode:(AFOPlayMediaErrorCode)errorCode;

/// 读取失败时可传入 `avformat_open_input` 的返回值（负数），便于界面与日志显示 FFmpeg 原因。
+ (NSError *)errorCode:(AFOPlayMediaErrorCode)errorCode libavformatOpenReturn:(int)fferr path:(nullable NSString *)path;
@end

NS_ASSUME_NONNULL_END
