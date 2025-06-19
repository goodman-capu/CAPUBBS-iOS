//
//  CustomWebView.h
//  CAPUBBS
//
//  Created by Zhikang Fan on 6/6/25.
//  Copyright © 2025 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomWebViewContainer : UIView <WKUIDelegate>

@property (nonatomic, strong) WKWebView *webView;

+ (void)clearAllDataStores:(void (^)(void))completionHandler;

// Token should be excluded in most cases
- (void)initiateWebViewWithToken:(BOOL)hasToken;

@end

// 防止循环引用的delegate
@interface WeakScriptMessageDelegate : NSObject <WKScriptMessageHandler>

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)delegate;

@property (nonatomic, weak, readonly) id<WKScriptMessageHandler> delegate;

@end

NS_ASSUME_NONNULL_END
