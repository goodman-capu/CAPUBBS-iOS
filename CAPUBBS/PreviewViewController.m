//
//  PreviewViewController.m
//  CAPUBBS
//
//  Created by 范志康 on 15/4/12.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import "PreviewViewController.h"
#import "ContentViewController.h"
#import "WebViewController.h"

@interface PreviewViewController ()

@end

@implementation PreviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GRAY_PATTERN;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(done:)];
    [self.webView.layer setBorderColor:GREEN_LIGHT.CGColor];
    [self.webView setDelegate:self];
    [self.webView.layer setBorderWidth:1.0];
    [self.webView.layer setMasksToBounds:YES];
    [self.webView.layer setCornerRadius:10.0];
    [self.webView setAllowsLinkPreview:YES];
    self.labelTitle.text = self.textTitle;
    NSDictionary *dict = USERINFO;
    NSString *sig = nil;
    if (self.sig > 0) {
        if ([dict isEqual:@""] || [dict[[NSString stringWithFormat:@"sig%d", self.sig]] length] == 0) {
            sig = [NSString stringWithFormat:@"[您选择了第%d个签名档]", self.sig];
        } else {
            sig = dict[[NSString stringWithFormat:@"sig%d", self.sig]];
        }
    }
    NSString *html = [ContentViewController htmlStringWithText:[self transToHTML:self.textBody] sig:sig textSize:[[DEFAULTS objectForKey:@"textSize"] intValue]];
    [self.webView loadHTMLString:html baseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/bbs/content/?", CHEXIE]]];
    // Do any additional setup after loading the view.
}

- (void)done:(id)sender{
    [NOTIFICATION postNotificationName:@"publishContent" object:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

- (NSString *)transToHTML:(NSString *)oriString {
    NSArray *oriExp = @[@"(\\[img])(.+?)(\\[/img])",
                        @"(\\[quote=)(.+?)(])([\\s\\S]+?)(\\[/quote])",
                        @"(\\[size=)(.+?)(])([\\s\\S]+?)(\\[/size])",
                        @"(\\[font=)(.+?)(])([\\s\\S]+?)(\\[/font])",
                        @"(\\[color=)(.+?)(])([\\s\\S]+?)(\\[/color])",
                        @"(\\[color=)(.+?)(])([\\s\\S]+?)",
                        @"(\\[at])(.+?)(\\[/at])",
                        @"(\\[url])(.+?)(\\[/url])",
                        @"(\\[url=)(.+?)(])([\\s\\S]+?)(\\[/url])",
                        @"(\\[b])(.+?)(\\[/b])",
                        @"(\\[i])(.+?)(\\[/i])"];
    NSArray *repExp = @[@"<img src='$2'>",
                        @"<quote><div style=\"background:#F5F5F5;padding:10px\"><font color='gray' size=2>引用自 [at]$2[/at] ：<br><br>$4<br><br></font></div></quote>",
                        @"<font size='$2'>$4</font>",
                        @"<font face='$2'>$4</font>",
                        @"<font color='$2'>$4</font>",
                        @"<font color='$2'>$4</font>",
                        @"<a href='/bbs/user?name=$2'>@$2</a>",
                        @"<a href='$2'>$2</a>",
                        @"<a href='$2'>$4</a>",
                        @"<b>$2</b>",
                        @"<i>$2</i>"];
    NSRegularExpression *regexp;
    for (int i = 0; i < oriExp.count; i++) {
        regexp = [NSRegularExpression regularExpressionWithPattern:[oriExp objectAtIndex:i] options:0 error:nil];
        oriString = [regexp stringByReplacingMatchesInString:oriString options:0 range:NSMakeRange(0, oriString.length) withTemplate:[repExp objectAtIndex:i]];
    }
    return oriString;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{// 处理帖子中的URL
    // NSLog(@"type=%d,path=%@",navigationType,request.URL.absoluteString);
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        NSString *path = request.URL.absoluteString;
        WebViewController *dest = [self.storyboard instantiateViewControllerWithIdentifier:@"webview"];
        CustomNavigationController *navi = [[CustomNavigationController alloc] initWithRootViewController:dest];
        dest.URL = path;
        navi.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewControllerSafe:navi];
        return NO;
    } else {
        return YES;
    }
}

@end
