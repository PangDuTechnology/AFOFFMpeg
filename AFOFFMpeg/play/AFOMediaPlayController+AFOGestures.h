//
//  AFOMediaPlayController+AFOGestures.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/1/26.
//  Copyright © 2018年 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOMediaPlayController.h"
@class AFOMetalVideoView;
@class AFOMediaView;
@interface AFOMediaPlayController (AFOGestures)
@property (nonatomic, strong) AFOMetalVideoView           *mediaView;
/// 覆盖在视频上的控制层（播放/暂停/进度条）
@property (nonatomic, strong) AFOMediaView *mediaOverlayView;
- (void)addMeidaView;
@end
