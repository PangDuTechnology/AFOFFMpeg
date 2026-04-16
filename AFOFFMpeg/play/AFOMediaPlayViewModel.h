//
//  AFOMediaPlayViewModel.h
//  AFOFFMpeg
//
//  Created by Cursor.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class AFOTotalDispatchManager;

@interface AFOMediaPlayViewModel : NSObject

/// --- Outputs (由 Controller 绑定)
@property (nonatomic, copy, nullable) void (^onTitleChanged)(NSString *title);
@property (nonatomic, copy, nullable) void (^onFrame)(CVPixelBufferRef _Nullable pixelBuffer);
@property (nonatomic, copy, nullable) void (^onTime)(NSString * _Nullable totalTime,
                                                    NSString * _Nullable currentTime,
                                                    NSInteger totalSeconds,
                                                    NSUInteger currentSeconds,
                                                    BOOL isVideoEnd);
@property (nonatomic, copy, nullable) void (^onError)(NSString *message);

/// --- Readonly state (给系统回调用)
@property (nonatomic, assign, readonly) UIInterfaceOrientationMask orientationMask;
@property (nonatomic, copy, readonly, nullable) NSString *path;
@property (nonatomic, copy, readonly, nullable) NSString *title;

/// --- Inputs
- (void)configureWithPath:(NSString *)path
                    title:(nullable NSString *)title
           orientationMask:(UIInterfaceOrientationMask)mask;

- (void)onViewDidLoad;
- (void)onViewWillAppear;
- (void)onViewDidDisappear;

- (void)play;
- (void)restart;
- (void)stop;

/// YES: 暂停帧泵/播放；NO: 恢复
- (void)setSuspended:(BOOL)suspended;

@end

NS_ASSUME_NONNULL_END

