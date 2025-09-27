//
//  MessageViewController.h
//  CAPUBBS
//
//  Created by 范志康 on 15/4/17.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MessageViewController : CustomViewController<UITableViewDelegate> {
    MBProgressHUD *hud;
    UIRefreshControl *control;
    UISegmentedControl *activeSegment;
    NSArray *data;
    NSInteger page;
    NSInteger maxPage;
    NSString *chatID;
    BOOL isBackground;
    BOOL isVisible;
    BOOL messageRefreshing;
    long originalSegment;
}

@property (weak, nonatomic) IBOutlet UIView *segmentBackgroundView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentTypeInView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentTypeInTitle;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *flexSpace;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonPrevious;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonAdd;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *buttonNext;


@end
