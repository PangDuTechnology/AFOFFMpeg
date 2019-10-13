//
//  AFOSchedulerBaseClass+AFORouter.h
//  AFORouter
//
//  Created by piccolo on 2019/10/13.
//  Copyright © 2019 AFO. All rights reserved.
//

#import <AFOSchedulerCore/AFOSchedulerBaseClass.h>
NS_ASSUME_NONNULL_BEGIN

@interface AFOSchedulerBaseClass (AFORouter)
+ (void)jumpPassingParameters:(NSDictionary *)parameters;
@end

NS_ASSUME_NONNULL_END
