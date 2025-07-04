//
//  WebViewController.h
//  CAPUBBS
//
//  Created by 范志康 on 15/5/12.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "CustomWebViewContainer.h"

@interface WebViewController : CustomViewController<WKNavigationDelegate, UIScrollViewDelegate> {
    MBProgressHUD *hud;
    CGFloat contentOffsetY;
    BOOL isAtEnd;
    NSUserActivity *activity;
    NSTimer *titleCheckTimer;
}

@property NSString *URL;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonStop;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonRefresh;
@property (weak, nonatomic) IBOutlet CustomWebViewContainer *webViewContainer;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonBack;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonForward;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonShare;

@end
