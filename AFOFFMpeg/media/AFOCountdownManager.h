//
//  AFOCountdownManager.h
//  AFOPlayer
//
//  Created by xueguang xian on 2017/12/31.
//  Copyright © 2017年 AFO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFOCountDownManagerDelegate.h"
@interface AFOCountdownManager : NSObject
@property (nonatomic, weak) id<AFOCountDownManagerDelegate>delegate;
/**
 <#Description#>

 @param fps <#fps description#>
 @param time <#time description#>
 @param block <#block description#>
 */
- (void)addCountdownActionFps:(float)fps
                     duration:(int64_t)time
                     block:(void (^)(NSNumber *isEnd))block;

/// 暂停倒计时（不会销毁 timer）。
- (void)pause;
/// 恢复倒计时。
- (void)resume;
/// 取消并释放 timer。
- (void)cancel;
@end
