//
//  AFOMediaView.h
//  AFOPlayer
//
//  Created by xueguang xian on 2017/12/28.
//  Copyright © 2017年 AFO. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AFOMediaViewDelegate
@optional
- (void)buttonTouchActionDelegate:(BOOL)isSuspended;
@end

@interface AFOMediaView : UIView
- (instancetype)initWithFrame:(CGRect)frame delegate:(id)delegate;
- (void)settingMovieImage:(UIImage * _Nullable)image
                totalTime:(NSString *)totalTime
              currentTime:(NSString *)currentTime
                    total:(NSInteger)total
                  current:(NSInteger)current;
- (void)settingPlayButtonPause;
- (void)settingBottomViewShowOrHidden:(void (^)(UIView *view))block;
@end

NS_ASSUME_NONNULL_END
