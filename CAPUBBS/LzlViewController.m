//
//  LzlViewController.m
//  CAPUBBS
//
//  Created by XiongDian on 14/9/21.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "LzlViewController.h"
#import "LzlCell.h"
#import <StoreKit/StoreKit.h>
#import "UserViewController.h"
#import "ContentViewController.h"
#import "WebViewController.h"

@interface LzlViewController ()

@end

@implementation LzlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GRAY_PATTERN;
    self.preferredContentSize = CGSizeMake(400, 0);
    UIView *targetView = self.navigationController ? self.navigationController.view : self.view;
    hud = [[MBProgressHUD alloc] initWithView:targetView];
    [targetView addSubview:hud];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshControlValueChanged:) forControlEvents:UIControlEventValueChanged];
    shouldShowHud = YES;
    [self.tableView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)]];
    [self.buttomCompose setEnabled:[Helper checkLogin:NO]];
    
    if (self.defaultData) {
        data = [self.defaultData mutableCopy];
    }
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!data) {
        [self loadData];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (![[DEFAULTS objectForKey:@"Featurelzl1.3"] boolValue]) {
        [self showAlertWithTitle:@"Tips" message:@"长按某层楼中楼可以快捷回复" cancelTitle:@"我知道了"];
        [DEFAULTS setObject:@(YES) forKey:@"Featurelzl1.3"];
    }
    activity = [[NSUserActivity alloc] initWithActivityType:[BUNDLE_IDENTIFIER stringByAppendingString:@".lzl"]];
    activity.webpageURL = self.URL;
    [activity becomeCurrent];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [activity invalidate];
}

- (void)refreshControlValueChanged:(UIRefreshControl*)sender{
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"刷新"];
    shouldShowHud = YES;
    [self loadData];
}

- (IBAction)back:(id)sender {
    if (self.textPost.text.length == 0) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"确定退出" message:@"您有尚未发表的楼中楼，建议先保存草稿，确定继续退出？" preferredStyle:UIAlertControllerStyleActionSheet];
        [alertController addAction:[UIAlertAction actionWithTitle:@"退出" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        if ([sender isKindOfClass:[UIBarButtonItem class]]) {
            alertController.popoverPresentationController.barButtonItem = sender;
        }
        [self presentViewControllerSafe:alertController];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.textPost) {
        return;
    }
    if (scrollView.dragging) {
        [self.view endEditing:YES];
    }
}

- (void)loadData {
    if (shouldShowHud) {
        [hud showWithProgressMessage:@"读取中"];
    }
    NSDictionary *dict = @{
        @"fid" : self.fid,
        @"method" : @"show"
    };
    [Helper callApiWithParams:dict toURL:@"lzl" callback:^(NSArray *result, NSError *err) {
        if (self.refreshControl.isRefreshing) {
            [self.refreshControl endRefreshing];
        }
        if (err || result.count == 0) {
            if (shouldShowHud) {
                [hud hideWithFailureMessage:@"读取失败"];
            }
            return;
        }
        
        if (shouldShowHud) {
            [hud hideWithSuccessMessage:@"读取成功"];
        }
        shouldShowHud = NO;
        
        data = [result subarrayWithRange:NSMakeRange(1, result.count - 1)];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
        dispatch_global_after(0.5, ^{
            [NOTIFICATION postNotificationName:@"refreshLzl" object:nil userInfo:@{
                @"fid" : self.fid,
                @"details": data,
            }];
        });
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return [Helper checkLogin:NO] ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (section == 0) {
        return data.count;
    } else {
        return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    LzlCell *cell;
    if (indexPath.section == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
        NSDictionary *dict = data[indexPath.row];
        cell.textAuthor.text = dict[@"author"];
        [cell.imageBottom setImage:[[UIImage imageNamed:[dict[@"author"] isEqualToString:UID] ? @"balloon_white" : @"balloon_green"] stretchableImageWithLeftCapWidth:15 topCapHeight:15]];
        cell.textTime.text = dict[@"time"];
        cell.textMain.text = dict[@"text"];
        [cell.icon setUrl:dict[@"icon"]];
        cell.buttonIcon.tag = indexPath.row;
    } else if (indexPath.section == 1) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"post" forIndexPath:indexPath];
        
        self.textPost = cell.textPost;
        [self.textPost setDelegate:self];
        [self textViewDidChange:self.textPost];
        self.labelByte = cell.labelByte;
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if (section == 0) {
        if (!data) {
            return @"正在加载";
        } else if (data.count == 0) {
            return @"暂时没有楼中楼";
        }
        return [NSString stringWithFormat:@"共有%lu条楼中楼",(unsigned long)data.count];
    } else {
        return @"发表楼中楼";
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"选择操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        if ([Helper checkLogin:NO]) {
            [alertController addAction:[UIAlertAction actionWithTitle:@"回复" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self directPost:nil];
            }]];
        }
        [alertController addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIPasteboard generalPasteboard] setString:lzlText];
            [hud showAndHideWithSuccessMessage:@"复制完成"];
        }]];
        if ([self tableView:tableView canEditRowAtIndexPath:indexPath]) {
            [alertController addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [self confirmDelete:indexPath];
            }]];
        }
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        lzlText = data[indexPath.row][@"text"];
        lzlAuthor = data[indexPath.row][@"author"];
        NSString *exp = @"[a-zA-z]+://[^\\s]*"; // 提取网址链接
        NSRange range = [lzlText rangeOfString:exp options:NSRegularExpressionSearch];
        if (range.location != NSNotFound) {
            lzlUrl = [lzlText substringWithRange:range];
            [alertController addAction:[UIAlertAction actionWithTitle:@"打开链接" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSDictionary *dict = [Helper getLink:lzlUrl];
                if (dict.count > 0 && [dict[@"tid"] length] > 0) {
                    ContentViewController *dest = [self.storyboard instantiateViewControllerWithIdentifier:@"content"];
                    dest.bid = dict[@"bid"];
                    dest.tid = dict[@"tid"];
                    dest.destinationPage = dict[@"p"];
                    dest.title=@"帖子跳转中";
                    dest.navigationItem.leftBarButtonItem = [AppDelegate getCloseButtonForTarget:self action:@selector(done)];
                    CustomNavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
                    [navi setToolbarHidden:NO];
                    navi.modalPresentationStyle = UIModalPresentationFullScreen;
                    [self presentViewControllerSafe:navi];
                } else {
                    WebViewController *dest = [self.storyboard instantiateViewControllerWithIdentifier:@"webview"];
                    CustomNavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
                    dest.URL = lzlUrl;
                    [navi setToolbarHidden:NO];
                    navi.modalPresentationStyle = UIModalPresentationFullScreen;
                    [self presentViewControllerSafe:navi];
                }
            }]];
        }
        LzlCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        UIView *view = cell.imageBottom;
        alertController.popoverPresentationController.sourceView = view;
        alertController.popoverPresentationController.sourceRect = view.bounds;
        [self presentViewControllerSafe:alertController];
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    if (indexPath.section == 0) {
        if ([Helper checkRight] > 1 || [data[indexPath.row][@"author"] isEqualToString:UID]) {
            return YES;
        }
    }
    return NO;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self confirmDelete:indexPath];
    }
}

- (void)confirmDelete:(NSIndexPath *)indexPath {
    NSDictionary *info = data[indexPath.row];
    [self showAlertWithTitle:@"警告" message:[NSString stringWithFormat:@"确定要删除该楼中楼吗？\n删除操作不可逆！\n\n作者：%@\n正文：%@", info[@"author"], info[@"text"]] confirmTitle:@"删除" confirmAction:^(UIAlertAction *action) {
        [hud showWithProgressMessage:@"正在删除"];
        
        NSDictionary *dict = @{
            @"method" : @"delete",
            @"fid" : self.fid,
            @"id" : info[@"id"]
        };
        [Helper callApiWithParams:dict toURL:@"lzl" callback:^(NSArray *result, NSError *err) {
            if (err || result.count == 0) {
                [hud hideWithFailureMessage:@"删除失败"];
                return;
            }
            if ([result[0][@"code"] integerValue]==0) {
                [hud hideWithSuccessMessage:@"删除成功"];
                NSMutableArray *temp = [NSMutableArray arrayWithArray:data];
                [temp removeObjectAtIndex:indexPath.row];
                data = [NSArray arrayWithArray:temp];
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                dispatch_global_after(0.5, ^{
                    [self loadData];
                });
            } else {
                [hud hideWithFailureMessage:@"删除失败"];
                [self showAlertWithTitle:@"删除失败" message:result[0][@"msg"]];
            }
        }];
    }];
}

- (IBAction)buttonPost:(id)sender {
    if (self.textPost.text.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"楼中楼内容为空！" cancelAction:^(UIAlertAction *action) {
            [self.textPost becomeFirstResponder];
        }];
        return;
    }
    if (self.textPost.text.length > 140) {
        [self showAlertWithTitle:@"错误" message:@"楼中楼内容太长！" cancelAction:^(UIAlertAction *action) {
            [self.textPost becomeFirstResponder];
        }];
        return;
    }
    
    [hud showWithProgressMessage:@"正在发布"];
    
    NSDictionary *dict = @{
        @"method" : @"post",
        @"fid" : self.fid,
        @"text" : self.textPost.text
    };
    [Helper callApiWithParams:dict toURL:@"lzl" callback:^(NSArray *result, NSError *err) {
        if (err || result.count == 0) {
            [hud hideWithFailureMessage:@"发布失败"];
            return;
        }
            if ([result[0][@"code"] integerValue]==0) {
                [hud hideWithSuccessMessage:@"发布成功"];
                [SKStoreReviewController requestReview];
                self.textPost.text = @"";
                dispatch_global_after(0.5, ^{
                    [self loadData];
                });
            } else {
                [hud hideWithFailureMessage:@"发布失败"];
                [self showAlertWithTitle:@"发布失败" message:result[0][@"msg"]];
            }
    }];
}

- (IBAction)directPost:(id)sender {
    if (![Helper checkLogin:YES]) {
        return;
    }
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    if (sender == nil) {
        [self.textPost insertText:[NSString stringWithFormat:@"回复 @%@: ", lzlAuthor]];
    }
    dispatch_main_async_safe(^{
        [self.textPost becomeFirstResponder];
    })
}

- (void)textViewDidChange:(UITextView *)textView {
    int length = (int)textView.text.length;
    self.labelByte.text = [NSString stringWithFormat:@"%d/140", length];
    if (length <= 120) {
        [self.labelByte setTextColor:[UIColor darkGrayColor]];
    } else if (length <= 140) {
        [self.labelByte setTextColor:[UIColor orangeColor]];
    } else {
        [self.labelByte setTextColor:[UIColor redColor]];
    }
    // 如果有输入文字，不允许点击外部关闭
    if (@available(iOS 13.0, *)) {
        [self setModalInPresentation:length > 0];
    }
}

- (void)longPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [sender locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
        if (indexPath == nil || indexPath.section == 1) {
            return;
        }
        if (![Helper checkLogin:NO]) {
            return;
        }
        lzlAuthor = data[indexPath.row][@"author"];
        [self directPost:nil];
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    if ([segue.identifier isEqualToString:@"userInfo"]) {
        UserViewController *dest = [segue destinationViewController];
        UIButton *button = sender;
        dest.ID = data[button.tag][@"author"];
        dest.navigationItem.leftBarButtonItems = nil;
        LzlCell *cell = (LzlCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForItem:button.tag inSection:0]];
        if (![cell.icon.image isEqual:PLACEHOLDER]) {
            dest.iconData = UIImagePNGRepresentation(cell.icon.image);
        }
    }
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
