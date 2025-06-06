//
//  ContentViewController.m
//  CAPUBBS
//
//  Created by 熊典 on 14-2-17.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "ContentViewController.h"
#import "ContentCell.h"
#import "ComposeViewController.h"
#import "LzlViewController.h"
#import "UserViewController.h"
#import "WebViewController.h"

static const float kOtherViewHeight = 118;
static const float kWebViewMinHeight = 40;

@interface ContentViewController ()

@end

@implementation ContentViewController

#pragma mark - View control

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GRAY_PATTERN;
    UIView *targetView = self.navigationController ? self.navigationController.view : self.view;
    hud = [[MBProgressHUD alloc] initWithView:targetView];
    [targetView addSubview:hud];
    
    textSize = [[DEFAULTS objectForKey:@"textSize"] intValue];
    performer = [[ActionPerformer alloc] init];
    if ([self.floor integerValue] > 0) { // 进入时直接跳至指定页
        page = ceil([self.floor floatValue] / 12);
    } else {
        page = 1;
    }
    selectedIndex = -1;
    isEdit = NO;
    heights = [[NSMutableArray alloc] init];
    HTMLStrings = [[NSMutableArray alloc] init];
    
    [self.refreshControl addTarget:self action:@selector(refreshControlValueChanged:) forControlEvents:UIControlEventValueChanged];
    [NOTIFICATION addObserver:self selector:@selector(refreshLzl:) name:@"refreshLzl" object:nil];
    [NOTIFICATION addObserver:self selector:@selector(shouldRefresh:) name:@"refreshContent" object:nil];
    
    [self jumpTo:page];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    //self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:YES];
    
    activity = [[NSUserActivity alloc] initWithActivityType:[BUNDLE_IDENTIFIER stringByAppendingString:@".content"]];
    activity.webpageURL = [NSURL URLWithString:URL];
    activity.title = self.title;
    [activity becomeCurrent];
    
//    if (![[DEFAULTS objectForKey:@"FeatureSize2.1"] boolValue]) {
//        [self showAlertWithTitle:@"新功能！" message:@"底栏中可以调整字体大小\n设置中还可选择默认大小" cancelTitle:@"我知道了"];
//        [DEFAULTS setObject:[NSNumber numberWithBool:YES] forKey:@"FeatureSize2.1"];
//    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [activity invalidate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Web request

- (void)jumpTo:(int)pageNum {
    [hud showWithProgressMessage:@"加载中"];
    int oldPage = page;
    if ((page = pageNum) == 1) {
        self.toolbarItems = @[self.buttonCollection, self.barFreeSpace, self.buttonJump, self.barFreeSpace, self.buttonAction, self.barFreeSpace, self.buttonCompose, self.barFreeSpace, self.buttonForward];
    } else {
        self.toolbarItems = @[self.buttonBack, self.barFreeSpace, self.buttonJump, self.barFreeSpace, self.buttonAction, self.barFreeSpace, self.buttonCompose, self.barFreeSpace, self.buttonForward];
    }
    self.buttonBack.enabled = (page > 1);
    self.buttonForward.enabled = NO;
    self.buttonLatest.enabled = NO;
    self.buttonJump.enabled = NO;
    self.buttonCompose.enabled = NO;
    URL = [NSString stringWithFormat:@"%@/bbs/content/?tid=%@&bid=%@&p=%ld", CHEXIE, self.tid, self.bid, (long)page];
    activity.webpageURL = [NSURL URLWithString:URL];
    activity.title = self.title;
    NSDictionary *dict = @{
        @"p" : [NSString stringWithFormat:@"%ld", (long)pageNum],
        @"bid" : self.bid,
        @"tid" : self.tid
    };
    [performer performActionWithDictionary:dict toURL:@"show" withBlock:^(NSArray *result, NSError *err) {
        if (self.refreshControl.isRefreshing) {
            [self.refreshControl endRefreshing];
        }
        if (err || result.count == 0 || [result[0][@"time"] hasPrefix:@"1970"]) {
            page = oldPage;
            if (!err && (result.count == 0 || [result[0][@"time"] hasPrefix:@"1970"])) {
                self.title = @"没有这个帖子";
            }
            self.buttonCollection.enabled = NO;
            [hud hideWithFailureMessage:@"加载失败"];
            NSLog(@"%@", err);
            if (err.code == 111) {
                tempPath = [NSString stringWithFormat:@"%@/bbs/content/?tid=%@&bid=%@&p=%ld", CHEXIE, self.tid, self.bid, (long)page];
                [self performSegueWithIdentifier:@"web" sender:nil];
            }
            return;
        }
        
        // NSLog(@"%@", result);
        int code = [[result.firstObject objectForKey:@"code"] intValue];
        data = [NSMutableArray arrayWithArray:result];
        if ([[result.firstObject objectForKey:@"code"] intValue] != -1 && code != 0) {
            if (code == 1 && page > 1) {
                [self jumpTo:page - 1];
                return;
            }
            [self showAlertWithTitle:@"读取失败" message:[result.firstObject objectForKey:@"msg"]];
            [hud hideWithFailureMessage:@"加载失败"];
            return ;
        }
        
        if (!(self.isCollection && page > 1)) {
            [self updateCollection];
        }
        
        [hud hideWithSuccessMessage:@"加载成功"];

        NSString *titleText = [data.firstObject objectForKey:@"title"];
        self.title = [ActionPerformer removeRe:titleText];
        isLast = [[data[0] objectForKey:@"nextpage"] isEqualToString:@"false"];
        self.buttonForward.enabled = !isLast;
        self.buttonLatest.enabled = !isLast;
        self.buttonJump.enabled = ([[[data lastObject] objectForKey:@"pages"] integerValue] > 1);
        self.buttonCompose.enabled = [ActionPerformer checkLogin:NO];
        if (data.count != 0) {
            for (NSDictionary *dict in data) {
                if (self.exactFloor.length > 0 && [dict[@"floor"] isEqualToString:self.exactFloor]) {
                    selectedIndex = [data indexOfObject:dict];
                    [self performSegueWithIdentifier:@"lzl" sender:nil];
                }
            }
        }
        self.exactFloor = @"";
        
        [self clearHeightsAndReloadData:true];
        if (data.count != 0) {
            if (self.willScroll) {
                self.willScroll = NO;
                // NSLog(@"Scroll To Index %lu", data.count-1); // Scroll问题目前没有很好地解决 不能等在WebView全加载完后再Scroll 之前又无法确定WebView的高度从而不知道滚动的终点 所以暂时取消这个机制
                // [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:data.count-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
            } else {
                [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
            }
        }
    }];
}

- (void)updateCollection {
    NSMutableArray *array = [NSMutableArray arrayWithArray:[DEFAULTS objectForKey:@"collection"]];
    for (NSMutableDictionary *mdic in array) {
        if ([self.bid isEqualToString:[mdic objectForKey:@"bid"]] && [self.tid isEqualToString:[mdic objectForKey:@"tid"]]) {
            if (page == 1) { // 更新楼主信息
                NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:mdic];
                [tmp addEntriesFromDictionary:data[0]];
                
                NSString *text = [tmp objectForKey:@"text"];
                text = [self getCollectionText:text];
                [tmp setObject:text forKey:@"text"];
                text = [tmp objectForKey:@"title"];
                text = [ActionPerformer removeRe:text];
                [tmp setObject:text forKey:@"title"];
                
                BOOL hasChange = NO;
                NSArray *keywords = @[@"title", @"text", @"author", @"icon"];
                for (NSString *keyword in keywords) {
                    if (!([tmp[keyword] isEqualToString:mdic[keyword]])) {
                        hasChange = YES;
                    }
                }
                
                [array removeObject:mdic];
                [array addObject:tmp];
                [DEFAULTS setObject:array forKey:@"collection"];
                if (hasChange) {
                    NSLog(@"Update Collection");
                    [NOTIFICATION postNotificationName:@"collectionChanged" object:nil];
                }
            }
            self.isCollection = YES;
            break;
        }
        self.isCollection = NO;
    }
    [self.buttonCollection setImage:[UIImage imageNamed:(self.isCollection ? @"star-full" : @"star-empty")]];
}

- (void)clearHeightsAndReloadData:(BOOL)reload {
    [heights removeAllObjects];
    [HTMLStrings removeAllObjects];
    for (int i = 0; i < data.count; i++) {
        NSDictionary *dict = [data objectAtIndex:i];
        [heights addObject:@0];
        NSString *html = [ContentViewController htmlStringWithText:dict[@"text"] sig:dict[@"sig"] textSize:textSize];
        NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"(<img[^>]+?src=['\"])(.+?)(['\"][^>]*>)" options:0 error:nil];
        html = [regexp stringByReplacingMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@"<a href='pic:$2'>$0</a>"];
        // NSLog(@"%@", html);
        [HTMLStrings addObject:html];
        
        if (reload) {
            ContentCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            if (cell.webView.isLoading) {
                [cell.webView stopLoading];
            }
            if (cell.heightCheckTimer && [cell.heightCheckTimer isValid]) {
                [cell.heightCheckTimer invalidate];
            }
            [cell.webView loadHTMLString:@"" baseURL:[NSURL URLWithString:CHEXIE]];
        }
    }
    if (reload) {
        [self.tableView reloadData];
    }
}

- (void)shouldRefresh:(NSNotification *)notification {
    self.willScroll = YES;
    if ([[notification.userInfo objectForKey:@"isEdit"] boolValue] == YES) {
        [self jumpTo:page];
    } else {
        [self jumpTo:[[[data lastObject] objectForKey:@"pages"] intValue]];
    }
}

- (void)refreshControlValueChanged:(UIRefreshControl *)refreshControl {
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"刷新"];
    [self jumpTo:page];
}

- (void)refresh {
    [self jumpTo:page];
}

- (IBAction)jump:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"跳转页面" message:[NSString stringWithFormat:@"请输入页码(1-%@)",[[data lastObject] objectForKey:@"pages"]] preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"页码";
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"好"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        NSString *pageip = alert.textFields.firstObject.text;
        int pagen = [pageip intValue];
        if (pagen <= 0 || pagen > [[[data lastObject] objectForKey:@"pages"] integerValue]) {
            [self showAlertWithTitle:@"错误" message:@"输入不合法"];
            return;
        }
        [self jumpTo:pagen];
    }]];
    [self presentViewControllerSafe:alert];
}

- (IBAction)gotoLatest:(id)sender {
    self.willScroll = YES;
    [self jumpTo:[[[data lastObject] objectForKey:@"pages"] intValue]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return data.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    float webViewHeight = 0;
    if (heights.count >= indexPath.row && [[heights objectAtIndex:indexPath.row] floatValue] > 0) {
        webViewHeight = [[heights objectAtIndex:indexPath.row] floatValue];
    }
    return kOtherViewHeight + MIN(MAX(kWebViewMinHeight, webViewHeight), WEB_VIEW_MAX_HEIGHT);
}

- (UITableViewCell *)getCellForView:(UIView *)view {
    UIView *currentView = view;
    while (currentView != nil) {
        if ([currentView isKindOfClass:[UITableViewCell class]]) {
            return (UITableViewCell *)currentView;
        }
        currentView = currentView.superview;
    }
    return nil;
}

- (void)updateWebViewHeight:(UIWebView *)webView {
    NSUInteger row = webView.tag;
    if (!self.isViewLoaded || !self.view.window ||
        !self.tableView || !self.tableView.window ||
        row >= [self.tableView numberOfRowsInSection:0]) { // Fix occasional crash
        return;
    }
    
    UITableViewCell *cell = [self getCellForView:webView];
    if (!cell || [self.tableView indexPathForCell:cell].row != row) {
        return;
    }
    
    [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.body.style.webkitTextSizeAdjust= '%d%%'", textSize]];
    
    NSString *height = [webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('body-wrapper').scrollHeight"];
    if (height.length &&
        [height floatValue] - [[heights objectAtIndex:row] floatValue] >= 1) {
        [heights replaceObjectAtIndex:row withObject:height];
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
    }
}

- (void)timerFiredUpdateWebViewHeight:(NSTimer *)timer {
    [self updateWebViewHeight:timer.userInfo];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSUInteger row = webView.tag;
    if (!self.isViewLoaded || !self.view.window ||
        !self.tableView || !self.tableView.window ||
        row >= [self.tableView numberOfRowsInSection:0]) { // Fix occasional crash
        return;
    }
    ContentCell *cell = (ContentCell *)[self getCellForView:webView];
    if (!cell || [self.tableView indexPathForCell:cell].row != row) {
        return;
    }
    if (cell.heightCheckTimer && [cell.heightCheckTimer isValid]) {
        [cell.heightCheckTimer invalidate];
    }
    // Do not trigger immediately, the webview might still be showing the previous content.
    cell.heightCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerFiredUpdateWebViewHeight:) userInfo:webView repeats:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSUInteger row = webView.tag;
    if (!self.isViewLoaded || !self.view.window ||
        !self.tableView || !self.tableView.window ||
        row >= [self.tableView numberOfRowsInSection:0]) { // Fix occasional crash
        return;
    }
    ContentCell *cell = (ContentCell *)[self getCellForView:webView];
    if (!cell || [self.tableView indexPathForCell:cell].row != row) {
        return;
    }
    [cell.indicatorLoading stopAnimating];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *header = @"";
    if (SIMPLE_VIEW == NO && data.count > 0) {
        header = [NSString stringWithFormat:@"%@ 第%ld/%@页", [ActionPerformer getBoardTitle:self.bid], (long)page, [[data lastObject] objectForKey:@"pages"]];
        if ([[data[0] objectForKey:@"click"] length] > 0) {
            header = [NSString stringWithFormat:@"%@ 查看：%@ 回复：%@%@", header, [data[0] objectForKey:@"click"], [data[0] objectForKey:@"reply"], self.isCollection ? @" 已收藏": @""];
        }
    }
    return header;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // NSLog(@"Cell in row %d", (int)indexPath.row);
    ContentCell *cell = [tableView dequeueReusableCellWithIdentifier:@"content" forIndexPath:indexPath];
    
    cell.buttonAction.tag = indexPath.row;
    cell.buttonLzl.tag = indexPath.row;
    cell.buttonIcon.tag = indexPath.row;
    cell.webView.tag = indexPath.row;
    
    NSDictionary *dict = data[indexPath.row];
    NSString *author = [dict[@"author"] stringByAppendingString:@" "];
    int star = [dict[@"star"] intValue];
    for (int i = 1; i <= star; i++) {
        author = [author stringByAppendingString:@"★"];
    }
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:author];
    [attr addAttribute:(NSString *)NSForegroundColorAttributeName value:[UIColor colorWithWhite:0 alpha:0.25] range:NSMakeRange(author.length-star,star)];
    cell.labelAuthor.attributedText = attr;
    cell.labelDate.text = dict[@"time"];
    NSString *floor;
    switch ([dict[@"floor"] integerValue]) {
        case 1:
            floor = @"楼主";
            break;
        case 2:
            floor = @"沙发";
            break;
        case 3:
            floor = @"板凳";
            break;
        case 4:
            floor = @"地席";
            break;
        default:
            floor = [NSString stringWithFormat:@"%@楼",dict[@"floor"]];
            break;
    }
    cell.labelInfo.text = floor;
    [cell.buttonLzl setTitle:[NSString stringWithFormat:@"评论 (%@)",dict[@"lzl"]] forState:UIControlStateNormal];
    if ([dict[@"lzl"] isEqualToString:@"0"]) {
        [cell.buttonLzl setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    } else {
        [cell.buttonLzl setTitleColor:BLUE forState:UIControlStateNormal];
    }
    
    if (SIMPLE_VIEW== NO) {
        if (dict[@"edittime"] && ![dict[@"edittime"] isEqualToString:dict[@"time"]]) {
            cell.labelDate.text = [cell.labelDate.text stringByAppendingString:[NSString stringWithFormat:@"\n%@", dict[@"edittime"]]];
        }
        if ([dict[@"type"] isEqualToString:@"web"]) {
            cell.labelInfo.text = [cell.labelInfo.text stringByAppendingString:@"\n🖥"];
        } else if ([dict[@"type"] isEqualToString:@"android"]) {
            cell.labelInfo.text = [cell.labelInfo.text stringByAppendingString:@"\n📱"];
        } else if ([dict[@"type"] isEqualToString:@"ios"]) {
            cell.labelInfo.text = [cell.labelInfo.text stringByAppendingString:@"\n📱"];
        }
    }
    
    [cell.icon setUrl:dict[@"icon"]];
    
    [cell.webView setDelegate:self];
    [cell.webView loadHTMLString:[HTMLStrings objectAtIndex:indexPath.row] baseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/bbs/content/?", CHEXIE]]];
    
    
    if (([[heights objectAtIndex:indexPath.row] floatValue] > 0)) {
        [cell.indicatorLoading stopAnimating];
    } else {
        [cell.indicatorLoading startAnimating];
    }
    
    if (cell.gestureRecognizers.count == 0 && cell.topView.gestureRecognizers.count == 0) {
    UITapGestureRecognizer *tapTwice = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapWeb:)];
    [tapTwice setNumberOfTapsRequired:2];
    [cell addGestureRecognizer:tapTwice];
    [cell.topView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressTop:)]];
    }
    
    return cell;
}

#pragma mark - Content view

// 开始拖拽视图
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    contentOffsetY = scrollView.contentOffset.y;
    isAtEnd = NO;
}

// 滚动时调用此方法
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // NSLog(@"scrollView.contentOffset:%f, %f", scrollView.contentOffset.x, scrollView.contentOffset.y);
    if (isAtEnd == NO && scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.frame.size.height) {
        if (heights.count > 0 && [[heights lastObject] floatValue] > 0) {
            [self.navigationController setToolbarHidden:NO animated:YES];
            isAtEnd = YES;
        }
    }
    if (isAtEnd == NO && scrollView.dragging) { // 拖拽
        if ((scrollView.contentOffset.y - contentOffsetY) > 5.0f) { // 向上拖拽
            [self.navigationController setToolbarHidden:YES animated:YES];
        } else if ((contentOffsetY - scrollView.contentOffset.y) > 5.0f) { // 向下拖拽
            [self.navigationController setToolbarHidden:NO animated:YES];
        }
    }
}

- (void)showPic:(NSURL *)url {
    [hud showWithProgressMessage:@"正在载入"];
    [self performSelectorInBackground:@selector(showPicThread:) withObject:url];
}
- (void)showPicThread:(NSURL *)url {
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable idata, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (idata) {
            imgPath = [NSString stringWithFormat:@"%@/%@.%@", NSTemporaryDirectory(), [ActionPerformer md5:url.absoluteString], ([AsyncImageView fileType:idata] == GIF_TYPE) ? @"gif" : @"png"];
        }
        [self performSelectorOnMainThread:@selector(presentImage:) withObject:idata waitUntilDone:NO];
    }];
    [task resume];
}
- (void)presentImage:(NSData *)image {
    if (!image || ![UIImage imageWithData:image]) {
        [hud hideWithFailureMessage:@"载入失败"];
        return;
    } else {
        [hud hideWithSuccessMessage:@"载入成功"];
    }
    [image writeToFile:imgPath atomically:YES];
    dic = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:imgPath]];
    dic.delegate = self;
    dic.name = @"查看帖子图片";
    [dic presentPreviewAnimated:YES];
}
- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self;
}
- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller {
    return self.view;
}
- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController *)controller {
    [MANAGER removeItemAtPath:imgPath error:nil];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType { // 处理帖子中的URL
//     NSLog(@"type=%d,path=%@",(int)navigationType,request.URL.absoluteString);
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        NSString *path = request.URL.absoluteString;
        
        if ([path hasPrefix:@"x-apple"]) {
            return NO;
        }
        
        if ([path hasPrefix:@"pic:"]) {
            NSString *piclink = [path substringFromIndex:@"pic:".length];
            NSURL *picurl = [NSURL URLWithString:piclink];
            if (![piclink hasPrefix:@"http://"] && ![piclink hasPrefix:@"https://"] && ![piclink hasPrefix:@"ftp://"]) {
                picurl = [NSURL URLWithString:piclink relativeToURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/bbs/content/?", CHEXIE]]];
            }
            [self showPic:picurl];
            return NO;
        }
        
        if ([path hasPrefix:@"mailto:"]) {
            if ([CustomMailComposeViewController canSendMail]) {
                path = [path substringFromIndex:@"mailto:".length];
                mail = [[CustomMailComposeViewController alloc] init];
                [mail.navigationBar setBarStyle:UIBarStyleBlackTranslucent];
                [mail.navigationBar setTintColor:[UIColor whiteColor]];
                [mail setToRecipients:@[path]];
                mail.mailComposeDelegate = self;
                [self presentViewControllerSafe:mail];
            }
            return NO;
        }
        if ([path hasPrefix:@"tel:"]) {
            // Directly open
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:path] options:@{} completionHandler:nil];
            return NO;
        }
        
        NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:@"((http://|https://)?/bbs/user)" options:0 error:nil];
        NSArray *matchs = [regular matchesInString:path options:0 range:NSMakeRange(0, path.length)];
        if (matchs.count != 0) {
            NSRange range = [path rangeOfString:@"name="];
            NSString *uid = [path substringFromIndex:range.location+range.length];
            uid = [uid stringByRemovingPercentEncoding];
            [self performSegueWithIdentifier:@"userInfo" sender:uid];
            return NO;
        }
        
        NSDictionary *dict = [ContentViewController getLink:path];
        if (dict.count > 0 && ![dict[@"tid"] isEqualToString:@""]) {
            ContentViewController *next = [self.storyboard instantiateViewControllerWithIdentifier:@"content"];
            next.bid = dict[@"bid"];
            next.tid = dict[@"tid"];
            next.floor = [NSString stringWithFormat:@"%d", [dict[@"p"] intValue] * 12];
            next.title = @"帖子跳转中";
            [self.navigationController pushViewController:next animated:YES];
            return NO;
        }
        
        tempPath = path;
        [self performSegueWithIdentifier:@"web" sender:nil];
        return NO;
    } else {
        return YES;
    }
}

- (void)deletePost {
    if (![ActionPerformer checkLogin:YES]) {
        return;
    }
    [hud showWithProgressMessage:@"正在删除"];
    NSDictionary *dict = @{
        @"bid" : self.bid,
        @"tid" : self.tid,
        @"pid" : data[selectedIndex][@"floor"]
    };
    [performer performActionWithDictionary:dict toURL:@"delete" withBlock:^(NSArray *result, NSError *err) {
        if (err || result.count == 0) {
            [hud hideWithFailureMessage:@"删除失败"];
            [self showAlertWithTitle:@"错误" message:err.localizedDescription];
            return;
        }
        NSInteger back=[[[result firstObject] objectForKey:@"code"] integerValue];
        if (back == 0) {
            [hud hideWithSuccessMessage:@"删除成功"];
        } else {
            [hud hideWithFailureMessage:@"删除失败"];
        }
        switch (back) {
            case 0:{
                [self.tableView setEditing:NO];
                [data removeObjectAtIndex:selectedIndex];
                [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:selectedIndex inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
                if ([self.tableView numberOfRowsInSection:0] == 0) {
                    if (page > 1) {
                        page--;
                        [self performSelector:@selector(refresh) withObject:nil afterDelay:0.5];
                    } else {
                        [self.navigationController performSelector:@selector(popViewControllerAnimated:) withObject:[NSNumber numberWithBool:YES] afterDelay:0.5];
                        [NOTIFICATION postNotificationName:@"refreshList" object:nil];
                    }
                } else {
                    [self performSelector:@selector(refresh) withObject:nil afterDelay:0.5];
                }
            }
                break;
            case 1:{
                [self showAlertWithTitle:@"错误" message:@"密码错误，请重新登录！"];
                return;
            }
                break;
            case 2:{
                [self showAlertWithTitle:@"错误" message:@"用户不存在，请重新登录！"];
                return;
            }
                break;
            case 3:{
                [self showAlertWithTitle:@"错误" message:@"您的账号被封禁，请联系管理员！"];
                return;
            }
                break;
            case 4:{
                [self showAlertWithTitle:@"错误" message:@"您的操作过频繁，请稍后再试！"];
                return;
            }
                break;
            case 5:{
                [self showAlertWithTitle:@"错误" message:@"文章被锁定，无法操作！"];
                return;
            }
                break;
            case 6:{
                [self showAlertWithTitle:@"错误" message:@"帖子不存在或服务器错误！"];
                return;
            }
                break;
            case 10:{
                [self showAlertWithTitle:@"错误" message:@"您的权限不够，无法操作！"];
                return;
            }
                break;
            case -25: {
                [self showAlertWithTitle:@"错误" message:@"您长时间未登录，请重新登录！"];
                return;
            }
                break;
            default:{
                [self showAlertWithTitle:@"错误" message:@"发生未知错误！"];
                return;
            }
        }
    }];
}

- (IBAction)changeCollection:(id)sender {
    NSMutableArray *array = [NSMutableArray arrayWithArray:[DEFAULTS objectForKey:@"collection"]];
    NSMutableDictionary *mdic;
    if (self.isCollection) {
        for (mdic in array) {
            if ([self.bid isEqualToString:[mdic objectForKey:@"bid"]] && [self.tid isEqualToString:[mdic objectForKey:@"tid"]]) {
                [array removeObject:mdic];
                self.isCollection = NO;
                [hud showAndHideWithSuccessMessage:@"取消收藏"];
                break;
            }
        }
    } else {
        mdic = [NSMutableDictionary dictionaryWithDictionary:@{
            @"collectionTime" : [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]],
            @"bid" : self.bid,
            @"tid" : self.tid,
            @"title" : [ActionPerformer removeRe:self.title]
        }];
        [array addObject:mdic];
        self.isCollection = YES;
        [hud showAndHideWithSuccessMessage:@"收藏完成"];
    }
    [DEFAULTS setObject:array forKey:@"collection"];
    if (self.isCollection == NO) {
        NSLog(@"Delete Collection");
        [NOTIFICATION postNotificationName:@"collectionChanged" object:nil];
    }
    [self updateCollection];
    if ([[self.tableView visibleCells] containsObject:[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]]]) {
        [self.tableView reloadData];
    }
}

- (IBAction)back:(id)sender {
    [self jumpTo:page - 1];
}

- (IBAction)forward:(id)sender {
    [self jumpTo:page + 1];
}

- (IBAction)action:(id)sender {
    UIAlertController *action = [UIAlertController alertControllerWithTitle:@"更多操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [action addAction:[UIAlertAction actionWithTitle:@"举报" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        if ([CustomMailComposeViewController canSendMail]) {
            mail = [[CustomMailComposeViewController alloc] init];
            mail.mailComposeDelegate = self;
            [mail.navigationBar setBarStyle:UIBarStyleBlackTranslucent];
            [mail.navigationBar setTintColor:[UIColor whiteColor]];
            [mail setSubject:@"CAPUBBS 举报违规帖子"];
            [mail setToRecipients:REPORT_EMAIL];
            [mail setMessageBody:[NSString stringWithFormat:@"您好，我是%@，我在帖子 <a href=\"%@\">%@</a> 中发现了违规内容，希望尽快处理，谢谢！", ([UID length] > 0) ? UID : @"匿名用户", URL, self.title] isHTML:YES];
            [self presentViewControllerSafe:mail];
        } else {
            [self showAlertWithTitle:@"您的设备无法发送邮件" message:@"请前往网络维护板块反馈"];
        }
    }]];
    [action addAction:[UIAlertAction actionWithTitle:self.isCollection ? @"取消收藏" : @"收藏" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self changeCollection:nil];
    }]];
    [action addAction:[UIAlertAction actionWithTitle:@"分享" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *shareURL = [[NSURL alloc] initWithString:URL];
        NSString *title = self.title;
        UIActivityViewController *activityViewController =
        [[UIActivityViewController alloc] initWithActivityItems:@[title, shareURL] applicationActivities:nil];
        activityViewController.popoverPresentationController.barButtonItem = self.buttonAction;
        [self presentViewControllerSafe:activityViewController];
    }]];
    [action addAction:[UIAlertAction actionWithTitle:@"打开网页版" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        WebViewController *dest = [self.storyboard instantiateViewControllerWithIdentifier:@"webview"];
        CustomNavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
        dest.URL = URL;
        [navi setToolbarHidden:NO];
        navi.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewControllerSafe:navi];
    }]];
    if (textSize + 10 != 100 && textSize < 200) {
        [action addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"增大字体至%d%%", textSize + 10] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            textSize += 10;
            [self clearHeightsAndReloadData:false];
        }]];
    }
    if (textSize - 10 != 100 & textSize > 50) {
        [action addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"减小字体至%d%%", textSize - 10] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            textSize -= 10;
            [self clearHeightsAndReloadData:false];
        }]];
    }
    if (textSize != 100) {
        [action addAction:[UIAlertAction actionWithTitle:@"恢复字体至100%" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            textSize = 100;
            [self clearHeightsAndReloadData:false];
        }]];
    }
    [action addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    action.popoverPresentationController.barButtonItem = self.buttonAction;
    [self presentViewControllerSafe:action];
}

- (void)mailComposeController:(CustomMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error{
    [mail dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)swipeRight:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (self.buttonForward.enabled == YES && ![[DEFAULTS objectForKey:@"oppositeSwipe"] boolValue])
            [self jumpTo:page + 1];
        if (self.buttonBack.enabled == YES && [[DEFAULTS objectForKey:@"oppositeSwipe"] boolValue])
            [self jumpTo:page - 1];
    }
}

- (IBAction)swipeLeft:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (self.buttonForward.enabled == YES && [[DEFAULTS objectForKey:@"oppositeSwipe"] boolValue])
            [self jumpTo:page + 1];
        if (self.buttonBack.enabled == YES && ![[DEFAULTS objectForKey:@"oppositeSwipe"] boolValue])
            [self jumpTo:page - 1];
    }
}

- (void)refreshLzl:(NSNotification *)notification {
    if (selectedIndex >= 0 && selectedIndex < data.count && notification && [[notification.userInfo objectForKey:@"fid"] isEqualToString:[data[selectedIndex] objectForKey:@"fid"]]) {
        __block NSString *num = [notification.userInfo objectForKey:@"num"];
        [data[selectedIndex] setObject:num forKey:@"lzl"];
        ContentCell *cell = (ContentCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:selectedIndex inSection:0]];
        [cell.buttonLzl setTitle:[NSString stringWithFormat:@"评论 (%@)", num] forState:UIControlStateNormal];
        if ([num isEqualToString:@"0"]) {
            [cell.buttonLzl setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        } else {
            [cell.buttonLzl setTitleColor:BLUE forState:UIControlStateNormal];
        }
    }
}

- (void)doubleTapWeb:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint point = [sender locationInView:self.tableView];
        NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (indexPath == nil) {
            return ;
        }
        ContentCell *cell = (ContentCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        if (cell.webView.scrollView.isScrollEnabled == NO) {
            [hud showAndHideWithSuccessMessage:@"透视模式"];
            cell.webView.scrollView.scrollEnabled = YES;
            [cell.webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('body-mask').style.backgroundColor = 'rgba(127, 127, 127, 0.75)'"];
        } else {
            [hud showAndHideWithSuccessMessage:@"恢复默认"];
            cell.webView.scrollView.scrollEnabled = NO;
            [cell.webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('body-mask').style.backgroundColor = ''"];
        }
    }
}

- (IBAction)moreAction:(UIButton *)sender {
    selectedIndex = sender.tag;
    [self showMoreAction:sender];
}

- (void)showMoreAction:(UIView *)view {
    NSDictionary *item = data[selectedIndex];
    UIAlertController *action = [UIAlertController alertControllerWithTitle:@"更多操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [action addAction:[UIAlertAction actionWithTitle:@"引用" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if ([ActionPerformer checkLogin:YES]) {
            NSString *content = item[@"text"];
            content = [self getValidQuote:content];
            content = [ContentViewController restoreFormat:content];
            defaultContent = [NSString stringWithFormat:@"[quote=%@]%@[/quote]\n", item[@"author"], content];
            [self performSegueWithIdentifier:@"compose" sender:self.buttonCompose];
        }
    }]];
    [action addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *content = item[@"text"];
        content = [ContentViewController restoreFormat:content];
        content = [ContentViewController removeHTML:content];
        [[UIPasteboard generalPasteboard] setString:content];
        [hud showAndHideWithSuccessMessage:@"复制完成"];
    }]];
    if ([ActionPerformer checkRight] > 1 || [item[@"author"] isEqualToString:UID]) {
        [action addAction:[UIAlertAction actionWithTitle:@"编辑" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            defaultTitle = [item[@"floor"] isEqualToString:@"1"]?self.title:[NSString stringWithFormat:@"Re: %@",self.title];
            isEdit = YES;
            NSString *content = item[@"text"];
            // NSLog(@"%@", content);
            content = [ContentViewController restoreFormat:content];
            content = [ContentViewController transFromHTML:content];
            defaultContent = content;
            [self performSegueWithIdentifier:@"compose" sender:nil];
        }]];
        [action addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            if ([ActionPerformer checkLogin:YES]) {
                NSString *content = item[@"text"];
                content = [self getCollectionText:item[@"text"]];
                if (content.length > 50) {
                    content = [[content substringToIndex:49] stringByAppendingString:@"..."];
                }
                [self showAlertWithTitle:@"警告" message:[NSString stringWithFormat:@"确定要删除该楼层吗？\n删除操作不可逆！\n\n作者：%@\n正文：%@", item[@"author"], content] confirmTitle:@"删除" confirmAction:^(UIAlertAction *action) {
                    [self deletePost];
                }];
            }
        }]];
    }
    [action addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    action.popoverPresentationController.sourceView = view;
    action.popoverPresentationController.sourceRect = view.bounds;
    [self presentViewControllerSafe:action];
}

#pragma mark - HTML processing

+ (NSString *)htmlStringWithText:(NSString *)text sig:(NSString *)sig textSize:(int)textSize {
    NSString *body = @"";
    if (text) {
        body = [NSString stringWithFormat:@"<div class='textblock'>%@</div>", text];
    }
    if (sig && sig.length > 0) {
        body = [NSString stringWithFormat:@"%@<div class='sigblock'>%@"
                "<div class='sig'>%@</div></div>", body, text ? @"<span class='sigtip'>--------</span>" : @"", sig];
    }
    
    if ([[DEFAULTS objectForKey:@"picOnlyInWifi"] boolValue] && IS_CELLULAR) {
        NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"(<img[^>]+?src=['\"])(.+?)(['\"][^>]*>)" options:0 error:nil];
        body = [regexp stringByReplacingMatchesInString:body options:0 range:NSMakeRange(0, body.length) withTemplate:@"<a href='pic:$2'>🚫</a>"];
    }
    
    NSString *jQueryScript = @"";
    if ([body containsString:@"<script"] && [body containsString:@"/script>"]) {
        NSError *error = nil;
        NSString *jQueryContent = [NSString stringWithContentsOfFile:JQUERY_MIN_JS encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            jQueryScript = [NSString stringWithFormat:@"<script>%@</script>", jQueryContent];
        }
    }
    
    NSString *sigBlockStyle = text ? @".sigblock{color:gray;font-size:small;margin-top:1em;}" : @"";
    NSString *bodyBackground = text ? @"rgba(255,255,255,0.75)" : @"transparent";
    
    return [NSString stringWithFormat:@"<html>"
            "<head>"
            "%@"
            "<style type='text/css'>"
            "img{max-width:min(100%%,700px);}"
            "body{word-wrap:break-word;-webkit-overflow-scrolling:touch;-webkit-text-size-adjust:%d%%;}"
            "#body-mask{position:absolute;top:0;bottom:0;left:0;right:0;z-index:-1;background-color:%@;transition:background-color 0.2s linear;}"
            ".textblock,.sig{overflow-x:scroll;}"
            ".textblock{min-height:3em;}"
            "%@"
            ".sig{max-height:400px;overflow-y:scroll;}"
            "</style>"
            "</head>"
            "<body><div id='body-mask'></div><div id='body-wrapper'>%@</div></body>"
            "</html>", jQueryScript, textSize, bodyBackground, sigBlockStyle, body];
}

+ (NSDictionary *)getLink:(NSString *)path {
    NSString *bid = @"", *tid = @"", *p = @"", *floor = @"";
    NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:@"((http://|https://)?/bbs|\\.\\.)(/content(/|/index.php)?\\?)(.+)" options:0 error:nil];
    NSArray *matchs = [regular matchesInString:path options:0 range:NSMakeRange(0, path.length)];
    if (matchs.count != 0) {
        NSTextCheckingResult *result = matchs.firstObject;
        NSString *getstr = [path substringWithRange:[result rangeAtIndex:5]];
        bid = [getstr substringWithRange:[[[NSRegularExpression regularExpressionWithPattern:@"(bid=)([^&]+)" options:0 error:nil] matchesInString:getstr options:0 range:NSMakeRange(0, getstr.length)].firstObject rangeAtIndex:2]];
        tid = [getstr substringWithRange:[[[NSRegularExpression regularExpressionWithPattern:@"(tid=)([^&]+)" options:0 error:nil] matchesInString:getstr options:0 range:NSMakeRange(0, getstr.length)].firstObject rangeAtIndex:2]];
        if (bid.length > 0 && tid.length > 0) {
            p = [getstr substringWithRange:[[[NSRegularExpression regularExpressionWithPattern:@"(p=)([^&]+)" options:0 error:nil] matchesInString:getstr options:0 range:NSMakeRange(0, getstr.length)].firstObject rangeAtIndex:2]];
            floor = [getstr substringWithRange:[[[NSRegularExpression regularExpressionWithPattern:@"(#)([^&]+)" options:0 error:nil] matchesInString:getstr options:0 range:NSMakeRange(0, getstr.length)].firstObject rangeAtIndex:2]];
        }
    }
    
    regular = [NSRegularExpression regularExpressionWithPattern:@"((http://|https://)?/cgi-bin/bbs.pl\\?)(.+)" options:0 error:nil];
    matchs = [regular matchesInString:path options:0 range:NSMakeRange(0, path.length)];
    if (matchs.count != 0) {
        NSTextCheckingResult *result = matchs.firstObject;
        NSString *getstr = [path substringWithRange:[result rangeAtIndex:3]];
        bid = [getstr substringWithRange:[[[NSRegularExpression regularExpressionWithPattern:@"(b=)([^&]+)" options:0 error:nil] matchesInString:getstr options:0 range:NSMakeRange(0, getstr.length)].firstObject rangeAtIndex:2]];
        tid = [getstr substringWithRange:[[[NSRegularExpression regularExpressionWithPattern:@"(see=)([^&]+)" options:0 error:nil] matchesInString:getstr options:0 range:NSMakeRange(0, getstr.length)].firstObject rangeAtIndex:2]];
        NSString *oldbid = [getstr substringWithRange:[[[NSRegularExpression regularExpressionWithPattern:@"(id=)([^&]+)" options:0 error:nil] matchesInString:getstr options:0 range:NSMakeRange(0, getstr.length)].firstObject rangeAtIndex:2]];
        
        NSDictionary *trans = @{@"act": @1, @"capu": @2, @"bike": @3, @"water": @4, @"acad": @5, @"asso": @6, @"skill": @7, @"race": @9, @"web": @28};
        if (oldbid&&oldbid.length != 0) {
            bid = [trans objectForKey:oldbid];
        }
        
        if (![tid isEqualToString:@""]) {
            long count = 0; // 转换26进制tid
            for (int i = 0; i < tid.length; i++) {
                count += ([tid characterAtIndex:tid.length - 1 - i] - 'a') * pow(26, i);
            }
            count++;
            tid = [NSString stringWithFormat:@"%ld", count];
        }
    }
    
    if ([p isEqualToString:@""]) {
        p = @"1";
    }
    return @{
        @"bid" : bid,
        @"tid" : tid,
        @"p" : p,
        @"floor" : floor
    };
}

+ (NSString *)restoreFormat:(NSString *)text { // 恢复正确的格式
    // NSLog(@"%@", text);
    NSArray *oriExp = @[@"(<quote>)(.*?)(<a href=['\"]/bbs/user)(.*?)(>@)(.*?)(</a> ：<br><br>)((.|[\r\n])*?)(<br><br></font></div></quote>)",
                        @"(<a href=['\"]/bbs/user)(.*?)(>@)(.*?)(</a>)",
                        @"(<a href=['\"]#['\"]>)((.|[\r\n])*?)(</a>)", // 修复网页版@格式的错误
                        @"(<a href=['\"])(.+?)(['\"][^>]*>)(.+?)(</a>)",
                        @"(<img src=['\"])(.+?)(['\"][^>]*>)",
                        @"(<b>)(.+?)(</b>)",
                        @"(<i>)(.+?)(</i>)"];
    NSArray *repExp = @[@"[quote=$6]$8[/quote]",
                        @"[at]$4[/at]",
                        @"$2",
                        @"[url=$2]$4[/url]",
                        @"[img]$2[/img]",
                        @"[b]$2[/b]",
                        @"[i]$2[/i]"];
    NSRegularExpression *regExp;
    for (int i = 0; i < oriExp.count; i++) {
        regExp = [NSRegularExpression regularExpressionWithPattern:[oriExp objectAtIndex:i] options:0 error:nil];
        text = [regExp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:[repExp objectAtIndex:i]];
    }
    
    NSRange range = NSMakeRange(0, 0); // 恢复字体
    while (YES) {
        BOOL found = NO;
        for (int i = 0; i < text.length; i++) {
            if (i + 4 < text.length && [[text substringWithRange:NSMakeRange(i, 5)] isEqualToString:@"<font"]) {
                for (int j = i + 4; j < text.length; j++) {
                    if (j + 4 < text.length && [[text substringWithRange:NSMakeRange(j, 5)] isEqualToString:@"<font"]) {
                        i = j;
                    }
                    if (j + 6 < text.length && [[text substringWithRange:NSMakeRange(j, 7)] isEqualToString:@"</font>"]) {
                        range = NSMakeRange(i, j - i + 7);
                        found = YES;
                        break;
                    }
                }
            }
        }
        if (!found) {
            break;
        }
        NSString *subText = [text substringWithRange:range];
        NSString *textHTML = [subText substringWithRange:[subText rangeOfString:@"<font(.*?)>" options:NSRegularExpressionSearch]];
        NSString *textBody = [subText substringWithRange:[subText rangeOfString:@">(.*?)</font>" options:NSRegularExpressionSearch]];
        textBody = [textBody substringWithRange:NSMakeRange(1, textBody.length - 8)];
        NSRange temprange = [textHTML rangeOfString:@"color=['\"](.+?)['\"]" options:NSRegularExpressionSearch];
        if (temprange.location != NSNotFound) {
            NSString *tempText = [subText substringWithRange:temprange];
            tempText = [tempText substringWithRange:NSMakeRange(7, tempText.length - 8)];
            // 下面是常见颜色的还原
            if ([[tempText lowercaseString] isEqualToString:@"#ff0000"]) {
                tempText = @"red";
            }
            if ([[tempText lowercaseString] isEqualToString:@"#00ff00"]) {
                tempText = @"green";
            }
            if ([[tempText lowercaseString] isEqualToString:@"#0000ff"]) {
                tempText = @"blue";
            }
            if ([[tempText lowercaseString] isEqualToString:@"#ffffff"]) {
                tempText = @"white";
            }
            if ([[tempText lowercaseString] isEqualToString:@"#000000"]) {
                tempText = @"black";
            }
            textBody = [NSString stringWithFormat:@"[color=%@]%@[/color]", tempText, textBody];
        }
        temprange = [textHTML rangeOfString:@"size=['\"](.+?)['\"]" options:NSRegularExpressionSearch];
        if (temprange.location != NSNotFound) {
            NSString *tempText = [subText substringWithRange:temprange];
            tempText = [tempText substringWithRange:NSMakeRange(6, tempText.length - 7)];
            textBody = [NSString stringWithFormat:@"[size=%@]%@[/size]", tempText, textBody];
        }
        temprange = [textHTML rangeOfString:@"face=['\"](.+?)['\"]" options:NSRegularExpressionSearch];
        if (temprange.location != NSNotFound) {
            NSString *tempText = [subText substringWithRange:temprange];
            tempText = [tempText substringWithRange:NSMakeRange(6, tempText.length - 7)];
            textBody = [NSString stringWithFormat:@"[font=%@]%@[/font]", tempText, textBody];
        }
        text = [text stringByReplacingCharactersInRange:range withString:textBody];
    }
    
    return text;
}

+ (NSString *)transFromHTML:(NSString *)text {
    int index = 0;
    while (index < text.length) {
        if ([[text substringWithRange:NSMakeRange(index, 1)] isEqualToString:@"<"]) {
            index++;
            while (index < text.length) {
                if ([[text substringWithRange:NSMakeRange(index, 1)] isEqualToString:@">"]) {
                    break;
                }
                // 防止出现嵌套的情况比如 <span style=...<br>...>
                if (index + 3 < text.length && [[text substringWithRange:NSMakeRange(index, 4)] isEqualToString:@"<br>"]) {
                    text = [text stringByReplacingCharactersInRange:NSMakeRange(index, 4) withString:@""];
                }
                if (index + 5 < text.length && [[text substringWithRange:NSMakeRange(index, 6)] isEqualToString:@"<br />"]) {
                    text = [text stringByReplacingCharactersInRange:NSMakeRange(index, 6) withString:@""];
                }
                index++;
            }
        }
        index++;
    }
    
    NSString *expression = @"<br(.*?)>"; // 恢复换行
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:expression options:0 error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"\n"];
    
    NSArray *HTML = @[@"&nbsp;", @"&amp;", @"&apos;", @"&quot;", @"&ldquo;", @"&rdquo;", @"&#39;", @"&mdash;", @"&hellip;"]; // 常见的转义
    NSArray *oriText = @[@" ", @"&", @"'", @"\"", @"“", @"”", @"'",  @"——", @"…"];
    for (int i = 0; i < oriText.count; i++) {
        text = [text stringByReplacingOccurrencesOfString:[HTML objectAtIndex:i] withString:[oriText objectAtIndex:i]];
    }
    // NSLog(@"%@", text);
    return text;
}

+ (NSString *)removeHTML:(NSString *)text {
    text = [self transFromHTML:text];
    
    NSString *expression = @"<!--((.|[\r\n])*?)-->"; // 去除注释
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:expression options:0 error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    
    expression = @"<div(.*?)>(.*?)</div>"; // <div xxx>xxx</div>标签处理为换行
    regexp = [NSRegularExpression regularExpressionWithPattern:expression options:0 error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"$2\n"];
    
    expression = @"<span(.*?)>(.*?)</span>"; // <span xxx>xxx</span>标签处理为换行
    regexp = [NSRegularExpression regularExpressionWithPattern:expression options:0 error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"$2\n"];
    
    expression = @"(<img[^>]+?src=['\"])(.+?)(['\"][^>]*>)"; // 恢复所有图片链接
    regexp = [NSRegularExpression regularExpressionWithPattern:expression options:0 error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"[img]$2[/img]"];
    
    expression = @"<(.*?)>"; // 去除所有HTML标签
    regexp = [NSRegularExpression regularExpressionWithPattern:expression options:0 error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    
    text = [text stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    text = [text stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    // NSLog(@"%@", text);
    return text;
}

- (NSString *)getCollectionText:(NSString *)text{
    text = [[ContentViewController removeHTML:text] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    while ([text hasPrefix:@" "] || [text hasPrefix:@"\t"]) {
        text = [text substringFromIndex:@" ".length];
    }
    return text;
}

- (NSString *)getValidQuote:(NSString *)text {
    text = [ContentViewController transFromHTML:text];
    
    NSString *expression = @"<quote>((.|[\r\n])*?)</quote>"; // 去除帖子中的引用
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:expression options:0 error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    
    int maxLength = 100;
    int maxCountXIndex = 2 * maxLength * maxLength;
    if (text.length <= maxLength) {
        return text;
    }
    
    int index = 0, count = 0;
    NSMutableArray * htmlLabel = [[NSMutableArray alloc] init];
    NSArray *exception = @[@"br", @"br/", @"hr", @"img", @"input", @"isindex", @"area", @"base", @"basefont",@"bgsound", @"col", @"embed", @"frame", @"keygen", @"link",@"meta", @"nextid", @"param", @"plaintext", @"spacer", @"wbr"];
    while (YES) {
        if (index >= text.length) {
            break;
        }
        if (![[text substringWithRange:NSMakeRange(index, 1)] isEqualToString:@"<"]) {
            count++;
            if (count > maxLength || count * index >= maxCountXIndex) {
                // NSLog(@"Quote Count:%d Index:%d", count, index);
                break;
            } else {
                index++;
                continue;
            }
        } else {
            int tempIndex = index + 1;
            BOOL isRemove = NO;
            if ([[text substringWithRange:NSMakeRange(tempIndex, 1)] isEqualToString:@"/"]) {
                isRemove = YES;
                tempIndex++;
            }
            while (YES) {
                if ([[text substringWithRange:NSMakeRange(tempIndex, 1)] isEqualToString:@" "] || [[text substringWithRange:NSMakeRange(tempIndex, 1)] isEqualToString:@">"]) {
                    NSString *label = [text substringWithRange:NSMakeRange(index + 1 + isRemove, tempIndex - index - 1 - isRemove)];
                    bool isBlank = NO;
                    for (NSString *exc in exception) {
                        if ([label isEqualToString:exc]) {
                            isBlank = YES;
                        }
                    }
                    if (!isBlank) {
                        if (isRemove) {
                            for (int i = (int)htmlLabel.count - 1; i >= 0; i--) {
                                if ([[htmlLabel objectAtIndex:i] isEqualToString:label]) {
                                    [htmlLabel removeObjectAtIndex:i];
                                    break;
                                }
                            }
                        } else {
                            [htmlLabel addObject:label];
                        }
                    }
                    break;
                }
                tempIndex++;
            }
            
            while (YES) {
                if ([[text substringWithRange:NSMakeRange(index++, 1)] isEqualToString:@">"]) {
                    break;
                }
            }
        }
    }
    if (index + 1 < text.length) {
        text = [[text substringToIndex:index] stringByAppendingString:@"..."];
    } else {
        text = [text substringToIndex:index];
    }
    if (htmlLabel.count != 0) {
        for (int i = (int)htmlLabel.count - 1; i >= 0; i--) {
            text = [text stringByAppendingString:[NSString stringWithFormat:@"</%@>", [htmlLabel objectAtIndex:i]]];
        }
    }
    //NSLog(@"%@", text);
    return text;
}

- (void)longPressTop:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [sender locationInView:self.tableView];
        NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (indexPath == nil) {
            return;
        }
        selectedIndex = indexPath.row;
        ContentCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self showMoreAction:cell.labelAuthor];
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"compose"]) {
        ComposeViewController *dest = [[[segue destinationViewController] viewControllers] firstObject];
        if (sender != nil) {
            defaultTitle = [NSString stringWithFormat:@"Re: %@",self.title];
        }
        
        dest.tid = self.tid;
        dest.bid = self.bid;
        dest.defaultTitle = defaultTitle;
        dest.defaultContent = defaultContent;
        dest.isEdit = isEdit;
        
        if (isEdit) {
            dest.floor=[NSString stringWithFormat:@"%d",[[data[selectedIndex] objectForKey:@"floor"] intValue]];
        }
        
        defaultTitle = nil;
        defaultContent = nil;
        selectedIndex = -1;
        isEdit = NO;
    } else if ([segue.identifier isEqualToString:@"lzl"]) {
        LzlViewController *dest = [[[segue destinationViewController] viewControllers] firstObject];
        if (sender) {
            UIButton *button = sender;
            selectedIndex = button.tag;
            dest.navigationController.modalPresentationStyle = UIModalPresentationPopover;
            dest.navigationController.popoverPresentationController.sourceView = button;
            dest.navigationController.popoverPresentationController.sourceRect = button.bounds;
        }
        dest.fid = [data[selectedIndex] objectForKey:@"fid"];
        dest.URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@#%@", URL, [data[selectedIndex] objectForKey:@"floor"]]];
    } else if ([segue.identifier isEqualToString:@"userInfo"]) {
        UserViewController *dest = [[[segue destinationViewController] viewControllers] firstObject];
        if ([sender isKindOfClass:[UIButton class]]) {
            UIButton *button = sender;
            dest.ID = [data[button.tag] objectForKey:@"author"];
            dest.navigationController.modalPresentationStyle = UIModalPresentationPopover;
            dest.navigationController.popoverPresentationController.sourceView = button;
            dest.navigationController.popoverPresentationController.sourceRect = button.bounds;
            ContentCell *cell = (ContentCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:button.tag inSection:0]];
            if (![cell.icon.image isEqual:PLACEHOLDER]) {
                dest.iconData = UIImagePNGRepresentation(cell.icon.image);
            }
        } else if ([sender isKindOfClass:[NSString class]]) {
            dest.ID = sender;
        }
    } else if ([segue.identifier isEqualToString:@"web"]) {
        WebViewController *dest = [[[segue destinationViewController] viewControllers] firstObject];
        dest.URL = tempPath;
    }
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

@end

