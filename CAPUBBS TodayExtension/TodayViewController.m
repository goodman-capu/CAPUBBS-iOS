//
//  TodayViewController.m
//  CAPUBBS TodayExtension
//
//  Created by 范志康 on 2016/9/29.
//  Copyright © 2016年 熊典. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import "CommonDefinitions.h"
#import "ActionPerformer.h"
#import "AsyncImageView.h"
#import "TodayTableViewCell.h"

#define SMALL_SIZE 110
#define LARGE_SIZE 209
#define TEXT_INFO_COLOR [UIColor colorWithWhite:1.0 alpha:1.0]
#define TEXT_HINT_COLOR [UIColor colorWithWhite:0.75 alpha:1.0]

@interface TodayViewController () <NCWidgetProviding, UITableViewDelegate, UITableViewDataSource> {
    float iOS;
    float height;
    ActionPerformer *performer;
    NSDictionary *userInfo;
    NSArray *hotPosts;
}

@property (strong, nonatomic) IBOutlet AsyncImageView *imageIcon;
@property (strong, nonatomic) IBOutlet UILabel *labelName;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *indicatorLoading;
@property (strong, nonatomic) IBOutlet UIButton *buttonMessages;
@property (strong, nonatomic) IBOutlet UIButton *buttonMore;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *constraintIndicatorWidth;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *constraintMoreButtonWidth;
@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation TodayViewController

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [_imageIcon setRounded:YES];
    iOS = [[[UIDevice currentDevice] systemVersion] floatValue];
    performer = [ActionPerformer new];
    
    if (iOS < 10.0) {
        height = [[DEFAULTS objectForKey:@"size"] floatValue];
        if (height == 0) {
            height = SMALL_SIZE;
        }
        [self _refreshShowMoreButtonTitle];
        [self setPreferredContentSize:CGSizeMake(0, height)];
        [_labelName setTextColor:TEXT_INFO_COLOR];
        [_buttonMessages setTitleColor:TEXT_HINT_COLOR forState:UIControlStateNormal];
        [_buttonMore setTintColor:TEXT_HINT_COLOR];
    } else {
        _constraintMoreButtonWidth.constant = 0;
        [self.extensionContext setWidgetLargestAvailableDisplayMode:NCWidgetDisplayModeExpanded];
        self.preferredContentSize = [self.extensionContext widgetMaximumSizeForDisplayMode:NCWidgetDisplayModeCompact];
    }
    
    // Do any additional setup after loading the view from its nib.
}

- (UIEdgeInsets)widgetMarginInsetsForProposedMarginInsets:(UIEdgeInsets)defaultMarginInsets{
    return UIEdgeInsetsMake(0, 15, 0, 15);
}

- (void)widgetActiveDisplayModeDidChange:(NCWidgetDisplayMode)activeDisplayMode withMaximumSize:(CGSize)maxSize {
    if (activeDisplayMode == NCWidgetDisplayModeCompact) {
        [self setPreferredContentSize:maxSize];
    } else {
        [self setPreferredContentSize:CGSizeMake(0, LARGE_SIZE)];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    [self refreshView];
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    completionHandler(NCUpdateResultNewData);
}

- (void)refreshView {
    dispatch_global_default_async(^{
        dispatch_sync(dispatch_get_main_queue(), ^{
            _constraintIndicatorWidth.constant = 20;
            [_indicatorLoading startAnimating];
        });
        dispatch_semaphore_t signal = dispatch_semaphore_create(0);
        [self refreshUserInfoWithBlock:^{
            dispatch_semaphore_signal(signal);
        }];
        [self refreshHotPostWithBlock:^{
            dispatch_semaphore_signal(signal);
        }];
        dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
        dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
        dispatch_sync(dispatch_get_main_queue(), ^{
            _constraintIndicatorWidth.constant = 0;
            [_indicatorLoading stopAnimating];
        });
    });
}

- (void)refreshUserInfoWithBlock:(void (^)())block {
    void(^failBlock)() = ^() {
        [_imageIcon setImage:PLACEHOLDER];
        [_labelName setText:@"未登录"];
        [_buttonMessages setTitle:@"点击打开app" forState:UIControlStateNormal];
        userInfo = nil;
    };
    void(^updateInfoBlock)() = ^() {
        [_imageIcon setUrl:userInfo[@"icon"] withPlaceholder:NO];
        [_labelName setText:userInfo[@"username"]];
        int newMessageNum = [userInfo[@"newmsg"] intValue];
        if (newMessageNum > 0) {
            [_buttonMessages setTitle:[NSString stringWithFormat:@"您有 %d 条新消息", newMessageNum] forState:UIControlStateNormal];
        } else {
            [_buttonMessages setTitle:@"您暂时没有新消息" forState:UIControlStateNormal];
        }
    };
    
    if (![ActionPerformer checkLogin:NO] || (!userInfo && (!UID || !PASS))) {
        failBlock();
        block();
        return;
    }
    
    [_buttonMessages setHidden:NO];
    userInfo = USERINFO;
    if (userInfo) {
        updateInfoBlock();
    }
    [performer performActionWithDictionary:@{@"uid": UID} toURL:@"userinfo" withBlock:^(NSArray *result, NSError *err) {
        if (err || result.count == 0) {
            if (!userInfo) {
                failBlock();
            }
        } else {
            userInfo = [result firstObject];
            [GROUP_DEFAULTS setObject:userInfo forKey:@"userinfo"];
            updateInfoBlock();
        }
        block();
    }];
}

- (void)refreshHotPostWithBlock:(void (^)())block {
    hotPosts = HOTPOSTS;
    if (hotPosts.count > 0) {
        [_tableView reloadData];
    }
    [performer performActionWithDictionary:@{@"hotnum": @"5"} toURL:@"hot" withBlock:^(NSArray *result, NSError *err) {
        if (err || result.count == 0) {
            if (!hotPosts) {
                dispatch_main_async_safe(^{
                    TodayTableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathWithIndex:0]];
                    [cell.labelAuthor setText:@"网络异常"];
                });
            }
        } else {
            hotPosts = [NSMutableArray arrayWithArray:result];
            [GROUP_DEFAULTS setObject:hotPosts forKey:@"hotPosts"];
            [self.tableView reloadData];
        }
        block();
    }];
}

- (IBAction)showMessage:(id)sender {
    if (!userInfo || [userInfo[@"newmsg"] intValue] == 0) {
        [[self extensionContext] openURL:[NSURL URLWithString:@"capubbs://"] completionHandler:nil];
    } else {
        [[self extensionContext] openURL:[NSURL URLWithString:@"capubbs://open=message"] completionHandler:nil];
    }
}

- (IBAction)showMore:(id)sender {
    height = (height == SMALL_SIZE ? LARGE_SIZE : SMALL_SIZE);
    [DEFAULTS setObject:@(height) forKey:@"size"];
    [self _refreshShowMoreButtonTitle];
    [self setPreferredContentSize:CGSizeMake(0, height)];
}

- (void)_refreshShowMoreButtonTitle {
    [_buttonMore setImage:[UIImage imageNamed:(height == SMALL_SIZE ? @"down": @"up")] forState:UIControlStateNormal];
}

#pragma mark Table View delegate & Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TodayTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"hot"];
    if (iOS < 10.0) {
        [cell.labelTitle setTextColor:TEXT_INFO_COLOR];
        [cell.labelAuthor setTextColor:TEXT_HINT_COLOR];
    }
    if (!hotPosts || ! hotPosts[indexPath.row]) {
        [cell.labelTitle setText:(indexPath.row == 0 ? @"加载中..." : @"")];
        [cell.labelAuthor setText:@""];
    } else {
        NSDictionary *dict = hotPosts[indexPath.row];
        
        NSString *title = [NSString stringWithFormat:@"%ld. %@", indexPath.row + 1, [ActionPerformer removeRe:dict[@"text"]]];
        [cell.labelTitle setText:title];
        
        NSString *detailText;
        if ([dict[@"pid"] integerValue] == 0 || [dict[@"replyer"] isEqualToString:@"Array"]) {
            detailText = dict[@"author"];
        }else {
            detailText = dict[@"replyer"];
        }
        [cell.labelAuthor setText:detailText];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *dict = hotPosts[indexPath.row];
    NSString *urlString = [NSString stringWithFormat:@"capubbs://open=post&bid=%@&tid=%@&page=%d", dict[@"bid"], dict[@"tid"], [dict[@"pid"] intValue] / 12];
    [[self extensionContext] openURL:[NSURL URLWithString:urlString] completionHandler:nil];
}

@end
