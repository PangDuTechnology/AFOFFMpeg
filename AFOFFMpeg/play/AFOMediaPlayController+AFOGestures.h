//
//  AFOMediaPlayController+AFOGestures.h
//  AFOFFMpeg
//
//  Created by xueguang xian on 2018/1/26.
//  Copyright © 2018年 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOMediaPlayController.h"
@class AFOMetalVideoView;
@interface AFOMediaPlayController (AFOGestures)
@property (nonatomic, strong) AFOMetalVideoView           *mediaView;
- (void)addMeidaView;
@end
