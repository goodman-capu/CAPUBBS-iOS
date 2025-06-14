//
//  AppDelegate.m
//  CAPUBBS
//
//  Created by 熊典 on 14-2-16.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "AppDelegate.h"
#import "AsyncImageView.h"
#import "LoginViewController.h"
#import "ContentViewController.h"
#import "ListViewController.h"
#import "CollectionViewController.h"
#import "MessageViewController.h"
#import "ComposeViewController.h"
#import <CoreSpotlight/CoreSpotlight.h>

@interface PreviewItemWithName : NSObject <QLPreviewItem>

@property (nonatomic, strong) NSURL *previewItemURL;
@property (nonatomic, strong) NSString *previewItemTitle;

@end

@implementation PreviewItemWithName
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground]; // solid background (no transparency)
        appearance.backgroundColor = GREEN_DARK;
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
        appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
        
        UINavigationBar *navBarAppearance = [UINavigationBar appearance];
        navBarAppearance.standardAppearance = appearance;
        navBarAppearance.scrollEdgeAppearance = appearance;
        navBarAppearance.compactAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            navBarAppearance.compactScrollEdgeAppearance = appearance;
        }
        navBarAppearance.tintColor = [UIColor whiteColor]; // buttons color
    } else {
        [[UINavigationBar appearance] setBarTintColor:GREEN_DARK];
        [[UINavigationBar appearance] setBarStyle:UIBarStyleBlack];
        [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
        [[UINavigationBar appearance] setTranslucent:NO];
    }
    
    if (@available(iOS 13.0, *)) {
        UIToolbarAppearance *appearance = [[UIToolbarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor whiteColor];
        
        UIToolbar *toolbarAppearance = [UIToolbar appearance];
        toolbarAppearance.tintColor = BLUE;
        toolbarAppearance.standardAppearance = appearance;
        toolbarAppearance.compactAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            toolbarAppearance.scrollEdgeAppearance = appearance;
            toolbarAppearance.compactScrollEdgeAppearance = appearance;
        }
    } else {
        [[UIToolbar appearance] setTintColor:BLUE];
        [[UIToolbar appearance] setTranslucent:NO];
    }
    
    
    [[UITextField appearance] setClearButtonMode:UITextFieldViewModeWhileEditing];
    [[UITextField appearance] setBackgroundColor:[UIColor lightTextColor]];
    [[UITextView appearance] setBackgroundColor:[UIColor lightTextColor]];
    [[UISegmentedControl appearance] setTintColor:BLUE];
    [[UIStepper appearance] setTintColor:BLUE];
    [[UISwitch appearance] setOnTintColor:BLUE];
    [[UISwitch appearance] setTintColor:[UIColor whiteColor]];
    [[UITableViewCell appearance] setBackgroundColor:[UIColor clearColor]];
    
    NSDictionary *dict = @{
        // @"proxy" : @2,
        @"autoLogin" : @YES,
        @"enterLogin" : @YES,
        @"wakeLogin" : @NO,
        @"vibrate" : @YES,
        @"picOnlyInWifi" : @NO,
        @"autoSave" : @YES,
        @"oppositeSwipe" : @YES,
        @"toolbarEditor" : @1,
        @"viewCollectionType" : @1,
        @"textSize" : @100,
        @"IDNum" : @(MAX_ID_NUM / 2),
        @"hotNum" : @(MAX_HOT_NUM / 2),
        @"checkUpdate" : @"2025-01-01",
        @"checkPass" : @"2025-01-01"
    };
    NSDictionary *group = @{
        @"URL" : DEFAULT_SERVER_URL,
        @"token" : @"",
        @"userInfo" : @"",
        @"iconOnlyInWifi" : @NO,
        @"simpleView" : @NO
    };
    [DEFAULTS registerDefaults:dict];
    [DEFAULTS removeObjectForKey:@"enterLogin"];
    [DEFAULTS removeObjectForKey:@"wakeLogin"];
    [GROUP_DEFAULTS registerDefaults:group];
    [self transferDefaults];
    
    [[NSURLCache sharedURLCache] setMemoryCapacity:128.0 * 1024 * 1024];
    [[NSURLCache sharedURLCache] setDiskCapacity:512.0 * 1024 * 1024];
    dispatch_global_default_async(^{
        [self transport];
    });
    performer = [[ActionPerformer alloc] init];
    [NOTIFICATION addObserver:self selector:@selector(showAlert:) name:@"showAlert" object:nil];
    [NOTIFICATION addObserver:self selector:@selector(collectionChanged) name:@"collectionChanged" object:nil];
    [NOTIFICATION addObserver:self selector:@selector(sendEmail:) name:@"sendEmail" object:nil];
    [NOTIFICATION addObserver:self selector:@selector(previewFile:) name:@"previewFile" object:nil];
    if ([ActionPerformer checkLogin:NO] && [[DEFAULTS objectForKey:@"autoLogin"] boolValue] == YES) {
        [self loginAsync:YES];
    }
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [[ReachabilityManager sharedManager] stopMonitoring];
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"Become Active");
    // 返回后自动登录
    // 条件为 已登录 或 不是第一次打开软件且开启了自动登录
    if (([ActionPerformer checkLogin:NO] || [[DEFAULTS objectForKey:@"autoLogin"] boolValue] == YES) && [[DEFAULTS objectForKey:@"wakeLogin"] boolValue] == YES) {
        [self loginAsync:YES];
    }
    [DEFAULTS setObject:@(YES) forKey:@"wakeLogin"];
    [[ReachabilityManager sharedManager] startMonitoring];
    [self maybeCheckUpdate];
    
    static dispatch_once_t addTapListenerToken;
    dispatch_once(&addTapListenerToken, ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UITapGestureRecognizer *globalTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGlobalTap:)];
        globalTapGesture.cancelsTouchesInView = NO;
        [keyWindow addGestureRecognizer:globalTapGesture];
    });
    
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)transferDefaults {
    NSUserDefaults *appGroup = GROUP_DEFAULTS;
    if ([[appGroup objectForKey:@"activated"] boolValue] == NO) {
        for (NSString *key in @[@"URL", @"uid", @"pass", @"token", @"userInfo", @"iconOnlyInWifi", @"simpleView"]) {
            id obj = [DEFAULTS objectForKey:key];
            if (obj) {
                [appGroup setObject:obj forKey:key];
                [DEFAULTS removeObjectForKey:key];
            }
        }
        [appGroup setObject:@(YES) forKey:@"activated"];
        [appGroup synchronize];
    }
}

+ (UIViewController *)getTopViewController {
    __block UIViewController *topVC;
    dispatch_main_sync_safe(^{
        topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topVC.presentedViewController && !topVC.presentedViewController.isBeingDismissed) {
            topVC = topVC.presentedViewController;
        }
    });
    return topVC;
}

- (void)showAlert:(NSNotification *)noti {
    NSDictionary *dict = noti.userInfo;
    [[AppDelegate getTopViewController] showAlertWithTitle:dict[@"title"] message:dict[@"message"] cancelTitle:dict[@"cancelTitle"] ? : @"好"];
}

- (void)sendEmail:(NSNotification *)notification {
    NSDictionary *mailInfo = notification.userInfo;
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mail = [[CustomMailComposeViewController alloc] init];
        mail.mailComposeDelegate = self;
        mail.navigationBar.barStyle = UIBarStyleBlackTranslucent;
        mail.navigationBar.barTintColor = [UIColor whiteColor];
        [mail setToRecipients:mailInfo[@"recipients"]];
        if (mailInfo[@"subject"]) {
            [mail setSubject:mailInfo[@"subject"]];
        }
        if (mailInfo[@"body"]) {
            BOOL isHTML = mailInfo[@"isHTML"] ? [mailInfo[@"isHTML"] boolValue] : NO;
            [mail setMessageBody:mailInfo[@"body"] isHTML:isHTML];
        }
        [[AppDelegate getTopViewController] presentViewControllerSafe:mail];
    } else {
        [[AppDelegate getTopViewController] showAlertWithTitle:@"您的设备无法发送邮件" message:mailInfo[@"fallbackMessage"] ?: @"请查看系统设置"];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)previewFile:(NSNotification *)noti {
    NSDictionary *dict = noti.userInfo;
    previewFilePath = dict[@"filePath"];
    previewFileName = dict[@"fileName"];
    if (noti.object && [noti.object isKindOfClass:[UIView class]]) {
        previewFrame = noti.object;
    }
    
    dispatch_main_sync_safe(^{
        QLPreviewController *previewController = [[QLPreviewController alloc] init];
        previewController.dataSource = self;
        previewController.delegate = self;
        [[AppDelegate getTopViewController] presentViewControllerSafe:previewController];
    });
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return previewFilePath ? 1 : 0;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    PreviewItemWithName *item = [[PreviewItemWithName alloc] init];
    item.previewItemURL = [NSURL fileURLWithPath:previewFilePath];
    item.previewItemTitle = previewFileName;
    return item;
}

- (void)previewControllerWillDismiss:(QLPreviewController *)controller {
    if (previewFilePath) {
        [MANAGER removeItemAtPath:previewFilePath error:nil];
        previewFilePath = nil;
        previewFileName = nil;
        previewFrame = nil;
    }
}

- (UIImage *)previewController:(QLPreviewController *)controller
 transitionImageForPreviewItem:(id<QLPreviewItem>)item
                   contentRect:(CGRect *)contentRect {
    if (!previewFrame) {
        *contentRect = CGRectZero;
        return nil;
    }
    *contentRect = previewFrame.bounds;
    return [UIImage imageWithContentsOfFile:previewFilePath];
}

- (CGRect)previewController:(QLPreviewController *)controller frameForPreviewItem:(id<QLPreviewItem>)item inSourceView:(UIView * _Nullable * _Nonnull)view {
    if (!previewFrame) {
        *view = nil;
        return CGRectZero;
    }
    *view = previewFrame;
    return previewFrame.bounds;
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    NSArray *collectionParts = @[];
    if ([userActivity.activityType isEqualToString:CSSearchableItemActionType]) {
        NSString *identifier = userActivity.userInfo[CSSearchableItemActivityIdentifier];
        if (identifier.length > 0) {
            collectionParts = [identifier componentsSeparatedByString:@"\n"];
        }
    }
    NSDictionary *linkInfo;
    if (userActivity.webpageURL && userActivity.webpageURL.absoluteString.length > 0) {
        linkInfo = [ActionPerformer getLink:userActivity.webpageURL.absoluteString];
    }
    
    BOOL continueFronCollectionSearch = (collectionParts.count > 0 && [collectionParts[0] isEqualToString:@"collection"]);
    BOOL continueFromHandoffOrWebpage = (linkInfo.count > 0 && ![linkInfo[@"tid"] isEqualToString:@""]);
    if (continueFronCollectionSearch || continueFromHandoffOrWebpage) {
        dispatch_global_default_async(^{
            NSMutableDictionary *naviDict = [NSMutableDictionary dictionaryWithDictionary:@{@"open": @"post"}];
            if (continueFronCollectionSearch) {
                naviDict[@"bid"] = collectionParts[1];
                naviDict[@"tid"] = collectionParts[2];
                naviDict[@"naviTitle"] = collectionParts[3];
            } else if (continueFromHandoffOrWebpage) {
                naviDict[@"bid"] = linkInfo[@"bid"];
                naviDict[@"tid"] = linkInfo[@"tid"];
                naviDict[@"page"] = linkInfo[@"p"];
                naviDict[@"floor"] = linkInfo[@"floor"];
                naviDict[@"naviTitle"] = userActivity.title;
            }
            [self _handleUrlRequestWithDictionary:naviDict];
        });
    }
    
    NSDictionary *activityInfo = userActivity.userInfo;
    if ([activityInfo[@"type"] isEqualToString:@"compose"]) {
        dispatch_global_default_async(^{
            if (userActivity.webpageURL.absoluteString.length == 0 && [activityInfo[@"bid"] length] > 0) {
                NSMutableDictionary *listDict = [NSMutableDictionary dictionaryWithDictionary:@{@"open": @"list"}];
                listDict[@"bid"] = activityInfo[@"bid"];
                [self _handleUrlRequestWithDictionary:listDict];
            }
            
            NSMutableDictionary *naviDict = [NSMutableDictionary dictionaryWithDictionary:@{@"open": @"compose"}];
            [naviDict addEntriesFromDictionary:activityInfo];
            naviDict[@"naviTitle"] = userActivity.title;
            [self _handleUrlRequestWithDictionary:naviDict];
        });
    }
    
    return YES;
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    dispatch_global_default_async(^{
        if ([shortcutItem.type isEqualToString:@"Hot"]) {
            [self _handleUrlRequestWithDictionary:@{@"open": @"hot"}];
        } else if ([shortcutItem.type isEqualToString:@"Collection"]) {
            [self _handleUrlRequestWithDictionary:@{@"open": @"collection"}];
        } else if ([shortcutItem.type isEqualToString:@"Message"]) {
            [self _handleUrlRequestWithDictionary:@{@"open": @"message"}];
        } else if ([shortcutItem.type isEqualToString:@"Compose"]) {
            [self _handleUrlRequestWithDictionary:@{@"open": @"compose"}];
        }
    });
    completionHandler(YES);
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if (url.isFileURL) {
        BOOL secured = [url startAccessingSecurityScopedResource];
        if (!secured) {
            NSLog(@"Handle file error - unable to start access");
            return NO;
        }
        NSError *error = nil;
        NSData *jsonData = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&error];
        if (error) {
            NSLog(@"Handle file error - %@", error);
            [url stopAccessingSecurityScopedResource];
            return NO;
        }
        
        NSArray *importData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (error) {
            NSLog(@"Handle file error - wrong json format");
            [url stopAccessingSecurityScopedResource];
            return NO;
        }
        
        BOOL hasValidCollection = NO;
        if ([importData isKindOfClass:[NSArray class]]) {
            for (id item in importData) {
                if ([item isKindOfClass:[NSDictionary class]] && item[@"type"] && item[@"data"] && item[@"sig"] && [[ActionPerformer getSigForData:item[@"data"]] isEqualToString:item[@"sig"]]) {
                    if (!hasValidCollection && [item[@"type"] isEqualToString:@"capubbs_collection"] && [item[@"data"] isKindOfClass:[NSArray class]]) {
                        hasValidCollection = YES;
                        [self _handleImportCollectionData:item[@"data"]];
                    }
                }
            }
        }
        if (!hasValidCollection) {
            [[AppDelegate getTopViewController] showAlertWithTitle:@"提示" message:@"您打开了一个JSON文件，但里面不包含有效的导入内容"];
        }
        return hasValidCollection;
    }
    
    if (![url.scheme isEqualToString:@"capubbs"]) {
        return NO;
    }
    
    NSString *urlString = [url absoluteString];
    urlString = [urlString substringFromIndex:[@"capubbs://" length]];
    NSArray *paramsArray = [urlString componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    for (NSString *param in paramsArray) {
        if (param.length == 0) {
            NSLog(@"Handle Url error - wrong parameter");
            return NO;
        }
        NSArray *tempArray = [param componentsSeparatedByString:@"="];
        if (tempArray.count != 2) {
            NSLog(@"Handle Url error - wrong parameter");
            return NO;
        }
        [params addEntriesFromDictionary:@{tempArray[0]: [tempArray[1] stringByRemovingPercentEncoding]}];
    }
    if (params.allKeys.count > 0) {
        dispatch_global_default_async(^{
            [self _handleUrlRequestWithDictionary:params];
        });
    }
    return YES;
}

- (void)_handleImportCollectionData:(NSArray *)data {
    [[AppDelegate getTopViewController] showAlertWithTitle:[NSString stringWithFormat:@"发现%ld项收藏", data.count] message:@"是否导入？\n导入时会自动排除重复项。" confirmTitle:@"导入" confirmAction:^(UIAlertAction *action) {
        dispatch_global_default_async(^{
            int successCount = 0;
            int duplicateCount = 0;
            int failCount = 0;
            NSMutableArray *collections = [[DEFAULTS objectForKey:@"collection"] mutableCopy];
            for (id newItem in data) {
                if (![newItem isKindOfClass:[NSDictionary class]]) {
                    failCount++;
                    continue;
                }
                
                NSString *bid = newItem[@"bid"];
                NSString *tid = newItem[@"tid"];
                NSString *collectionTime = newItem[@"collectionTime"];
                NSString *title = newItem[@"title"];
                if (!bid.length || !tid.length || !collectionTime.length || !title.length) {
                    failCount++;
                    continue;
                }
                
                BOOL hasDuplicate = NO;
                for (NSDictionary *myItem in collections) {
                    if ([myItem[@"bid"] isEqualToString:bid] && [myItem[@"tid"] isEqualToString:tid]) {
                        hasDuplicate = YES;
                        break;
                    }
                }
                if (hasDuplicate) {
                    duplicateCount++;
                } else {
                    successCount++;
                    [collections addObject:newItem];
                }
            }
            if (successCount > 0) {
                [DEFAULTS setObject:collections forKey:@"collection"];
                [NOTIFICATION postNotificationName:@"collectionChanged" object:nil];
            }
            [[AppDelegate getTopViewController] showAlertWithTitle:@"导入结束" message:[NSString stringWithFormat:@"成功：%d\n重复：%d\n失败：%d", successCount, duplicateCount, failCount]];
        });
    }];
}

- (void)_handleUrlRequestWithDictionary:(NSDictionary *)dict {
    NSString *open = dict[@"open"];
    if (open.length == 0) {
        return;
    }
    UIViewController *view = [AppDelegate getTopViewController];
    if ([open isEqualToString:@"message"]) {
        // 同步登陆
        [self loginAsync:NO];
        [DEFAULTS setObject:@(NO) forKey:@"wakeLogin"];
        
        dispatch_main_sync_safe(^{
            MessageViewController *dest = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"message"];
            
            dest.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(back)];
            UINavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
            navi.modalPresentationStyle = UIModalPresentationFullScreen;
            navi.toolbarHidden = NO;
            [view presentViewControllerSafe:navi];
        });
    } else if ([open isEqualToString:@"hot"]) {
        dispatch_main_sync_safe(^{
            ListViewController *dest = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"list"];
            dest.bid = @"hot";
            
            dest.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(back)];
            UINavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
            navi.modalPresentationStyle = UIModalPresentationFullScreen;
            navi.toolbarHidden = NO;
            [view presentViewControllerSafe:navi];
        });
    } else if ([open isEqualToString:@"collection"]) {
        dispatch_main_sync_safe(^{
            CollectionViewController *dest = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"collection"];
            
            dest.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(back)];
            UINavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
            navi.modalPresentationStyle = UIModalPresentationFullScreen;
            [view presentViewControllerSafe:navi];
        });
    } else if ([open isEqualToString:@"compose"]) {
        dispatch_main_sync_safe(^{
            ComposeViewController *dest = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"compose"];
            
            if (dict[@"bid"] && dict[@"pid"]) {
                dest.bid = dict[@"bid"];
                dest.tid = dict[@"tid"];
                dest.floor = dict[@"floor"];
                dest.defaultTitle = dict[@"title"];
                dest.defaultContent = dict[@"content"];
                dest.title = dict[@"naviTitle"];
            }
            
            UINavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
            navi.modalPresentationStyle = UIModalPresentationFormSheet;
            [view presentViewControllerSafe:navi];
        });
    } else if ([open isEqualToString:@"list"]) {
        dispatch_main_sync_safe(^{
            ListViewController *dest = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"list"];
            dest.bid = dict[@"bid"];
            
            dest.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(back)];
            UINavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
            navi.modalPresentationStyle = UIModalPresentationFullScreen;
            navi.toolbarHidden = NO;
            [view presentViewControllerSafe:navi];
        });
    } else if ([open isEqualToString:@"post"]) {
        // 同步登陆
        [self loginAsync:NO];
        [DEFAULTS setObject:@(NO) forKey:@"wakeLogin"];
        
        dispatch_main_sync_safe(^{
            ContentViewController *dest = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"content"];
            
            dest.bid = dict[@"bid"];
            dest.tid = dict[@"tid"];
            if (dict[@"page"]) {
                dest.floor = [NSString stringWithFormat:@"%d", [dict[@"page"] intValue] * 12];
            }
            if (dict[@"floor"]) {
                dest.destinationFloor = dict[@"floor"];
                // dest.openDestinationLzl = YES; // Do we need it? not tested yet
            }
            if (dict[@"naviTitle"]) {
                dest.title = dict[@"naviTitle"];
            } else {
                dest.title = @"加载中";
            }
            
            dest.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(back)];
            UINavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
            navi.modalPresentationStyle = UIModalPresentationFullScreen;
            [view presentViewControllerSafe:navi];
        });
    }
    NSLog(@"Open with %@", open);
}

- (void)back {
    [[AppDelegate getTopViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)collectionChanged { // 后台更新系统搜索内容
    dispatch_global_default_async(^{
        [self updateCollection];
    });
}

- (void)updateCollection {
    NSMutableArray *seachableItems = [[NSMutableArray alloc] init];
    NSArray *array = [DEFAULTS objectForKey:@"collection"];
    for (NSDictionary *dict in array) {
        NSString *bid = dict[@"bid"];
        NSString *tid = dict[@"tid"];
        NSString *title = dict[@"title"];
        NSString *author = dict[@"author"];
        NSString *text = dict[@"text"];
        CSSearchableItemAttributeSet *attr = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"views"];
        attr.title = title;
        // 切割text长度 防止太长导致内容丢失
        if (text.length > 6000) {
            text = [text substringToIndex:6000];
        }
        if (author.length > 0 && text.length > 0) {
            attr.contentDescription = [NSString stringWithFormat:@"%@ - %@", author, text];
        }
        attr.thumbnailData = UIImagePNGRepresentation([UIImage imageNamed:[NSString stringWithFormat:@"b%@", bid]]);
        attr.keywords = @[@"CAPUBBS", @"收藏"];
        CSSearchableItem *item = [[CSSearchableItem alloc] initWithUniqueIdentifier:[NSString stringWithFormat:@"collection\n%@\n%@\n%@", bid, tid, title] domainIdentifier:BUNDLE_IDENTIFIER attributeSet:attr];
        [seachableItems addObject:item];
    }
    [[CSSearchableIndex defaultSearchableIndex] deleteSearchableItemsWithDomainIdentifiers:@[BUNDLE_IDENTIFIER] completionHandler:^(NSError * __nullable error) {
        if (error) {
            NSLog(@"%@", error);
        }
        [[CSSearchableIndex defaultSearchableIndex] indexSearchableItems:seachableItems completionHandler:^(NSError * __nullable error) {
            if (error) {
                NSLog(@"%@", error);
            } else {
                NSLog(@"Collection Saved");
            }
        }];
    }];
}

- (void)transport {
    if ([[DEFAULTS objectForKey:@"clearDirtyData3.2"] boolValue] == NO) { // 3.2之前版本采用NSUserDefaults储存头像 文件夹里面有许多垃圾数据
        NSString *rootFolder = NSHomeDirectory();
        NSArray *childPaths = [MANAGER subpathsAtPath:rootFolder];
        for (NSString *path in childPaths) {
            NSString *childPath = [NSString stringWithFormat:@"%@/%@", rootFolder, path];
            NSArray *testPaths = [MANAGER subpathsAtPath:childPath];
            if ([childPath containsString:@"CAPUBBS.plist"] && ![childPath hasSuffix:@".plist"] && testPaths.count == 0) {
                [MANAGER removeItemAtPath:childPath error:nil];
            }
        }
        
        // 转移头像缓存
        [AsyncImageView checkPath];
        NSDictionary *cache = [DEFAULTS objectForKey:@"iconCache"];
        for (NSString *key in cache) {
            [MANAGER createFileAtPath:[NSString stringWithFormat:@"%@/%@", CACHE_PATH, [ActionPerformer md5:key]] contents:[cache objectForKey:key] attributes:nil];
        }
        
        // 清除旧缓存
        [DEFAULTS removeObjectForKey:@"iconCache"];
        [DEFAULTS removeObjectForKey:@"iconSize"];
        [DEFAULTS setObject:@(YES) forKey:@"clearDirtyData3.2"];
    }
    
    if ([[DEFAULTS objectForKey:@"transportID3.3"] boolValue] == NO) { // 3.3之后版本ID储存采用一个Dictionary
        NSMutableArray *IDs = [[NSMutableArray alloc] init];
        for (int i = 0; i < MAX_ID_NUM; i++) {
            NSString *uid = [DEFAULTS objectForKey:[NSString stringWithFormat:@"id%d", i]];
            if (uid.length > 0) {
                [IDs addObject:@{
                    @"id" : uid,
                    @"pass" : [DEFAULTS objectForKey:[NSString stringWithFormat:@"password%d", i]]
                }];
                [DEFAULTS removeObjectForKey:[NSString stringWithFormat:@"id%d", i]];
                [DEFAULTS removeObjectForKey:[NSString stringWithFormat:@"password%d", i]];
            }
        }
        [DEFAULTS setObject:IDs forKey:@"ID"];
        [DEFAULTS setObject:@(YES) forKey:@"transportID3.3"];
    }
    
    if ([[DEFAULTS objectForKey:@"clearIconCache3.5"] boolValue] == NO) { // 3.5之后链接全更改为https 缓存失效
        [MANAGER removeItemAtPath:CACHE_PATH error:nil];
        [DEFAULTS setObject:@(YES) forKey:@"clearIconCache3.5"];
    }
}

- (void)handleGlobalTap:(UITapGestureRecognizer *)gesture {
    [NOTIFICATION postNotificationName:@"globalTap" object:nil];
}

- (void)loginAsync:(BOOL)async {
    NSString *uid = UID;
    if (uid.length > 0) {
        NSDictionary *dict = @{
            @"username" : uid,
            @"password" : [ActionPerformer md5:PASS],
        };
        dispatch_semaphore_t signal = dispatch_semaphore_create(0);
        [performer performActionWithDictionary:dict toURL:@"login" withBlock:^(NSArray *result,NSError *err) {
            if (err || result.count == 0 || ![[[result objectAtIndex:0] objectForKey:@"code"] isEqualToString:@"0"]) {
                [GROUP_DEFAULTS removeObjectForKey:@"token"];
                [[AppDelegate getTopViewController] showAlertWithTitle:@"警告" message:@"后台登录失败,您现在处于未登录状态，请检查原因！"];
            } else {
                [GROUP_DEFAULTS setObject:[[result objectAtIndex:0] objectForKey:@"token"] forKey:@"token"];
                NSLog(@"Login Completed - %@ Async:%@", uid, async ? @"YES" : @"NO");
            }
            dispatch_semaphore_signal(signal);
            [NOTIFICATION postNotificationName:@"userChanged" object:nil userInfo:nil];
        }];
        if (!async) {
            dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
        }
    }
}

- (void)maybeCheckUpdate {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    NSTimeZone *beijingTimeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    [formatter setTimeZone:beijingTimeZone];
    NSDate *currentDate = [NSDate date];
    NSDate *lastDate =[formatter dateFromString:[DEFAULTS objectForKey:@"checkUpdate"]];
    NSTimeInterval time = [currentDate timeIntervalSinceDate:lastDate];
    if (time > 3600 * 24) { // 每隔1天检测一次更新
        NSLog(@"Check For Update");
        dispatch_global_default_async(^{
            [self checkUpdate:^(BOOL success) {
                if (!success) {
                    // 如果7天没成功检查更新，提示失败
                    if (time > 7 * 3600 * 24) {
                        [[AppDelegate getTopViewController] showAlertWithTitle:@"警告" message:@"向App Store检查更新失败，请检查您的网络连接！"];
                        [DEFAULTS setObject:[formatter stringFromDate:currentDate] forKey:@"checkUpdate"];
                    }
                } else {
                    [DEFAULTS setObject:[formatter stringFromDate:currentDate] forKey:@"checkUpdate"];
                }
            }];
        });
    } else {
        NSLog(@"Needn't Check Update");
    }
}

- (void)checkUpdate:(void (^)(BOOL success))callback {
    NSString *currentVersion = APP_VERSION;
//    currentVersion = @"3.9.5";
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:@"https://itunes.apple.com/lookup?id=826386033"]];
    [request setHTTPMethod:@"POST"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
                                  dataTaskWithRequest:request
                                  completionHandler:^(NSData * _Nullable data,
                                                      NSURLResponse * _Nullable response,
                                                      NSError * _Nullable error) {
        
        if (error || !data) {
            NSLog(@"Check Update Failed: %@", error);
            callback(NO);
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!json || jsonError) {
            NSLog(@"JSON Parse Error: %@", jsonError);
            callback(NO);
            return;
        }
        
        NSArray *infoArray = json[@"results"];
        if (infoArray.count == 0) {
            NSLog(@"No app info returned from App Store.");
            callback(NO);
            return;
        }
        
        callback(YES);
        NSDictionary *releaseInfo = [infoArray objectAtIndex:0];
        NSString *latestVersion = [releaseInfo objectForKey:@"version"];
//        latestVersion = @"3.9.6";
        NSLog(@"App Store latest version: %@", latestVersion);
        if ([currentVersion compare:latestVersion options:NSNumericSearch] == NSOrderedAscending) {
            NSString *newVerURL = [releaseInfo objectForKey:@"trackViewUrl"];
            [[AppDelegate getTopViewController] showAlertWithTitle:[NSString stringWithFormat:@"发现新版本%@", latestVersion] message:[releaseInfo objectForKey:@"releaseNotes"] confirmTitle:@"更新" confirmAction:^(UIAlertAction *action) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:newVerURL] options:@{} completionHandler:nil];
            } cancelTitle:@"暂不"];
        }
    }];
    [task resume];
}

@end
