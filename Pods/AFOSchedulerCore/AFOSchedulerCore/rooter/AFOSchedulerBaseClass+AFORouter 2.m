//
//  AFOSchedulerBaseClass+AFORouter.m
//  AFOSchedulerCore
//
//  Created by piccolo on 2019/10/15.
//  Copyright © 2019 piccolo. All rights reserved.
//

#import "AFOSchedulerBaseClass+AFORouter.h"
#import <UIKit/UIKit.h>
@implementation AFOSchedulerBaseClass (AFORouter)
#pragma mark ------ router
+ (void)schedulerRouterJumpPassingParameters:(NSDictionary *)parameters{
    SEL current = NSSelectorFromString(@"currentViewController");
    if ([UIViewController respondsToSelector:current]) {
        id controller = [UIViewController performSelector:current];
        NSArray *paraArray = @[controller,parameters[@"next"],parameters];
        Class class = NSClassFromString(@"AFORouterActionContext");
        id instance = [[class alloc] init];
        SEL sel = NSSelectorFromString(@"passingCurrentController:nextController:parameters:");
        if ([instance respondsToSelector:sel]) {
            [instance schedulerPerformSelector:sel params:paraArray];
        }
    }
}
@end
