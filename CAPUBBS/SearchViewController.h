//
//  SearchViewController.h
//  CAPUBBS
//
//  Created by 范志康 on 15/3/6.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AnimatedImageView.h"

@interface SearchViewController : CustomViewController<UITableViewDelegate> {
    MBProgressHUD *hud;
    AnimatedImageView *backgroundView;
    NSString *text;
    NSString *type;
    NSString *author;
    UIRefreshControl *control;
    UIDatePicker *startDatePicker;
    UIDatePicker *endDatePicker;
    NSDateFormatter *formatter;
    CustomNavigationController *navi;
    NSArray *data;
    NSArray *searchResult;
}

@property NSString *bid;
@property (weak, nonatomic) IBOutlet UITextField *inputText;
@property (weak, nonatomic) IBOutlet UITextField *inputAuthor;
@property (weak, nonatomic) IBOutlet UISegmentedControl *inputType;
@property (weak, nonatomic) IBOutlet UITextField *inputStart;
@property (weak, nonatomic) IBOutlet UITextField *inputEnd;
@property (weak, nonatomic) IBOutlet UITableView *tableview;
@property (weak, nonatomic) IBOutlet UILabel *labelB;

@end
