//
//  Helper.h
//  CAPUBBS
//
//  Created by 熊典 on 14-2-16.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ApiCompletionBlock)(NSArray* result, NSError* err);

@interface Helper: NSObject

+ (void)callApiWithParams:(NSDictionary*)params toURL:(NSString*)url callback:(ApiCompletionBlock)block;
+ (BOOL)checkLogin:(BOOL)showAlert;
+ (int)checkRight;
+ (void)updateUserInfo:(NSDictionary *)userInfo;

/// 移除帖子标题里嵌套的 Re：Re：Re：xxx
+ (NSString *)restoreTitle:(NSString *)text;
/// 拿到板块标题
+ (NSString *)getBoardTitle:(NSString *)bid;
/// 把正文和签名档组合成正式的 HTML
+ (NSString *)htmlStringWithText:(NSString *)text attachments:(NSArray *)attachements sig:(NSString *)sig textSize:(int)textSize;
/// 把转义过的 HTML 恢复成对应字符，例如 \&lt; 恢复成 <，但现有 HTML 标签里的内容不转义
+ (NSString *)simpleEscapeHTML:(NSString *)text processLtGt:(BOOL)ltGt;
/// 把空格和换行转换成 \<br\> 和 \&nbsp; 目的是兼容网页版编辑器，纯客户端其实不需要这个功能
+ (NSString *)toCompatibleFormat:(NSString *)text;
/// 将论坛的标签转义，例如 [font=][/font] 变成 \<font>xxx\</font>
+ (NSString *)transToHTML:(NSString *)text;
/// 清除 HTML 标签，有损操作，可能丢失信息
+ (NSString *)removeHTML:(NSString *)text restoreFormat:(BOOL)restoreFormat;
/// 提取论坛的链接，获取bid，tid，p，floor
+ (NSDictionary *)getLink:(NSString *)path;

+ (NSString *)fileSize:(NSInteger)size;
+ (NSString *)fileNameFromURL:(NSURL *)url;
+ (BOOL)isHttpScheme:(NSString *)scheme;
+ (NSString *)md5:(NSString *)str;
+ (NSString *)getSigForData:(id)data;
+ (NSString *)doDevicePlatform;

@end
