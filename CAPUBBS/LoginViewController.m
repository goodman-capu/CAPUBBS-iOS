//
//  LoginViewController.m
//  CAPUBBS
//
//  Created by 熊典 on 14-2-16.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "LoginViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "ContentViewController.h"
#import "WebViewController.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GRAY_PATTERN;
    [self.buttonEnter.layer setCornerRadius:10.0];
    [self.buttonRegister.layer setCornerRadius:10.0];
    [self.buttonLogin.layer setCornerRadius:10.0];
    [self.iconUser setRounded:YES];
    
    UIView *targetView = self.navigationController ? self.navigationController.view : self.view;
    hud = [[MBProgressHUD alloc] initWithView:targetView];
    [targetView addSubview:hud];
    
    [NOTIFICATION addObserver:self selector:@selector(userChanged) name:@"userChanged" object:nil];
    [NOTIFICATION addObserver:self selector:@selector(refreshUserInfo) name:@"infoRefreshed" object:nil];
    
    enterLogin = YES;
    userInfoRefreshing = NO;
    news = [NSArray arrayWithArray:[DEFAULTS objectForKey:@"newsCache"]];
    control = [[UIRefreshControl alloc] init];
    [control addTarget:self action:@selector(refreshControlValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.tableview addSubview:control];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self userChanged];
    [self showEULA];
    if (self.textUid.text.length == 0) {
        [self.textUid becomeFirstResponder];
    } else if (self.textPass.text.length == 0) {
        [self.textPass becomeFirstResponder];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.textUid resignFirstResponder];
    [self.textPass resignFirstResponder];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (@available(iOS 13.0, *)) {
        return UIStatusBarStyleDarkContent;
    } else {
        return UIStatusBarStyleDefault;
    }
}

- (void)refreshControlValueChanged:(UIRefreshControl *)refreshControl {
    control.attributedTitle = [[NSAttributedString alloc] initWithString:@"刷新"];
    [hud showWithProgressMessage:@"正在刷新"];
    // Reset to allow manual refresh
    newsRefreshTime = 0;
    [self getNewsAndInfo];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return news.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dict = news[indexPath.row];
    NSString *bid = dict[@"bid"];
    NSString *tid = dict[@"tid"];
    NSString *url = dict[@"url"];
    UITableViewCell *cell;
    if (bid.length == 0 || tid.length == 0) {
        if ([url hasPrefix:@"javascript"] || url.length == 0) {
            cell = [self.tableview dequeueReusableCellWithIdentifier:@"noLinkCell"];
            cell.tag = -1;
        } else {
            cell = [self.tableview dequeueReusableCellWithIdentifier:@"webCell"];
        }
    } else {
        cell = [self.tableview dequeueReusableCellWithIdentifier:@"postCell"];
    }
    NSString *text = dict[@"text"];
    if (![text hasPrefix:@"📣 "]) {
        int interval = [[NSDate date] timeIntervalSince1970] - [dict[@"time"] intValue];
        if (interval <= 7 * 24 * 3600) { // 一周内的公告
            text = [@"📣 " stringByAppendingString:text];
        }
    }
    cell.textLabel.text = text;
    cell.textLabel.textColor = BLUE;
    cell.backgroundColor = [UIColor colorWithWhite:1 alpha:(0.6 - indexPath.row / (2.0 * news.count))]; // 渐变色效果 alpha ∈ [0.6, 0.1)递减
    
    // Configure the cell...
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UITableViewCell *cell = [self.tableview cellForRowAtIndexPath:indexPath];
    if (cell.tag == -1) {
        [self showAlertWithTitle:@"无法打开" message:@"不是论坛链接！"];
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return ([Helper checkRight] > 0);
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        NSDictionary *item = news[indexPath.row];
        [self showAlertWithTitle:@"警告" message:[NSString stringWithFormat:@"确定要删除该公告吗？\n删除操作不可逆！\n\n标题：%@", item[@"text"]] confirmTitle:@"删除" confirmAction:^(UIAlertAction *action) {
            [hud showWithProgressMessage:@"正在操作"];
            NSDictionary *dict = @{
                @"method" : @"delete",
                @"time" : item[@"time"]
            };
            [Helper callApiWithParams:dict toURL:@"news" callback:^(NSArray *result, NSError *err) {
                if (err || result.count == 0) {
                    [hud hideWithFailureMessage:@"操作失败"];
                } else {
                    if ([result[0][@"code"] integerValue] == 0) {
                        [hud hideWithSuccessMessage:@"操作成功"];
                        NSMutableArray *temp = [NSMutableArray arrayWithArray:news];
                        [temp removeObjectAtIndex:indexPath.row];
                        news = [NSArray arrayWithArray:temp];
                        [self.tableview deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                    } else {
                        [hud hideWithFailureMessage:@"操作失败"];
                        [self showAlertWithTitle:@"操作失败" message:result[0][@"msg"]];
                    }
                }
                dispatch_global_after(0.5, ^{
                    [self getNewsAndInfo];
                });
            }];
        }];
    }
}

- (IBAction)addNews:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"添加公告"
                                                                   message:@"请填写公告的标题和链接\n链接可以为空"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(alertController) weakAlertController = alertController; // 避免循环引用
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"标题";
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"链接";
        textField.keyboardType = UIKeyboardTypeURL;
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"添加"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakAlertController) alertController = weakAlertController;
        if (!alertController) {
            return;
        }
        NSString *text = alertController.textFields[0].text;
        NSString *url = alertController.textFields[1].text;
        if (text.length == 0) {
            [self showAlertWithTitle:@"错误" message:@"您未填写公告的内容"];
            return;
        }
        
        [hud showWithProgressMessage:@"正在操作"];
        NSDictionary *dict = @{
            @"method" : @"add",
            @"text" : text,
            @"url" : url
        };
        [Helper callApiWithParams:dict toURL:@"news" callback:^(NSArray *result, NSError *err) {
            if (err || result.count == 0) {
                [hud hideWithFailureMessage:@"操作失败"];
            } else {
                if ([result[0][@"code"] integerValue] == 0) {
                    [hud hideWithSuccessMessage:@"操作成功"];
                } else {
                    [hud hideWithFailureMessage:@"操作失败"];
                    [self showAlertWithTitle:@"操作失败" message:result[0][@"msg"]];
                }
            }
            dispatch_global_after(0.5, ^{
                [self getNewsAndInfo];
            });
        }];
    }]];
    [self presentViewControllerSafe:alertController];
}

- (void)userChanged {
    dispatch_main_async_safe(^{
        NSLog(@"Refresh User State");
        NSString *userName = UID;
        BOOL shouldResetVibrate = lastUserName.length > 0 && ![userName isEqualToString:lastUserName];
        lastUserName = userName;
        if (userName.length == 0) {
            [self.iconUser setImage:PLACEHOLDER];
            [self.buttonAddNews setHidden:YES];
        } else {
            [self refreshUserInfo];
            if (userInfoRefreshing == NO) {
                userInfoRefreshing = YES;
                [Helper callApiWithParams:@{@"uid": UID} toURL:@"userinfo" callback:^(NSArray *result, NSError *err) {
                    userInfoRefreshing = NO;
                    if (!err && result.count > 0) {
                        [Helper updateUserInfo:result[0]];
                        if (shouldResetVibrate) {
                            vibrateTime = 0;
                        }
                        [NOTIFICATION postNotificationName:@"infoRefreshed" object:nil];
                    }
                }];
            }
        }
        [self setLoginView];
    });
}

- (void)tryVibrate:(NSUInteger)mewMsgNum {
    if (![[DEFAULTS objectForKey:@"vibrate"] boolValue]) {
        return;
    }
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    // 10 min interval between vibrations
    if (vibrateTime > 0 && currentTime - vibrateTime < 10 * 60) {
        NSLog(@"Skip Vibrate");
        return;
    }
    vibrateTime = currentTime;

    if ([[[UIDevice currentDevice] model] containsString:@"iPhone"]) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        NSLog(@"Vibreate");
    } else {
        NSLog(@"Can Not Vibreate. Show Alert Instead");
        UIViewController *topVc = [AppDelegate getTopViewController];
        if (topVc) {
            [topVc showAlertWithTitle:[NSString stringWithFormat:@"您有%ld条新消息", mewMsgNum]
                              message:@"可以前往消息中心查看"];
        }
    }
}

- (void)refreshUserInfo {
    dispatch_main_async_safe((^{
        NSDictionary *infoDict = USERINFO;
        if (![infoDict isEqual:@""]) {
            [self.iconUser setUrl:infoDict[@"icon"]];
            NSInteger newMsg = [infoDict[@"newmsg"] integerValue];
            if ([Helper checkLogin:NO] && newMsg > 0) {
                dispatch_global_after(0.5, ^{
                    [self tryVibrate:newMsg];
                });
            }
        } else {
            [self.iconUser setImage:PLACEHOLDER];
        }
        [self.buttonAddNews setHidden:([Helper checkRight] < 1)];
    }));
}

- (void)setLoginView {
    NSString *username = UID;
    self.textUid.text = UID;
    self.textPass.text = PASS;
    self.buttonLogin.highlighted = NO;
    self.buttonLogin.userInteractionEnabled = YES;
    self.textUid.userInteractionEnabled = YES;
    self.textPass.userInteractionEnabled = YES;
    self.textPass.secureTextEntry = YES;
    if (username.length > 0) {
        if (![Helper checkLogin:NO] && enterLogin && [[DEFAULTS objectForKey:@"autoLogin"] boolValue]) {
            NSLog(@"Auto Login");
            [self login:nil];
            enterLogin = NO;
        } else {
            [self getNewsAndInfo];
            if ([Helper checkLogin:NO]) {
                self.textUid.text = [username stringByAppendingString:@" ✅"];
                NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:@"已登录"];
                [attr addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:0 alpha:0.5] range:NSMakeRange(0, attr.length)];
                self.textPass.secureTextEntry = NO;
                self.textPass.attributedText = attr;
                self.buttonLogin.highlighted = YES;
                self.buttonLogin.userInteractionEnabled = NO;
                self.textUid.userInteractionEnabled = NO;
                self.textPass.userInteractionEnabled = NO;
            }
        }
    } else {
        [self getNewsAndInfo];
    }
}

- (IBAction)login:(id)sender {
    [self.textPass resignFirstResponder];
    [self.textUid resignFirstResponder];
    NSString *uid = self.textUid.text;
    NSString *pass = self.textPass.text;
    if (uid.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"用户名不能为空" cancelAction:^(UIAlertAction *action) {
            [self.textUid becomeFirstResponder];
        }];
        return;
    }
    if (pass.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"密码不能为空" cancelAction:^(UIAlertAction *action) {
            [self.textPass becomeFirstResponder];
        }];
        return;
    }
    [hud showWithProgressMessage:@"正在登录"];
    NSDictionary *dict = @{
        @"username" : uid,
        @"password" : [Helper md5:pass],
        @"device" : [Helper doDevicePlatform],
        @"version" : [[UIDevice currentDevice] systemVersion]
    };
    [Helper callApiWithParams:dict toURL:@"login" callback:^(NSArray *result, NSError *err) {
        //NSLog(@"%@",result);
        if (err || result.count == 0) {
            [hud hideWithFailureMessage:@"登录失败"];
            [self getNewsAndInfo];
//            [self showAlertWithTitle:@"登录失败" message:[err localizedDescription]];
            return ;
        }
        int code = [result[0][@"code"] intValue];
        if (code == 0) {
            [hud hideWithSuccessMessage:@"登录成功"];
        } else {
            [hud hideWithFailureMessage:@"登录失败"];
        }
        if (code == 0) {
            [GROUP_DEFAULTS setObject:uid forKey:@"uid"];
            [GROUP_DEFAULTS setObject:pass forKey:@"pass"];
            [GROUP_DEFAULTS setObject:result[0][@"token"] forKey:@"token"];
            [LoginViewController updateIDSaves];
            NSLog(@"Login - %@", uid);
            [NOTIFICATION postNotificationName:@"userChanged" object:nil userInfo:nil];
            return;
        }
        if (code == 1) {
            [self showAlertWithTitle:@"登录失败" message:@"密码错误！" cancelAction:^(UIAlertAction *action) {
                [self.textPass becomeFirstResponder];
            }];
        } else if (code == 2) {
            [self showAlertWithTitle:@"登录失败" message:@"用户名不存在！" cancelAction:^(UIAlertAction *action) {
                [self.textUid becomeFirstResponder];
            }];
        } else {
            [self showAlertWithTitle:@"登录失败" message:@"发生未知错误！"];
        }
        [self getNewsAndInfo];
    }];
}

+ (void)updateIDSaves {
    NSMutableArray *data = [NSMutableArray arrayWithArray:[DEFAULTS objectForKey:@"ID"]];
    NSDictionary *nowDict = @{
        @"id" : UID,
        @"pass" : PASS
    };
    BOOL findID = NO;
    for (int i = 0; i < data.count; i++) {
        NSDictionary *dict = data[i];
        if ([dict[@"id"] isEqualToString:UID]) {
            findID = YES;
            if (![dict[@"pass"] isEqualToString:PASS]) {
                data[i] = nowDict;
            }
        }
    }
    if (findID == NO) {
        [data addObject:nowDict];
    }
    [DEFAULTS setObject:data forKey:@"ID"];
}

- (void)getNewsAndInfo {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    // 60 min interval between news refresh
    if (newsRefreshTime > 0 && currentTime - newsRefreshTime < 60 * 60) {
        NSLog(@"Skip Fetch News");
        return;
    }
    NSLog(@"Fetch News");
    newsRefreshTime = currentTime;
    [Helper callApiWithParams:@{@"more":@"YES"} toURL:@"main" callback:^(NSArray *result, NSError *err) {
        if (control.isRefreshing) {
            [control endRefreshing];
        }
        if (err || result.count == 0) {
            [hud hideWithFailureMessage:@"刷新失败"];
            return ;
        }
        [hud hideWithSuccessMessage:@"刷新成功"];
        
        news = [result objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, result.count-1)]]; // result的第一项是更新信息 不需要
        // NSLog(@"%@", news);
        [DEFAULTS setObject:news forKey:@"newsCache"];
        [self.tableview reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
    }];
}

- (IBAction)didEndOnExit:(UITextField*)sender {
    [self.textPass becomeFirstResponder];
}

- (IBAction)swipeLeft:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self performSegueWithIdentifier:@"main" sender:nil];
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"post"]) {
        ContentViewController *dest = [[[segue destinationViewController] viewControllers] firstObject];
        NSDictionary *dict = news[[self.tableview indexPathForCell:(UITableViewCell *)sender].row];
        dest.bid = dict[@"bid"];
        dest.tid = dict[@"tid"];
        dest.title = dict[@"text"];
        dest.navigationItem.leftBarButtonItem = [AppDelegate getCloseButtonForTarget:self action:@selector(done)];
    }
    if ([segue.identifier isEqualToString:@"web"]) {
        WebViewController *dest = [[[segue destinationViewController] viewControllers] firstObject];
        NSDictionary *dict = news[[self.tableview indexPathForCell:(UITableViewCell *)sender].row];
        dest.URL = dict[@"url"];
        dest.title = dict[@"text"];
    }
    if ([segue.identifier isEqualToString:@"account"]) {
        UIViewController *dest = [[[segue destinationViewController] viewControllers] firstObject];
        dest.navigationController.popoverPresentationController.sourceView = self.iconUser;
        dest.navigationController.popoverPresentationController.sourceRect = self.iconUser.bounds;
    }
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showEULA {
    if ([[DEFAULTS objectForKey:@"hasShownEULA"] boolValue]) {
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"最终用户许可协议"
                                                                   message:EULA
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"查看隐私政策"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        WebViewController *dest = [self.storyboard instantiateViewControllerWithIdentifier:@"webview"];
        CustomNavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
        dest.URL = [CHEXIE stringByAppendingString:@"/privacy"];
        [navi setToolbarHidden:NO];
        navi.modalPresentationStyle = UIModalPresentationPageSheet;
        [self presentViewControllerSafe:navi];
        // Show again
        [self showEULA];
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"我同意以上协议"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [DEFAULTS setObject:@(YES) forKey:@"hasShownEULA"];
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"我拒绝以上协议"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }]];
    
    [self presentViewControllerSafe:alertController];
}

@end
