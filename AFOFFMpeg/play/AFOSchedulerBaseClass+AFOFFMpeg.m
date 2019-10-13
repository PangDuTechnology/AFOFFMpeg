//
//  AFOSchedulerBaseClass+AFOFFMpeg.m
//  AFOFFMpeg
//
//  Created by piccolo on 2019/10/13.
//  Copyright © 2019 AFO Science and technology Ltd. All rights reserved.
//

#import "AFOSchedulerBaseClass+AFOFFMpeg.h"
#import <AFOSchedulerCore/NSObject+AFOScheduler.h>
@implementation AFOSchedulerBaseClass (AFOFFMpeg)
#pragma mark ------ FFMpeg pass value
+ (void)ffmpegSchedulerMediaPlayReceiverParameters:(id)model
                                            target:(id)target{
    SEL sel = NSSelectorFromString(@"mediaPlayReceiverParameters:");
    if ([target respondsToSelector:sel]) {
        [self schedulerPerformSelector:target params:[NSArray arrayWithObject:model]];
    }
}
@end
