//
//  CustomViewControllers.m
//  CAPUBBS
//
//  Created by Zhikang Fan on 6/4/25.
//  Copyright © 2025 熊典. All rights reserved.
//

#import "CustomViewControllers.h"
#import <objc/runtime.h>

@implementation CustomNavigationController

- (UIViewController *)childViewControllerForStatusBarStyle {
    // 让状态栏样式跟随当前 topViewController
    return self.topViewController;
}

@end

@implementation CustomViewController

#ifdef DEBUG
- (void)dealloc {
    NSLog(@"✅ dealloc VC: %@", self);
}
#endif

@end

@implementation CustomTableViewController

#ifdef DEBUG
- (void)dealloc {
    NSLog(@"✅ dealloc VC: %@", self);
}
#endif

@end

@implementation CustomCollectionViewController

#ifdef DEBUG
- (void)dealloc {
    NSLog(@"✅ dealloc VC: %@", self);
}
#endif

@end

@implementation CustomMailComposeViewController

@end

@implementation CustomSearchController

@end

@implementation UIViewController (Extension)

static char kViewControllerQueueKey;
static char kPresentTimerKey;
static char kIsAttemptingToPresentKey;

- (NSMutableArray<UIViewController *> *)_getVcQueue {
    NSMutableArray *queue = objc_getAssociatedObject(self, &kViewControllerQueueKey);
    if (!queue) {
        queue = [NSMutableArray array];
        objc_setAssociatedObject(self, &kViewControllerQueueKey, queue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return queue;
}

- (NSTimer *)_getPresentTimer {
    return objc_getAssociatedObject(self, &kPresentTimerKey);
}

- (void)_setPresentTimer:(NSTimer *)timer {
    objc_setAssociatedObject(self, &kPresentTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)_isAttemptingToPresent {
    return [objc_getAssociatedObject(self, &kIsAttemptingToPresentKey) boolValue];
}

- (void)_setAttemptingToPresent:(BOOL)isAttempting {
    objc_setAssociatedObject(self, &kIsAttemptingToPresentKey, @(isAttempting), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)_tryPresentNextVc {
    if ([self _isAttemptingToPresent] || self.presentedViewController) {
        return NO;
    }
    
    NSMutableArray *queue = [self _getVcQueue];
    if (queue.count == 0) {
        if ([self _getPresentTimer]) {
            [[self _getPresentTimer] invalidate];
            [self _setPresentTimer:nil];
        }
        return NO;
    }
    
    [self _setAttemptingToPresent:YES];
    UIViewController *item = queue.firstObject;
    [queue removeObjectAtIndex:0];
    dispatch_main_async_safe(^{
        [self presentViewController:item animated:YES completion:^{
            [self _setAttemptingToPresent:NO];
        }];
    });
    return YES;
}

- (void)_timerCheck {
    [self _tryPresentNextVc];
}

- (void)presentViewControllerSafe:(UIViewController *)view {
    [[self _getVcQueue] addObject:view];
    if ([self _tryPresentNextVc]) {
        return;
    }
    if (![self _getPresentTimer]) {
        // 使用 weakSelf 防止循环引用导致不能 dealloc
        __weak typeof(self) weakSelf = self;
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf _timerCheck];
            } else {
                [timer invalidate];
            }
        }];
        [self _setPresentTimer:timer];
    }
}

- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
              confirmTitle:(NSString *)confirmTitle
             confirmAction:(void (^)(UIAlertAction *action))confirmAction
               cancelTitle:(NSString *)cancelTitle
              cancelAction:(void (^)(UIAlertAction *action))cancelAction {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    if (confirmTitle && confirmAction) {
        [alertController addAction:[UIAlertAction actionWithTitle:confirmTitle
                                                  style:[confirmTitle containsString:@"删除"] ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                                handler:confirmAction]];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:cancelTitle
                                              style:UIAlertActionStyleCancel
                                            handler:cancelAction]];
    [self presentViewControllerSafe:alertController];
};

- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
              confirmTitle:(NSString *)confirmTitle
             confirmAction:(void (^)(UIAlertAction *action))confirmAction
               cancelTitle:(NSString *)cancelTitle {
    [self showAlertWithTitle:title message:message confirmTitle:confirmTitle confirmAction:confirmAction cancelTitle:cancelTitle cancelAction:nil];
}

- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
              confirmTitle:(NSString *)confirmTitle
             confirmAction:(void (^)(UIAlertAction *action))confirmAction {
    [self showAlertWithTitle:title message:message confirmTitle:confirmTitle confirmAction:confirmAction cancelTitle:@"取消" cancelAction:nil];
}

- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
               cancelTitle:(NSString *)cancelTitle {
    [self showAlertWithTitle:title message:message confirmTitle:nil confirmAction:nil cancelTitle:cancelTitle cancelAction:nil];
}

- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
             cancelAction:(void (^)(UIAlertAction *action))cancelAction {
    [self showAlertWithTitle:title message:message confirmTitle:nil confirmAction:nil cancelTitle:@"好" cancelAction:cancelAction];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    [self showAlertWithTitle:title message:message confirmTitle:nil confirmAction:nil cancelTitle:@"好" cancelAction:nil];
}

@end

@implementation CustomViewController (Customize)

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end

@implementation CustomTableViewController (Customize)

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end

@implementation CustomCollectionViewController (Customize)

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end

@implementation CustomMailComposeViewController (Customize)

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end

@implementation CustomSearchController (Customize)

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
