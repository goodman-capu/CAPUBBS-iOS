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

@interface AppDelegate : UIResponder <UIApplicationDelegate, MFMailComposeViewControllerDelegate, QLPreviewControllerDelegate, QLPreviewControllerDataSource> {
    NSString *previewFilePath;
    NSString *previewFileTitle;
    UIView *previewFrame;
    UIImage *previewTransitionImage;
}

@property (strong, nonatomic) UIWindow *window;

- (void)openLink:(NSDictionary *)linkInfo postTitle:(NSString *)title;

+ (UIViewController *)getTopViewController;

@end
