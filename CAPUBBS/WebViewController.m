//
//  WebViewController.m
//  CAPUBBS
//
//  Created by 范志康 on 15/5/12.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import "WebViewController.h"
#import <Foundation/NSURLError.h>

@interface WebViewController ()

@end

@implementation WebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.webViewContainer initiateWebViewWithToken:YES];
    [self.webViewContainer.webView setNavigationDelegate:self];
    [self.webViewContainer.webView.scrollView setDelegate:self];
    [self.webViewContainer.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    
    UIView *targetView = self.navigationController ? self.navigationController.view : self.view;
    hud = [[MBProgressHUD alloc] initWithView:targetView];
    [targetView addSubview:hud];
    self.buttonBack.enabled = NO;
    self.buttonForward.enabled = NO;
    NSURL *url = [NSURL URLWithString:self.URL];
    if (!url || !url.host || !url.scheme) {
        self.URL = [@"https://" stringByAppendingString:self.URL];
        url = [NSURL URLWithString:self.URL];
    }
    
    [self.webViewContainer.webView loadRequest:[NSURLRequest requestWithURL:url]];
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    activity = [[NSUserActivity alloc] initWithActivityType:[BUNDLE_IDENTIFIER stringByAppendingString:@".web"]];
    [self setSafeActivityUrl:[NSURL URLWithString:self.URL]];
    [activity becomeCurrent];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [activity invalidate];
}

- (void)dealloc {
    [self.webViewContainer.webView removeObserver:self forKeyPath:@"estimatedProgress"];
}

- (void)setSafeActivityUrl:(NSURL *)url {
    NSString *scheme = url.scheme.lowercaseString;
    if (url && ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        activity.webpageURL = url;
    } else {
        activity.webpageURL = nil;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"] && object == self.webViewContainer.webView) {
        CGFloat progress = self.webViewContainer.webView.estimatedProgress;
        [self.progressView setProgress:progress animated:YES];
        self.progressView.hidden = progress >= 1.0;
        if (progress >= 1.0) {
            dispatch_main_after(0.25, ^{
                [self.progressView setProgress:0.0 animated:NO];
            });
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    // 允许其他类型加载（如 form submit、reload）
    if (navigationAction.navigationType != WKNavigationTypeLinkActivated) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    NSString *path = navigationAction.request.URL.absoluteString;
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
    
    if ([path hasPrefix:@"tel:"]) {
        // Directly open
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:path] options:@{} completionHandler:nil];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.title = @"加载中";
    self.navigationItem.rightBarButtonItems = @[self.buttonStop];
    [self.navigationController setToolbarHidden:NO animated:YES];
    [self setSafeActivityUrl:webView.URL];

    if (titleCheckTimer && titleCheckTimer.isValid) {
        [titleCheckTimer invalidate];
    }
    
    // 使用 weakSelf 防止循环引用导致不能 dealloc
    __weak typeof(self) weakSelf = self;
    titleCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || webView.estimatedProgress < 0.2) {
            return;
        }
        [webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            if (!error && result && [result isKindOfClass:[NSString class]]) {
                strongSelf.title = result;
            }
        }];
    }];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.buttonBack.enabled = [webView canGoBack];
    self.buttonForward.enabled = [webView canGoForward];
    self.URL = webView.URL.absoluteString;
    self.navigationItem.rightBarButtonItems = @[self.buttonRefresh];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"⚠️ WebView 加载失败: %@", error);
    [self handleWebView:webView error:error];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"⚠️ WebView 导航失败: %@", error);
    [self handleWebView:webView error:error];
}

- (void)handleWebView:(WKWebView *)webView error:(NSError *)error {
    self.buttonBack.enabled = [webView canGoBack];
    self.buttonForward.enabled = [webView canGoForward];
    self.navigationItem.rightBarButtonItems = @[self.buttonRefresh];
    [self.progressView setProgress:0 animated:YES];
    self.progressView.hidden = YES;
        
    if (!error || ![error.domain isEqualToString:NSURLErrorDomain] || error.code == NSURLErrorCancelled) {
        return;
    }
    
    NSURL *failingUrl = error.userInfo[NSURLErrorFailingURLErrorKey];
    
//    if (error.code == NSURLErrorAppTransportSecurityRequiresSecureConnection && [failingUrl.scheme isEqualToString:@"http"]) { // http不安全链接 尝试使用https重连
//        NSString *httpsUrl = [failingUrl.absoluteString stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
//        [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:httpsUrl]]];
//        return;
//    }
    
    NSString *errorMessage = [error localizedDescription];
    switch (error.code) {
        case NSURLErrorTimedOut:
            errorMessage = @"请求超时";
            break;
        case NSURLErrorNotConnectedToInternet:
            errorMessage = @"无网络连接";
            break;
        case NSURLErrorNetworkConnectionLost:
            errorMessage = @"网络连接中断";
            break;
        case NSURLErrorCannotFindHost:
            errorMessage = @"无法找到服务器";
            break;
        case NSURLErrorCannotConnectToHost:
            errorMessage = @"无法连接到服务器";
            break;
        case NSURLErrorBadServerResponse:
            errorMessage = @"服务器响应异常";
            break;
        case NSURLErrorDataNotAllowed:
            errorMessage = @"数据访问受限，检查是否开启了网络访问权限";
            break;
        case NSURLErrorAppTransportSecurityRequiresSecureConnection:
            errorMessage = @"安全连接失败：不安全的 HTTP 网址被系统拒绝";
            break;
        case NSURLErrorSecureConnectionFailed:
            errorMessage = @"安全连接失败：可能为 HTTPS 证书问题";
            break;
        case NSURLErrorServerCertificateHasBadDate:
        case NSURLErrorServerCertificateUntrusted:
        case NSURLErrorServerCertificateHasUnknownRoot:
        case NSURLErrorServerCertificateNotYetValid:
        case NSURLErrorClientCertificateRejected:
        case NSURLErrorClientCertificateRequired:
            errorMessage = @"安全连接失败：HTTPS 证书异常";
            break;
        case NSURLErrorBadURL:
            errorMessage = @"无效的链接";
            break;
        case NSURLErrorUnsupportedURL: {
            NSString *scheme = failingUrl.scheme.lowercaseString;
            if (scheme && ![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
                errorMessage = @"不支持该链接，可能未安装相应App";
            } else {
                errorMessage = @"不支持该链接";
            }
            break;
        }
        default:
            break;
    }
    if (failingUrl.absoluteString) {
        NSString *urlString = failingUrl.absoluteString;
        NSString *displayURL = urlString;
        if (urlString.length > 200) {
            NSString *head = [urlString substringToIndex:100];
            NSString *tail = [urlString substringFromIndex:urlString.length - 100];
            displayURL = [NSString stringWithFormat:@"%@\n...\n%@", head, tail];
        }
        
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"加载错误" message:[NSString stringWithFormat:@"%@ (%ld)\n\n%@", errorMessage, error.code, displayURL] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"复制链接"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * action) {
            [[UIPasteboard generalPasteboard] setString:urlString];
            [hud showAndHideWithSuccessMessage:@"复制成功"];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"重新加载"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * action) {
            dispatch_main_after(0.25, ^{
                [webView loadRequest:[NSURLRequest requestWithURL:failingUrl]];
            });
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"好"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [self presentViewControllerSafe:alert];
    } else {
        [self showAlertWithTitle:@"加载错误" message:errorMessage];
    }
}

- (IBAction)stop:(id)sender {
    [self.webViewContainer.webView stopLoading];
}

- (IBAction)refresh:(id)sender {
    [self.webViewContainer.webView reload];
}

- (IBAction)close:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)back:(id)sender {
    [self.webViewContainer.webView goBack];
}

- (IBAction)forward:(id)sender {
    [self.webViewContainer.webView goForward];
}

- (IBAction)openInSafari:(id)sender {
    NSURL *url = [NSURL URLWithString:self.URL];
    if (url) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (IBAction)share:(id)sender {
    UIActivityViewController *activityViewController =
    [[UIActivityViewController alloc] initWithActivityItems:@[self.title, [NSURL URLWithString:self.URL]] applicationActivities:nil];
    activityViewController.popoverPresentationController.barButtonItem = self.buttonShare;
    [self presentViewControllerSafe:activityViewController];
}

// 开始拖拽视图
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    contentOffsetY = scrollView.contentOffset.y;
    isAtEnd = NO;
}

// 点击系统状态栏回到顶部
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    [self.navigationController setToolbarHidden:NO animated:YES];
    return YES;
}

// 滚动时调用此方法
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // NSLog(@"scrollView.contentOffset:%f, %f", scrollView.contentOffset.x, scrollView.contentOffset.y);
    if (isAtEnd == NO && scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.frame.size.height) {
        [self.navigationController setToolbarHidden:NO animated:YES];
        isAtEnd = YES;
    }
    if (isAtEnd == NO && scrollView.dragging) { // 拖拽
        if ((scrollView.contentOffset.y - contentOffsetY) > 5.0f) { // 向上拖拽
            [self.navigationController setToolbarHidden:YES animated:YES];
        } else if ((contentOffsetY - scrollView.contentOffset.y) > 5.0f) { // 向下拖拽
            [self.navigationController setToolbarHidden:NO animated:YES];
        }
    }
}

@end
