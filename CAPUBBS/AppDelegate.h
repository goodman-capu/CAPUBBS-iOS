//
//  AppDelegate.h
//  CAPUBBS
//
//  Created by 熊典 on 14-2-16.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <QuickLook/QuickLook.h>

@interface PreviewItem : NSObject <QLPreviewItem>

@property (nonatomic, strong) NSURL *previewItemURL;
@property (nonatomic, strong) NSString *previewItemTitle;
@property (nonatomic, strong) UIView *previewFrame;
@property (nonatomic, strong) UIImage *previewTransitionImage;

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate, MFMailComposeViewControllerDelegate, QLPreviewControllerDelegate, QLPreviewControllerDataSource> {
    NSArray<PreviewItem *> *previewItems;
    BOOL wakeLogin;
}

@property (strong, nonatomic) UIWindow *window;

- (void)openLink:(NSDictionary *)linkInfo postTitle:(NSString *)title;

+ (UIViewController *)getTopViewController;

+ (UIView *)keyboardToolViewWithLeftButtons:(NSArray<UIButton *> *)leftButtons rightButtons:(NSArray<UIButton *> *)rightButtons;

+ (UIButton *)keyboardToolButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action;

@end
