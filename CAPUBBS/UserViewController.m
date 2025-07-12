//
//  UserViewController.m
//  CAPUBBS
//
//  Created by 范志康 on 15/3/15.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import "UserViewController.h"
#import "WebViewController.h"
#import "RegisterViewController.h"
#import "ChatViewController.h"
#import "ContentViewController.h"
#import "RecentViewController.h"

@interface UserViewController ()

@end

@implementation UserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GRAY_PATTERN;
    self.preferredContentSize = CGSizeMake(400, 650);
    UIView *targetView = self.navigationController ? self.navigationController.view : self.view;
    hud = [[MBProgressHUD alloc] initWithView:targetView];
    [targetView addSubview:hud];
    if (!SIMPLE_VIEW) {
        backgroundView = [[AnimatedImageView alloc] init];
        [backgroundView setContentMode:UIViewContentModeScaleAspectFill];
        self.tableView.backgroundView = backgroundView;
    }
    
    textSize = [[DEFAULTS objectForKey:@"textSize"] intValue];
    if (self.iconData.length > 0) {
        [self.icon setImage:[UIImage imageWithData:self.iconData]];
        [self refreshBackgroundViewAnimated:NO];
    }
    
    [self.icon setRounded:YES];
    if (self.noRightBarItem) {
        self.navigationItem.rightBarButtonItems = nil;
    } else {
        if ([self.ID isEqualToString:UID]) {
            self.navigationItem.rightBarButtonItems = @[self.buttoonEdit];
        } else {
            self.navigationItem.rightBarButtonItems = @[self.buttonChat];
        }
    }
    if ([self.ID isEqualToString:UID]) {
        self.labelReport.text = @"申请删除账号";
        self.title = @"个人信息";
    }
    labels = @[self.rights, self.sign, self.hobby, self.qq, self.mailBtn, self.from, self.regDate, self.lastDate, self.post, self.reply, self.water, self.extr];
    webViewContainers = @[self.intro, self.sig1, self.sig2, self.sig3];
    heights = [@[@0, @0, @0, @0] mutableCopy];
    for (int i = 0; i < webViewContainers.count; i++) {
        CustomWebViewContainer *webViewContainer = webViewContainers[i];
        [webViewContainer initiateWebViewWithToken:NO];
        [webViewContainer setBackgroundColor:[UIColor clearColor]];
        [webViewContainer setOpaque:NO];
        [webViewContainer.webView setTag:i];
        [webViewContainer.webView setNavigationDelegate:self];
        [webViewContainer.webView.scrollView setScrollEnabled:NO];
    }
    
    recentPost = [NSMutableArray array];
    recentReply = [NSMutableArray array];
    property = @[@"rights", @"sign", @"hobby", @"qq", @"mail", @"place", @"regdate", @"lastdate", @"post", @"reply", @"water", @"extr"];
    
    [NOTIFICATION addObserver:self selector:@selector(getInformation) name:@"userUpdated" object:nil];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshControlValueChanged:) forControlEvents:UIControlEventValueChanged];
//    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    [self getInformation];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([self.ID isEqualToString:UID]) {
//        if (![[DEFAULTS objectForKey:@"FeatureEditUser3.0"] boolValue]) {
//            [self showAlertWithTitle:@"新功能！" message:@"可以编辑个人信息\n点击右上方铅笔前往" cancelTitle:@"我知道了"];
//            [DEFAULTS setObject:@(YES) forKey:@"FeatureEditUser3.0"];
//        }
    }
}

- (void)refresh:(NSNotification *)noti {
    dispatch_main_async_safe(^{
        if (self.iconData.length == 0) {
            self.iconData = noti.userInfo[@"data"];
            [self refreshBackgroundViewAnimated:YES];
        }
    });
}

- (void)refreshBackgroundViewAnimated:(BOOL)animated {
    if (SIMPLE_VIEW) {
        return;
    }
    [backgroundView setImage:[UIImage imageWithData:self.iconData] blurred:YES animated:animated];
}

- (void)refreshControlValueChanged:(UIRefreshControl *)refreshControl {
    refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"刷新"];
    [self getInformation];
}

- (void)setDefault {
    dispatch_main_sync_safe(^{
        self.username.text = self.ID;
        self.star.text = @"未知";
        iconURL = @"";
        for (int i = 0; i < labels.count; i++) {
            if (i != 4) {
                UILabel *label = labels[i];
                if (i >= 1 && i <= 5) {
                    label.text = @"不告诉你";
                } else {
                    label.text = @"未知";
                }
            } else {
                UIButton *button = labels[i];
                [button setTitle:@"不告诉你" forState:UIControlStateNormal];
                [button setEnabled:NO];
            }
        }
    });
}

- (NSString *)extractValidEmail:(NSString *)rawEmailString {
    if (!rawEmailString || rawEmailString.length == 0) {
        return @"";
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:rawEmailString options:0 range:NSMakeRange(0, rawEmailString.length)];
    if (match) {
        return [rawEmailString substringWithRange:match.range];
    }
    return @"";
}

- (void)getInformation {
    [self setDefault];
    if (self.ID.length == 0) {
        [hud showAndHideWithFailureMessage:@"用户名不合法"];
        return;
    }
    [hud showWithProgressMessage:@"查询中"];
    [Helper callApiWithParams:@{@"uid": self.ID, @"recent": @"YES", @"raw": @"YES"} toURL:@"userinfo" callback:^(NSArray *result, NSError *err) {
        if (self.refreshControl.isRefreshing) {
            [self.refreshControl endRefreshing];
        }
        if (err || result.count == 0) {
            [hud hideWithFailureMessage:@"查询失败"];
            NSLog(@"%@",err);
            self.username.text = [self.username.text stringByAppendingString:@"❗️"];
            return;
        }
        
        // NSLog(@"%@", result);
        [hud hideWithSuccessMessage:@"查询成功"];
        NSDictionary *dict = result[0];
        if ([dict[@"username"] length] == 0) {
            [self showAlertWithTitle:@"查询错误！" message:@"没有这个ID或者您还未登录！"];
            self.username.text = [self.username.text stringByAppendingString:@"❌"];
            self.navigationItem.rightBarButtonItem.enabled = NO;
        } else {
            if ([dict[@"username"] isEqualToString:UID]) {
                NSLog(@"User Info Refreshed");
                [Helper updateUserInfo:dict];
                [NOTIFICATION postNotificationName:@"infoRefreshed" object:nil];
            }
            if ([dict[@"sex"] isEqualToString:@"男"]) {
                self.username.text = [dict[@"username"] stringByAppendingString:@" ♂"];
            } else if ([dict[@"sex"] isEqualToString:@"女"]) {
                self.username.text = [dict[@"username"] stringByAppendingString:@" ♀"];
            }
            self.star.text = @"";
            for (int i = 1; i<= [dict[@"star"] intValue]; i++) {
                self.star.text = [self.star.text stringByAppendingString:@"⭐️"];
            }
            for (int i = 0; i < labels.count; i++) {
                if (!([dict[property[i]] length] == 0 || [dict[property[i]] isEqualToString:@"Array"])) {
                    if (i != 4) {
                        UILabel *label = labels[i];
                        label.text = [dict[property[i]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                    } else {
                        UIButton *button = labels[i];
                        NSString *email = dict[property[i]];
                        NSString *validEmail = [self extractValidEmail:email];
                        if (validEmail) {
                            [button setTitle:validEmail forState:UIControlStateNormal];
                            [button setEnabled:YES];
                        } else {
                            [button setTitle:email forState:UIControlStateNormal];
                            [button setEnabled:NO];
                        }
                    }
                }
            }
            iconURL = dict[@"icon"];
            if (self.iconData.length == 0) {
                [NOTIFICATION addObserver:self selector:@selector(refresh:) name:[@"imageSet" stringByAppendingString:[AnimatedImageView transIconURL:iconURL]] object:nil];
            }
            [self.icon setUrl:iconURL];
            
            for (int i = 0; i < webViewContainers.count; i++) {
                heights[i] = @0;
                WKWebView *webView = webViewContainers[i].webView;
                NSString *content = i == 0 ? dict[@"intro"] : dict[[NSString stringWithFormat:@"sig%d", i]];
                if ([content isEqualToString:@"Array"] || content.length == 0) {
                    content = @"<font color='gray'>暂无</font>";
                }
                content = [Helper transToHTML:content];
                NSString *html = [Helper htmlStringWithText:nil attachments:nil sig:content textSize:textSize];
                if (webView.isLoading) {
                    [webView stopLoading];
                }
                [webView loadHTMLString:html baseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/bbs/content/", CHEXIE]]];
            }
            
            for (int i = 1; i < result.count; i++) {
                if (result[i] && result[i][@"info"]) {
                    id info = result[i][@"info"];
                    if (![info isKindOfClass:[NSArray class]]) {
                        info = @[info];
                    }
                    for (NSDictionary *dict in info) {
                        if ([dict[@"type"] isEqualToString:@"post"]) {
                            [recentPost addObject:dict];
                        }
                        if ([dict[@"type"] isEqualToString:@"reply"]) {
                            [recentReply addObject:dict];
                        }
                    }
                }
            }
        }
    }];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [webView setWeakScriptMessageHandler:self forNames:@[@"imageClickHandler", @"heightHandler"]];
    [webView evaluateJavaScript:@"window._imageClickHandlerAvailable=true;window._lastReportedHeight=0;" completionHandler:nil];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"imageClickHandler"]) {
        [AppDelegate handleImageClickWithMessage:message hud:hud];
    }
    if ([message.name isEqualToString:@"heightHandler"]) {
        [self handleHeightWithMessage:message];
    }
}

- (void)handleHeightWithMessage:(WKScriptMessage *)message {
    float height = [message.body floatValue];
    if (height <= 0) {
        return;
    }
    NSInteger tag = message.webView.tag;
    
    height = height * (textSize / 100.0);
    if (height > 0 && height - [heights[tag] floatValue] >= 1) {
        heights[tag] = @(height);
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    for (int i = 0; i < webViewContainers.count; i++) {
        heights[i] = @0;
    }
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return UITableViewAutomaticDimension;
    } else if (indexPath.section == 1) {
        return MIN(MAX([heights[indexPath.row] floatValue], 14) + 35, WEB_VIEW_MAX_HEIGHT);
    } else {
        return 50;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2 && indexPath.row == 2) {
        if ([self.ID isEqualToString:UID]) {
            [NOTIFICATION postNotificationName:@"sendEmail" object:nil userInfo:@{
                @"recipients": REPORT_EMAIL,
                @"subject": @"CAPUBBS 申请删除账号",
                @"body": [NSString stringWithFormat:@"您好，我是%@，我申请删除该账号，希望尽快处理，谢谢！", UID],
                @"fallbackMessage": @"请前往网络维护板块反馈"
            }];
        } else {
            [NOTIFICATION postNotificationName:@"sendEmail" object:nil userInfo:@{
                @"recipients": REPORT_EMAIL,
                @"subject": @"CAPUBBS 举报违规用户",
                @"body": [NSString stringWithFormat:@"您好，我是%@，我发现用户 <a href=\"%@/bbs/user/?name=%@\">%@</a> 存在违规行为，希望尽快处理，谢谢！", ([UID length] > 0) ? UID : @"匿名用户", CHEXIE, self.ID, self.ID],
                @"isHTML": @(YES),
                @"fallbackMessage": @"请前往网络维护板块反馈"
            }];
        }
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *path = url.absoluteString;
    
    // 允许其他类型加载（如 form submit、reload）
    if (navigationAction.navigationType != WKNavigationTypeLinkActivated) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    if ([path hasPrefix:@"x-apple"]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if ([path hasPrefix:@"mailto:"]) {
        NSString *mailAddress = [path substringFromIndex:@"mailto:".length];
        [NOTIFICATION postNotificationName:@"sendEmail" object:nil userInfo:@{
            @"recipients": @[mailAddress]
        }];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if ([path hasPrefix:@"tel:"] || [path hasPrefix:@"sms:"] || [path hasPrefix:@"facetime:"] || [path hasPrefix:@"maps:"]) {
        // Directly open
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    [AppDelegate openURL:path fullScreen:YES];
    decisionHandler(WKNavigationActionPolicyCancel);
}

- (IBAction)sendMail:(id)sender {
    [NOTIFICATION postNotificationName:@"sendEmail" object:nil userInfo:@{
        @"recipients": @[self.mailBtn.titleLabel.text]
    }];
}

- (IBAction)tapPic:(UIButton *)sender {
    if (iconURL.length > 0) {
        [self showPic:[AnimatedImageView transIconURL:iconURL]];
    }
}
- (void)showPic:(NSString *)url {
    NSURL *imageUrl = [NSURL safeURLWithString:url];
    NSString *md5Url = [Helper md5:url];
    NSString *cachePath = [NSString stringWithFormat:@"%@/%@", IMAGE_CACHE_PATH, md5Url];
    if ([MANAGER fileExistsAtPath:cachePath]) {
        NSData *imageData = [MANAGER contentsAtPath:cachePath];
        // 动图是未压缩的格式 可直接调取
        if ([AnimatedImageView isAnimated:imageData]) {
            ImageFileType type = [AnimatedImageView fileType:imageData];
            [self presentImage:imageData fileName:[md5Url stringByAppendingPathExtension:[AnimatedImageView fileExtension:type]]];
            return;
        }
    }
    [hud showWithProgressMessage:@"正在载入"];
    [Downloader loadURL:imageUrl progress:^(float progress, NSUInteger expectedBytes) {
        [hud updateToProgress:progress];
    } completion:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        ImageFileType type = [AnimatedImageView fileType:data];
        if (error || type == ImageFileTypeUnknown) {
            [hud hideWithFailureMessage:@"载入失败"];
            return;
        }
        [hud hideWithSuccessMessage:@"载入成功"];
        NSString *fileName;
        if (response.suggestedFilename && response.suggestedFilename.pathExtension.length > 0) {
            fileName = response.suggestedFilename;
        } else {
            fileName = [Helper fileNameFromURL:imageUrl] ?: [md5Url stringByAppendingPathExtension:[AnimatedImageView fileExtension:type]];
        }
        [self presentImage:data fileName:fileName];
    }];
}

- (void)presentImage:(NSData *)imageData fileName:(NSString *)fileName {
    dispatch_main_async_safe((^{
        UIImage *iconImage = [self.icon.image getCenterSquareImage];
        [NOTIFICATION postNotificationName:@"previewFile" object:nil userInfo:@{
            @"fileData": imageData,
            @"fileName": fileName,
            @"fileTitle": [NSString stringWithFormat:@"%@的头像", self.ID],
            @"frame": self.icon,
            @"transitionImage": [iconImage imageByApplyingCornerRadius:iconImage.size.width / 2]
        }];
    }));
}

- (IBAction)back:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"chat"]) {
        ChatViewController *dest = [segue destinationViewController];
        dest.ID = self.ID;
        dest.directTalk = YES;
        dest.shouldHideInfo = YES;
        dest.iconData = self.iconData;
        dest.navigationItem.leftBarButtonItems = nil;
    }
    if ([segue.identifier isEqualToString:@"edit"]) {
        RegisterViewController *dest = [segue destinationViewController];
        dest.isEdit = YES;
        dest.iconData = self.iconData;
        dest.navigationItem.leftBarButtonItems = nil;
    }
    if ([segue.identifier hasPrefix:@"recent"]) {
        RecentViewController *dest = [segue destinationViewController];
        dest.iconData = self.iconData;
        dest.iconUrl = [self.icon getUrl];
        if ([segue.identifier hasSuffix:@"Post"]) {
            dest.data = recentPost;
            dest.title = @"最近主题";
        } else if ([segue.identifier hasSuffix:@"Reply"]) {
            dest.data = recentReply;
            dest.title = @"最新回复";
        }
    }
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

@end
