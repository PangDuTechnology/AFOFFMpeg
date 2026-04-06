#import "AFOMediaPlayController+HideTabBar.h"
#import <objc/runtime.h>

// 将AFOMediaPlayController声明为外部可见，以避免编译警告
@interface AFOMediaPlayController : UIViewController
@end

@implementation AFOMediaPlayController (HideTabBar)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = NSClassFromString(@"AFOMediaPlayController");
        if (class) {
            // Swizzle viewDidLoad
            Method originalViewDidLoad = class_getInstanceMethod(class, @selector(viewDidLoad));
            Method swizzledViewDidLoad = class_getInstanceMethod(class, @selector(afo_viewDidLoad));
            method_exchangeImplementations(originalViewDidLoad, swizzledViewDidLoad);

            // Swizzle viewWillAppear:
            Method originalViewWillAppear = class_getInstanceMethod(class, @selector(viewWillAppear:));
            Method swizzledViewWillAppear = class_getInstanceMethod(class, @selector(afo_viewWillAppear:));
            method_exchangeImplementations(originalViewWillAppear, swizzledViewWillAppear);

            // Swizzle viewWillDisappear:
            Method originalViewWillDisappear = class_getInstanceMethod(class, @selector(viewWillDisappear:));
            Method swizzledViewWillDisappear = class_getInstanceMethod(class, @selector(afo_viewWillDisappear:));
            method_exchangeImplementations(originalViewWillDisappear, swizzledViewWillDisappear);
        }
    });
}

- (void)afo_viewDidLoad {
    [self afo_viewDidLoad]; // 调用原始的 viewDidLoad
    self.hidesBottomBarWhenPushed = YES; // 在viewDidLoad中设置，确保在push时生效
}

- (void)afo_viewWillAppear:(BOOL)animated {
    [self afo_viewWillAppear:animated]; // 调用原始的 viewWillAppear:
    self.tabBarController.tabBar.hidden = YES; // 手动隐藏 TabBar
}

- (void)afo_viewWillDisappear:(BOOL)animated {
    [self afo_viewWillDisappear:animated]; // 调用原始的 viewWillDisappear:
    self.tabBarController.tabBar.hidden = NO; // 手动显示 TabBar
}

@end