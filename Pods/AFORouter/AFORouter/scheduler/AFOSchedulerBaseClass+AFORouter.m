//
//  AFOSchedulerBaseClass+AFORouter.m
//  AFORouter
//
//  Created by piccolo on 2019/10/13.
//  Copyright © 2019 AFO. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "AFOSchedulerBaseClass+AFORouter.h"
#import <AFOSchedulerCore/NSObject+AFOScheduler.h>
@implementation AFOSchedulerBaseClass (AFORouter)
+ (void)jumpPassingParameters:(NSDictionary *)parameters{
    SEL current = NSSelectorFromString(@"currentViewController");
    if ([UIViewController respondsToSelector:current]) {
        id controller = [UIViewController performSelector:current];
        NSArray *paraArray = @[controller,[self nextController:parameters],parameters];
        Class class = NSClassFromString(@"AFORouterActionContext");
        id instance = [[class alloc] init];
        SEL sel = NSSelectorFromString(@"passingCurrentController:nextController:parameters:");
        if ([instance respondsToSelector:sel]) {
            [instance schedulerPerformSelector:sel params:paraArray];
        }
    }
}
+ (UIViewController *)nextController:(NSDictionary *)parameters{
    Class class = NSClassFromString(parameters[@"next"]);
    UIViewController *controller = [[class alloc] init];
    controller.hidesBottomBarWhenPushed = YES;
    return controller;
}
@end
