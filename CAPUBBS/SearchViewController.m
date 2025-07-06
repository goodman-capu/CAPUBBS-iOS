//
//  SearchViewController.m
//  CAPUBBS
//
//  Created by 范志康 on 15/3/6.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import "SearchViewController.h"
#import "SearchViewCell.h"
#import "ContentViewController.h"

#define MIN_DATE @"1995-10-25"

@interface SearchViewController ()

@end

@implementation SearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GREEN_BACK;
    UIView *targetView = self.navigationController ? self.navigationController.view : self.view;
    hud = [[MBProgressHUD alloc] initWithView:targetView];
    [targetView addSubview:hud];
    
    [self refreshBackgroundViewAnimated:NO];
    [self.inputText becomeFirstResponder];
    [self setDate];
    self.labelB.text = [Helper getBoardTitle:self.bid];
    control = [[UIRefreshControl alloc] init];
    [control addTarget:self action:@selector(refreshControlValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.tableview addSubview:control];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
    if (![self isValidBoard:self.bid]) {
        [self chooseBoard:nil];
    }
}

- (void)refreshBackgroundViewAnimated:(BOOL)animated {
    if (SIMPLE_VIEW) {
        return;
    }
    if (!backgroundView) {
        backgroundView = [[AnimatedImageView alloc] init];
        [backgroundView setContentMode:UIViewContentModeScaleAspectFill];
        [self.view addSubview:backgroundView];
        [self.view sendSubviewToBack:backgroundView];
        [backgroundView.layer setMasksToBounds:YES];
        [backgroundView setTranslatesAutoresizingMaskIntoConstraints:NO];
        int dir[4] = {NSLayoutAttributeTop, NSLayoutAttributeBottom, NSLayoutAttributeLeft, NSLayoutAttributeRight};
        for (int i = 0; i < 4; i++) {
            [self.view addConstraint:[NSLayoutConstraint constraintWithItem:backgroundView attribute:dir[i] relatedBy:NSLayoutRelationEqual toItem:self.view attribute:dir[i] multiplier:1.0 constant:0.0]];
        }
    }
    BOOL isAll = [self.bid isEqualToString:@"-1"];
    UIImage *image = isAll ? [UIImage imageWithColor:GREEN_BACK size:CGSizeMake(100, 100)] : [UIImage imageNamed:[@"b" stringByAppendingString:self.bid]];
    [backgroundView setImage:image blurred:!isAll animated:animated];
}

- (void)refreshControlValueChanged:(UIRefreshControl *)refreshControl {
    refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"刷新"];
    [self search:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (void)setDate { // 两个日期选择器
    NSDate *today = [NSDate date];
    NSTimeInterval secondsInOneYear = 365 * 24 * 60 * 60;
    NSDate *oneYearAgo = [today dateByAddingTimeInterval:-secondsInOneYear];
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    NSTimeZone *beijingTimeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    [formatter setTimeZone:beijingTimeZone];
    NSDate *minDate = [formatter dateFromString:MIN_DATE];
    startDatePicker = [[UIDatePicker alloc] init];
    endDatePicker = [[UIDatePicker alloc] init];
    for (UIDatePicker *picker in @[startDatePicker, endDatePicker]) {
        picker.datePickerMode = UIDatePickerModeDate;
        picker.preferredDatePickerStyle = UIDatePickerStyleInline;
        picker.minimumDate = minDate;
        picker.maximumDate = today;
        [picker addTarget:self action:@selector(ValueChanged:) forControlEvents:UIControlEventValueChanged];
    }
    [startDatePicker setDate:oneYearAgo animated:YES];
    [endDatePicker setDate:today animated:YES];
    startDatePicker.tag = 0;
    endDatePicker.tag = 1;
    self.inputStart.text = [formatter stringFromDate:oneYearAgo];
    self.inputStart.inputView = startDatePicker;
    self.inputEnd.text = [formatter stringFromDate:today];
    self.inputEnd.inputView = endDatePicker;
    self.inputStart.inputAccessoryView = [AppDelegate keyboardToolViewWithLeftButtons:@[
        [AppDelegate keyboardToolButtonWithTitle:@"下一个" target:self action:@selector(next1)],
    ] rightButtons:@[
        [AppDelegate keyboardToolButtonWithTitle:@"取消" target:self action:@selector(cancel1)],
        [AppDelegate keyboardToolButtonWithTitle:@"完成" target:self action:@selector(sure1)],
    ]];
    self.inputEnd.inputAccessoryView = [AppDelegate keyboardToolViewWithLeftButtons:@[
        [AppDelegate keyboardToolButtonWithTitle:@"上一个" target:self action:@selector(next2)],
    ] rightButtons:@[
        [AppDelegate keyboardToolButtonWithTitle:@"取消" target:self action:@selector(cancel2)],
        [AppDelegate keyboardToolButtonWithTitle:@"完成" target:self action:@selector(sure2)],
    ]];
}

- (void)cancel1 {
    [self.inputStart resignFirstResponder];
}

- (void)cancel2 {
    [self.inputEnd resignFirstResponder];
}

- (void)next1 {
    self.inputStart.text = [formatter stringFromDate:startDatePicker.date];
    [self.inputStart resignFirstResponder];
    [self.inputEnd becomeFirstResponder];
}

- (void)next2 {
    self.inputEnd.text = [formatter stringFromDate:endDatePicker.date];
    [self.inputEnd resignFirstResponder];
    [self.inputStart becomeFirstResponder];
}

- (void)sure1 {
    self.inputStart.text = [formatter stringFromDate:startDatePicker.date];
    [self.inputStart resignFirstResponder];
}

- (void)sure2 {
    self.inputEnd.text = [formatter stringFromDate:endDatePicker.date];
    [self.inputEnd resignFirstResponder];
}

- (void)ValueChanged:(UIDatePicker *)datePicker {
    NSString *date = [formatter stringFromDate:datePicker.date];
    if (datePicker.tag == 0) {
        self.inputStart.text = date;
    } else if (datePicker.tag == 1) {
        self.inputEnd.text = date;
    }
}

- (BOOL)isValidBoard:(NSString *)board {
    if (![Helper checkLogin:NO]) {
        return ![board isEqualToString:@"1"] && ![board isEqualToString:@"-1"];
    }
    return YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return searchResult.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (searchResult.count > 0) {
        return [NSString stringWithFormat:@"共有%ld条结果", searchResult.count];
    } else {
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dict = searchResult[indexPath.row];
    SearchViewCell *cell = [self.tableview dequeueReusableCellWithIdentifier:@"resultlist"];
    NSString *titleText = dict[@"title"] ? dict[@"title"] : dict[@"text"];
    titleText = [Helper restoreTitle:titleText];
    cell.titleText.text = titleText;
    cell.authorText.text = dict[@"author"];
    if ([self.bid isEqualToString:@"-1"] && !SIMPLE_VIEW) {
        cell.timeText.text = [NSString stringWithFormat:@"%@ • %@", [Helper getBoardTitle:dict[@"bid"]], dict[@"time"]];
    } else {
        cell.timeText.text = dict[@"time"];
    }
    // Configure the cell...
    return cell;
}

- (IBAction)didEndOnExit:(id)sender {
    [self search:nil];
}

- (IBAction)search:(id)sender {
    [self.view endEditing:YES];
    text = self.inputText.text;
    author = self.inputAuthor.text;
    NSString *beginTime;
    NSString *endTime;
    if (self.inputStart.text.length > 0) {
        beginTime = self.inputStart.text;
    } else {
        beginTime = MIN_DATE;
    }
    if (self.inputEnd.text.length > 0) {
        endTime = self.inputEnd.text;
    } else {
        endTime = [formatter stringFromDate:[NSDate date]];
    }
    if (self.inputType.selectedSegmentIndex == 0) {
        type = @"thread";
    } else {
        type = @"post";
    }
    if (![self isValidBoard:self.bid]) {
        [self showAlertWithTitle:@"错误" message:[NSString stringWithFormat:@"您未登录，不能搜索%@！", [Helper getBoardTitle:self.bid]] confirmTitle:@"选择讨论区" confirmAction:^(UIAlertAction *action) {
            [self chooseBoard:nil];
        }];
        return;
    }
    if (text.length == 0 && author.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"没有输入搜索内容！" cancelAction:^(UIAlertAction *action) {
            [self.inputText becomeFirstResponder];
        }];
        if (control.isRefreshing) {
            [control endRefreshing];
        }
        return;
    }
    if (text.length == 0) { // 空内容 按作者搜索
        type = @"post";
        [self.inputType setSelectedSegmentIndex:1];
    }
    NSDate *begin = [formatter dateFromString:beginTime];
    NSDate *end = [formatter dateFromString:endTime];
    NSTimeInterval earlyDate = [begin timeIntervalSince1970]*1;
    NSTimeInterval lateDate = [end timeIntervalSince1970]*1;
    if (earlyDate - lateDate > 0) {
        [self showAlertWithTitle:@"错误" message:@"日期输入有误！"];
        if (control.isRefreshing) {
            [control endRefreshing];
        }
        return;
    }
    // NSLog(@"Search Text:%@, Type:%@, BT:%@, ET:%@, Author:%@ Bid:%@", text, type, beginTime, endTime, author, self.b);
    [hud showWithProgressMessage:@"正在搜索"];
    NSDictionary *dict = @{
        @"type" : type,
        @"bid" : self.bid,
        @"text" : text,
        @"starttime" : beginTime,
        @"endtime" : endTime,
        @"username" : author
    };
    [Helper callApiWithParams:dict toURL:@"search" callback:^(NSArray *result, NSError *err) {
        if (control.isRefreshing) {
            [control endRefreshing];
        }
        if (err || result.count == 0) {
            searchResult=nil;
            [hud hideWithFailureMessage:@"搜索失败"];
            NSLog(@"%@",err);
            return;
        }
        [hud hideWithSuccessMessage:@"搜索成功"];
        searchResult=[result subarrayWithRange:NSMakeRange(1, result.count-1)];
//         NSLog(@"Search Result:%@", searchResult);
        if (searchResult.count == 0) {
            [self showAlertWithTitle:@"没有结果" message:@"请尝试更换关键词、日期或讨论区"];
        } else {
            [self.tableview reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }];
}

- (IBAction)chooseBoard:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"请选择要搜索的讨论区" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *board in [BOARDS arrayByAddingObject:@"-1"]) {
        NSString *boardTitle = [Helper getBoardTitle:board];
        BOOL isValid = [self isValidBoard:board];
        UIAlertAction *alertAction = [UIAlertAction actionWithTitle:isValid && [self.bid isEqualToString:board] ? [@"✅ " stringByAppendingString:boardTitle] : boardTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.bid = board;
            self.labelB.text = boardTitle;
            [self refreshBackgroundViewAnimated:YES];
        }];
        alertAction.enabled = isValid;
        [alertController addAction:alertAction];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (![self isValidBoard:self.bid]) {
            [self.navigationController popViewControllerAnimated:YES];
        }
    }]];
    alertController.popoverPresentationController.sourceView = self.labelB;
    alertController.popoverPresentationController.sourceRect = self.labelB.bounds;
    [self presentViewControllerSafe:alertController];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"post"]) {
        ContentViewController *dest = [segue destinationViewController];
        NSDictionary *dict = searchResult[[self.tableview indexPathForCell:(UITableViewCell *)sender].row];
        dest.bid = dict[@"bid"];
        dest.tid = dict[@"tid"];
        if (dict[@"floor"]) {
            dest.destinationFloor = dict[@"floor"];
        }
        NSString *titleText = dict[@"title"] ? dict[@"title"] : dict[@"text"];
        dest.title = [Helper restoreTitle:titleText];
        [self.navigationController setToolbarHidden:NO];
    }
}

@end
