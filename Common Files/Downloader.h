//
//  Downloader.h
//  CAPUBBS
//
//  Created by Zhikang Fan on 6/30/25.
//  Copyright © 2025 熊典. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (SafeURL)

/// This is useful before iOS 17
+ (nullable instancetype)safeURLWithString:(nullable NSString *)URLString;

@end

typedef void(^DownloaderProgressBlock)(float progress, NSUInteger expectedBytes);
typedef void(^DownloaderCompletionBlock)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

@interface Downloader : NSObject

/**
 * 通过 URL 字符串下载文件。
 * 所有回调均在主线程执行。
 */
+ (void)loadURLString:(NSString *)urlString
             progress:(nullable DownloaderProgressBlock)progressBlock
           completion:(DownloaderCompletionBlock)completionBlock;

/**
 * 通过 NSURL 下载文件。
 * 所有回调均在主线程执行。
 */
+ (void)loadURL:(NSURL *)url
       progress:(nullable DownloaderProgressBlock)progressBlock
     completion:(DownloaderCompletionBlock)completionBlock;

/**
 * 通过 NSURLRequest 下载文件，允许自定义请求头等信息。
 * 所有回调均在主线程执行。
 */
+ (void)loadRequest:(NSURLRequest *)request
           progress:(nullable DownloaderProgressBlock)progressBlock
         completion:(DownloaderCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
