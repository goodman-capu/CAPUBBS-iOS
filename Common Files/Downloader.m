//
//  Downloader.m
//  CAPUBBS
//
//  Created by Zhikang Fan on 6/30/25.
//  Copyright © 2025 熊典. All rights reserved.
//

#import "Downloader.h"

@implementation NSURL (SafeURL)

+ (nullable instancetype)safeURLWithString:(nullable NSString *)URLString {
    if (!URLString || URLString.length == 0) {
        return nil;
    }
    
    NSURL *url = [NSURL URLWithString:URLString];
    if (@available (iOS 17.0, *)) {
        return url;
    }

    if (!url) {
        NSString *encodedString = [URLString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        if (encodedString.length > 0) {
            url = [NSURL URLWithString:encodedString];
        }
    }

    return url;
}

@end

@interface Downloader () <NSURLSessionDataDelegate>

// 持有回调 block 和下载过程中的数据
@property (nonatomic, copy) DownloaderProgressBlock progressBlock;
@property (nonatomic, copy) DownloaderCompletionBlock completionBlock;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, assign) long long expectedBytes;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLResponse *response;

@end

@implementation Downloader

// 使用一个静态集合来持有所有活动的 downloader 实例，防止它们被提前释放
static NSMutableSet<Downloader *> *activeDownloaders;

+ (void)initialize {
    if (self == [Downloader class]) {
        activeDownloaders = [NSMutableSet set];
    }
}

#pragma mark - Public API

+ (void)loadURLString:(NSString *)urlString
             progress:(nullable DownloaderProgressBlock)progressBlock
           completion:(DownloaderCompletionBlock)completionBlock {
    NSURL *url = [NSURL safeURLWithString:urlString];
    if (!url) {
        NSString *reason = [NSString stringWithFormat:@"Invalid URL string provided: %@", urlString];
        NSError *error = [NSError errorWithDomain:@"DownloaderErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: reason}];
        // 如果 URL 无效，立即在主线程调用完成回调
        dispatch_main_async_safe(^{
            completionBlock(nil, nil, error);
        });
        return;
    }
    
    [self loadURL:url progress:progressBlock completion:completionBlock];
}

+ (void)loadURL:(NSURL *)url
       progress:(nullable DownloaderProgressBlock)progressBlock
     completion:(DownloaderCompletionBlock)completionBlock {
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [self loadRequest:request progress:progressBlock completion:completionBlock];
}

+ (void)loadRequest:(NSURLRequest *)request
           progress:(nullable DownloaderProgressBlock)progressBlock
         completion:(DownloaderCompletionBlock)completionBlock {
    
    Downloader *downloader = [[self alloc] init];
    downloader.progressBlock = progressBlock;
    downloader.completionBlock = completionBlock;

    // 添加到静态集合中以持有实例
    @synchronized (activeDownloaders) {
        [activeDownloaders addObject:downloader];
    }

    [downloader startWithRequest:request];
}

#pragma mark - Internal Logic

- (void)startWithRequest:(NSURLRequest *)request {
    self.receivedData = [NSMutableData data];
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:nil]; // 代理方法将在后台队列执行
    
    [[self.session dataTaskWithRequest:request] resume];
}

- (void)finishWithError:(nullable NSError *)error {
    // 确保所有收尾工作和回调都在主线程执行
    dispatch_main_async_safe(^{
        if (self.completionBlock) {
            self.completionBlock(error ? nil : self.receivedData, self.response, error);
        }
        
        // 清理资源，打破循环引用
        self.progressBlock = nil;
        self.completionBlock = nil;
        [self.session finishTasksAndInvalidate];
        self.session = nil;

        // 从静态集合中移除，允许 ARC 释放此实例
        @synchronized (activeDownloaders) {
            [activeDownloaders removeObject:self];
        }
    });
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    self.expectedBytes = [response expectedContentLength];
    self.response = response;
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.receivedData appendData:data];

    if (self.progressBlock && self.expectedBytes > 0) {
        float progress = (float)self.receivedData.length / (float)self.expectedBytes;
        dispatch_main_async_safe(^{
            self.progressBlock(progress, self.expectedBytes);
        });
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    if (error) {
        [self finishWithError:error];
        return;
    }
    
    // 检查 HTTP 状态码
    if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
        if (statusCode < 200 || statusCode >= 300) {
            NSError *httpError = [NSError errorWithDomain:@"DownloaderErrorDomain"
                                                     code:statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSHTTPURLResponse localizedStringForStatusCode:statusCode]}];
            [self finishWithError:httpError];
            return;
        }
    }
    
    [self finishWithError:nil];
}

@end
