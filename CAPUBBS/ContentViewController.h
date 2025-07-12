//
//  ContentViewController.h
//  CAPUBBS
//
//  Created by 熊典 on 14-2-17.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface ContentViewController : CustomTableViewController<WKNavigationDelegate, WKScriptMessageHandler> {
    MBProgressHUD *hud;
    NSUserActivity *activity;
    NSArray *data;
    int page;
    int textSize;
    BOOL isEdit;
    NSString *defaultTitle;
    NSString *defaultContent;
    NSInteger selectedIndex;
    NSMutableArray *heights;
    NSMutableArray *tempHeights; // 储存之前计算的高度结果，防止reload时高度突变
    NSMutableArray *HTMLStrings;
    NSString *tempPath;
    CGFloat contentOffsetY;
    BOOL isAtEnd;
    NSInteger scrollTargetRow;
    UITableViewScrollPosition scrollTargetPosition;
    NSIndexPath *longPressIndexPath;
}

@property NSString *bid;
@property NSString *tid;
@property NSString *destinationPage;
/// If set, will try to scroll to the desired flor
@property NSString *destinationFloor;
/// If set, will popup lzl for the desired floor
@property BOOL openDestinationLzl;
/// If set, will try to scroll to the last flor
@property BOOL willScrollToBottom;
@property BOOL isCollection;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonLatest;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonBackOrCollect;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonForward;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonJump;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAction;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonCompose;

@end
