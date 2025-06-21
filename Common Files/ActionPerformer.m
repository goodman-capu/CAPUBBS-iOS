//
//  ActionPerformer.m
//  CAPUBBS
//
//  Created by 熊典 on 14-2-16.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "ActionPerformer.h"
#import "XMLDictionary.h" // XML parsing
#import <CommonCrypto/CommonCrypto.h> // MD5
#import "sys/utsname.h" // 设备型号

@implementation ActionPerformer

#pragma mark Web Request

+ (NSString *)encodeURIComponent:(NSString *)string {
    static NSCharacterSet *allowedCharacters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._* "];
    });
    NSString *encoded = [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    return [encoded stringByReplacingOccurrencesOfString:@" " withString:@"+"];
}

/**
 * 强制以UTF-8解码，并将所有无效的字节序列替换为指定内容
 * @param corruptData 从服务器接收的可能已损坏的NSData
 * @param replacement 无效字节的替换，默认为空（跳过）
 * @return 清理和解码后的NSString
 */
+ (NSString *)forceDecodeUTF8StringFromData:(NSData *)corruptData replacement:(NSString *)replacement {
    if (!corruptData || corruptData.length == 0) {
        return nil;
    }

    // 预先创建问号的NSData对象，以便在循环中复用
    NSData *replacementData = [replacement ?: @"" dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableData *cleanedData = [NSMutableData dataWithCapacity:corruptData.length];
    const unsigned char *bytes = (const unsigned char *)[corruptData bytes];
    NSUInteger length = corruptData.length;
    NSUInteger i = 0;

    while (i < length) {
        unsigned char leadByte = bytes[i];
        NSUInteger sequenceLength = 0;

        if ((leadByte & 0x80) == 0) { // 0xxxxxxx -> ASCII
            sequenceLength = 1;
        } else if ((leadByte & 0xE0) == 0xC0) { // 110xxxxx
            sequenceLength = 2;
        } else if ((leadByte & 0xF0) == 0xE0) { // 1110xxxx
            sequenceLength = 3;
        } else if ((leadByte & 0xF8) == 0xF0) { // 11110xxx
            sequenceLength = 4;
        } else {
            // 发现无效的UTF-8起始字节
            [cleanedData appendData:replacementData];
            i++;
            continue; // 继续下一个字节
        }

        if (i + sequenceLength > length) {
            // 数据末尾不足以构成一个完整序列，将其视为错误
            [cleanedData appendData:replacementData];
            break; // 结束循环
        }

        NSData *sequenceData = [NSData dataWithBytes:&bytes[i] length:sequenceLength];
        BOOL isValid = [[NSString alloc] initWithData:sequenceData encoding:NSUTF8StringEncoding] != nil;
        // 这样性能更高，但可能在极端情况下出错
//        BOOL isValid = YES;
//        for (NSUInteger j = 1; j < sequenceLength; j++) {
//            if ((bytes[i + j] & 0xC0) != 0x80) { // 非起始字节必须是 10xxxxxx
//                isValid = NO;
//                break;
//            }
//        }

        if (isValid) {
            // 这是一个有效的序列，直接追加原始字节
            [cleanedData appendData:sequenceData];
        } else {
            // 这是一个无效的序列 (例如，起始字节有效，但后续字节错误)
            [cleanedData appendData:replacementData];
        }
        
        // 移动指针到下一个序列的开始
        i += sequenceLength;
    }

    // 用清理过的数据最终生成字符串
    return [[NSString alloc] initWithData:cleanedData encoding:NSUTF8StringEncoding];
}

+ (void)callApiWithParams:(NSDictionary *)params toURL:(NSString*)url callback:(ActionPerformerResultBlock)block {
    NSLog(@"🌐 Calling API: %@", url);
    NSString *postUrl = [NSString stringWithFormat:@"%@/api/client.php?ask=%@",CHEXIE, url];
    
    NSMutableDictionary *requestParams = [@{
        @"os": @"ios",
        @"device": [ActionPerformer doDevicePlatform],
        @"version": [[UIDevice currentDevice] systemVersion],
        @"clientversion": APP_VERSION,
        @"clientbuild": APP_BUILD,
        @"token": TOKEN
    } mutableCopy];
    for (NSString *key in [params allKeys]) {
        NSString *data = params[key];
        if ([data hasPrefix:@"@"]) { // 修复字符串首带有@时的错误
            data = [@" " stringByAppendingString:data];
        }
        requestParams[key] = data;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest
                                    requestWithURL:[NSURL URLWithString:postUrl]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 30;
    
    // Convert parameters to x-www-form-urlencoded (or JSON, depending on server)
    NSMutableArray *bodyParts = [NSMutableArray array];
    [requestParams enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *part = [NSString stringWithFormat:@"%@=%@",
                          [self encodeURIComponent:key],
                          [self encodeURIComponent:obj]];
        [bodyParts addObject:part];
    }];
    NSString *bodyString = [bodyParts componentsJoinedByString:@"&"];
    NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPBody = bodyData;
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"API POST error: %@", error);
            dispatch_main_async_safe(^{
                block(nil, error);
            });
            return;
        }
        
        BOOL hasError = NO;
        // Sanity check by encoding to UTF-8. Otherwise it might fail silently with lost data.
        NSString *xmlString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!xmlString) {
            NSLog(@"API data corrupted, attempting to recover...");
            xmlString = [self forceDecodeUTF8StringFromData:data replacement:@"�"];
            if (!xmlString) {
                NSLog(@"API data recovery failed!");
                hasError = YES;
            } else {
                NSLog(@"API data recovery success!");
            }
        }
        NSDictionary *xmlData = [NSDictionary dictionaryWithXMLString:xmlString];
        if (!xmlData || ![xmlData[@"__name"] isEqualToString:@"capu"]) {
            hasError = YES;
        }
        if (hasError) {
            [NOTIFICATION postNotificationName:@"showAlert" object:nil userInfo:@{@"title": @"加载失败", @"message": @"内容解析出现异常\n请使用网页版查看"}];
            dispatch_main_async_safe(^{
                block(nil, [NSError errorWithDomain:@"XMLParsing" code:0 userInfo:@{NSLocalizedDescriptionKey: @"XML parsing failed"}]);
            });
        } else {
            id info = xmlData[@"info"];
            NSArray *result;
            if (!info) {
                result = @[];
            } else if ([info isKindOfClass:[NSArray class]]) {
                result = info;
            } else {
                result = @[info];
            }
            dispatch_main_async_safe(^{
                block(result, nil);
            });
        }
    }];
    [task resume];
}

#pragma mark Common Functions

+ (BOOL)checkLogin:(BOOL)showAlert {
    if ([TOKEN length] == 0) { // 判断是否登录的方法为判断token是否为空
        if (showAlert) {
            [NOTIFICATION postNotificationName:@"showAlert" object:nil userInfo:@{@"title": @"错误", @"message": @"尚未登录"}];
        }
        return NO;
    } else {
        return YES;
    }
}

+ (int)checkRight {
    if ([self checkLogin:NO] && ![USERINFO isEqual:@""]) {
        return [[USERINFO objectForKey:@"rights"] intValue];
    } else {
        return -1;
    }
}

+ (void)checkPasswordLength {
    if ([PASS length] < 6) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd"];
        NSTimeZone *beijingTimeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
        [formatter setTimeZone:beijingTimeZone];
        NSDate *currentDate = [NSDate date];
        NSDate *lastDate =[formatter dateFromString:[DEFAULTS objectForKey:@"checkPass"]];
        NSTimeInterval time = [currentDate timeIntervalSinceDate:lastDate];
        if ((int)time > 3600 * 24) { // 每天提醒一次
            [NOTIFICATION postNotificationName:@"showAlert" object:nil userInfo:@{@"title": @"提醒", @"message": @"您的密码过于简单！\n建议在个人信息中修改密码", @"cancelTitle": @"今日不再提醒"}];
            [DEFAULTS setObject:[formatter stringFromDate:currentDate] forKey:@"checkPass"];
        }
    }
}

+ (void)updateUserInfo:(NSDictionary *)userInfo {
    [GROUP_DEFAULTS setObject:userInfo forKey:@"userInfo"];
    NSMutableArray *data = [NSMutableArray arrayWithArray:[DEFAULTS objectForKey:@"ID"]];
    for (int i = 0; i < data.count; i++) {
        if (![data[i][@"id"] isEqualToString:userInfo[@"username"]]) {
            continue;
        }
        if (![data[i][@"icon"] isEqualToString:userInfo[@"icon"]]) {
            NSMutableDictionary *tempDict = [data[i] mutableCopy];
            tempDict[@"icon"] = userInfo[@"icon"];
            data[i] = tempDict;
            [DEFAULTS setObject:data forKey:@"ID"];
        }
        break;
    }
}

+ (NSString *)restoreTitle:(NSString *)text {
    BOOL remove = YES;
    while (remove) {
        remove = NO;
        if ([text hasPrefix:@"Re:"] || [text hasPrefix:@"Re："]) {
            remove = YES;
            text = [text substringFromIndex:@"Re:".length];
        }
        if ([text hasPrefix:@" "]) {
            remove = YES;
            text = [text substringFromIndex:@" ".length];
        }
    }
    text = [self simpleEscapeHTML:text processLtGt:YES];
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    return text;
}

+ (NSString *)getBoardTitle:(NSString *)bid {
    NSArray *titles = @[@"车协工作区", @"行者足音", @"车友宝典", @"纯净水", @"考察与社会", @"五湖四海", @"一技之长", @"竞赛竞技", @"网站维护"];
    if ([bid hasPrefix:@"b"]) {
        bid = [bid substringFromIndex:@"b".length];
    }
    if ([bid isEqualToString:@"-1"]) {
        return @"全部版面";
    }
    for (int i = 0; i < NUMBERS.count; i++) {
        if ([bid isEqualToString:NUMBERS[i]]) {
            return titles[i];
        }
    }
    return @"未知版面";
}

+ (NSString *)htmlStringWithText:(NSString *)text sig:(NSString *)sig textSize:(int)textSize {
    NSString *body = @"";
    if (text) {
        body = [NSString stringWithFormat:@"<div class='textblock'>%@</div>", text];
    }
    if (sig && sig.length > 0) {
        body = [NSString stringWithFormat:@"%@<div class='sigblock'>%@"
                "<div class='sig'>%@</div></div>", body, text ? @"<span class='sigtip'>--------</span>" : @"", sig];
    }
    
    NSString *jQueryScript = @"";
    if ([body containsString:@"<script"] && [body containsString:@"/script>"]) {
        NSError *error = nil;
        NSString *jQueryContent = [NSString stringWithContentsOfFile:JQUERY_MIN_JS encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            jQueryScript = [NSString stringWithFormat:@"<script>%@</script>", jQueryContent];
        } else {
            NSLog(@"Failed to load jquery script: %@", error);
        }
    }
    
    NSString *hideImageHeaders = [[DEFAULTS objectForKey:@"picOnlyInWifi"] boolValue] && IS_CELLULAR ?
    @"<style type='text/css'>"
    "img{display:none;}img.image-hidden{display:block !important;background-color:#f0f0f0 !important;border:1px solid #ccc !important;}"
    "</style>"
    "<script>window._hideAllImages=true</script>"
    : @"";
    NSString *sigBlockStyle = text ? @".sigblock{color:gray;font-size:small;margin-top:1em;}" : @"";
    NSString *bodyBackground = text ? @"rgba(255,255,255,0.75)" : @"transparent";
    
    return [NSString stringWithFormat:@"<html>"
            "<head>"
            "<meta name='viewport' content='width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no'>"
            "%@"
            "%@"
            "<style type='text/css'>"
            "img{max-width:min(100%%,700px);}"
            "body{font-size:16px;word-wrap:break-word;zoom:%d%%;}"
            "#body-wrapper{padding:0 0.25em;}"
            "#body-mask{position:absolute;top:0;bottom:0;left:0;right:0;z-index:-1;background-color:%@;transition:background-color 0.2s linear;}"
            ".quoteblock{background-color:rgba(235,235,235,0.5);color:gray;font-size:small;padding:0.6em 2em 0;margin:0.6em 0;border-radius:0.5em;border:1px solid #ddd;position:relative;}"
            ".quoteblock::before,.quoteblock::after{position:absolute;font-size:4em;color:#d8e7f1;font-family:sans-serif;pointer-events:none;line-height:1;}"
            ".quoteblock::before{content:'“';top:0.05em;left:0.1em;}"
            ".quoteblock::after{content:'”';bottom:-0.5em;right:0.15em;}"
            ".textblock,.sig{overflow-x:scroll;}"
            ".textblock{min-height:3em;}"
            "%@"
            ".sig{max-height:400px;overflow-y:scroll;}"
            "</style>"
            "</head>"
            "<body><div id='body-mask'></div><div id='body-wrapper'>%@</div></body>"
            "</html>", jQueryScript, hideImageHeaders, textSize, bodyBackground, sigBlockStyle, body];
}

+ (NSDictionary *)getLink:(NSString *)path {
    NSString *bid = @"", *tid = @"", *p = @"", *floor = @"";
    NSURLComponents *components = [NSURLComponents componentsWithString:path];
    if (!components) {
        return @{@"bid" : bid, @"tid" : tid, @"p" : p, @"floor" : floor};
    }
    
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in components.queryItems) {
        if (item.value) { // 只添加有值的参数
            params[item.name] = item.value;
        }
    }
    
    NSString *urlPath = components.path;
    if ([urlPath containsString:@"/bbs/content"] || [urlPath containsString:@"/bbs/main"]) {
        bid = params[@"bid"] ?: @"";
        tid = params[@"tid"] ?: @"";
        p = params[@"p"];
        if (tid.length > 0) {
            floor = components.fragment ?: @"";
        }
    } else if ([urlPath containsString:@"/cgi-bin/bbs.pl"]) {
        bid = params[@"b"] ?: @"";
        tid = params[@"see"] ?: @"";
        NSString *oldbid = params[@"id"];
        if (oldbid) {
            // 这个转换表可以作为静态字典或属性，避免重复创建
            NSDictionary *trans = @{@"act": @"1", @"capu": @"2", @"bike": @"3", @"water": @"4", @"acad": @"5", @"asso": @"6", @"skill": @"7", @"race": @"9", @"web": @"28"};
            bid = trans[oldbid] ?: bid;
        }
        if (tid.length > 0) {
            long count = 0; // 转换26进制tid
            NSString *lowerTid = [tid lowercaseString];
            for (int i = 0; i < lowerTid.length; i++) {
                int charValue = [lowerTid characterAtIndex:lowerTid.length - 1 - i] - 'a';
                if (charValue >= 0 && charValue < 26) {
                    count += charValue * pow(26, i);
                }
            }
            count++;
            tid = [NSString stringWithFormat:@"%ld", count];
        }
    }
    if (p.length == 0) {
        p = @"1";
    }
    return @{@"bid" : bid, @"tid" : tid, @"p" : p, @"floor" : floor};
}

+ (NSString *)restoreFormat:(NSString *)text {
    if (!text || text.length == 0) {
        return text;
    }
    NSRegularExpressionOptions options = NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators;
    // NSLog(@"%@", text);
    NSArray *oriExp = @[@"(<quote>)(.*?)(<a href=['\"]/bbs/user)(.*?)(>@)(.*?)(</a> ：<br><br>)((.|[\r\n])*?)(<br><br></font></div></quote>)",
                        @"(<a href=['\"]/bbs/user)(.*?)(>@)(.*?)(</a>)",
                        @"(<a href=['\"]#['\"]>)((.|[\r\n])*?)(</a>)", // 修复网页版@格式的错误
                        @"(<a href=['\"])(.+?)(['\"][^>]*>)(.+?)(</a>)",
                        @"<img[^>]*?\\bsrc=['\"]([^'\"]+)['\"][^>]*?>",
                        @"<b[^>]*>(.+?)</b>",
                        @"<i[^>]*>(.+?)</i>"];
    NSArray *repExp = @[@"[quote=$6]$8[/quote]",
                        @"[at]$4[/at]",
                        @"$2",
                        @"[url=$2]$4[/url]",
                        @"[img]$1[/img]",
                        @"[b]$1[/b]",
                        @"[i]$1[/i]"];
    NSRegularExpression *regExp;
    for (int i = 0; i < oriExp.count; i++) {
        regExp = [NSRegularExpression regularExpressionWithPattern:oriExp[i] options:options error:nil];
        text = [regExp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:repExp[i]];
    }
    
    while (YES) {
        NSString *textHTML = nil;
        NSString *textBody = nil;
        NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"<font([^>]*)>([^<]*?)</font>" options:options error:nil];
        NSTextCheckingResult *match = [regexp firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
        if (match) {
            NSRange attributesRange = [match rangeAtIndex:1];
            if (attributesRange.location != NSNotFound) {
                textHTML = [text substringWithRange:attributesRange];
            }
            NSRange bodyRange = [match rangeAtIndex:2];
            if (bodyRange.location != NSNotFound) {
                textBody = [text substringWithRange:bodyRange];
            }
        }
        if (!textHTML || !textBody) {
            break;
        }
        
        NSString *finalTextBody = textBody;
        regexp = [NSRegularExpression regularExpressionWithPattern:@"(color|size|face)=['\"]([^'\"]+)['\"]" options:options error:nil];
        
        NSArray<NSTextCheckingResult *> *matches = [regexp matchesInString:textHTML options:0 range:NSMakeRange(0, textHTML.length)];
        for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
            NSString *key = [textHTML substringWithRange:[match rangeAtIndex:1]];
            NSString *value = [textHTML substringWithRange:[match rangeAtIndex:2]];
            if ([key caseInsensitiveCompare:@"color"] == NSOrderedSame) {
                finalTextBody = [NSString stringWithFormat:@"[color=%@]%@[/color]", value, finalTextBody];
            }
            else if ([key caseInsensitiveCompare:@"size"] == NSOrderedSame) {
                finalTextBody = [NSString stringWithFormat:@"[size=%@]%@[/size]", value, finalTextBody];
            }
            else if ([key caseInsensitiveCompare:@"face"] == NSOrderedSame) {
                finalTextBody = [NSString stringWithFormat:@"[font=%@]%@[/font]", value, finalTextBody];
            }
        }
        text = [text stringByReplacingCharactersInRange:match.range withString:finalTextBody];
    }
    
    return text;
}

+ (NSString *)simpleEscapeHTML:(NSString *)text processLtGt:(BOOL)ltGt {
    if (!text || text.length == 0) {
        return text;
    }
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
    
    NSString *expression = @"<br[^>]*>"; // 恢复换行
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:expression options:0 error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"\n"];
    
    NSDictionary *entityMap = @{
        @"&nbsp;": @" ",   @"&amp;": @"&",    @"&apos;": @"'",
        @"&quot;": @"\"",  @"&ldquo;": @"“",  @"&rdquo;": @"”",
        @"&#39;": @"'",    @"&mdash;": @"——", @"&hellip;": @"…"
    };
    for (NSString *key in entityMap) {
        text = [text stringByReplacingOccurrencesOfString:key withString:entityMap[key]];
    }
    if (ltGt) {
        NSDictionary *entityMap = @{@"&lt;": @"<", @"&gt;": @">"};
        for (NSString *key in entityMap) {
            text = [text stringByReplacingOccurrencesOfString:key withString:entityMap[key]];
        }
    }
    return text;
}

+ (NSString *)toCompatibleFormat:(NSString *)text {
    if (!text || text.length == 0) {
        return @"";
    }
    // Restore spaces & new lines
    text = [text stringByReplacingOccurrencesOfString:@"\n<br>" withString:@"<br>"];
    text = [text stringByReplacingOccurrencesOfString:@"\n\r" withString:@"<br>"];
    text = [text stringByReplacingOccurrencesOfString:@"\r" withString:@"<br>"];
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
    int index = 0;
    while (index < text.length) {
        if ([[text substringWithRange:NSMakeRange(index, 1)] isEqualToString:@"<"]) {
            index++;
            while (index < text.length) {
                if ([[text substringWithRange:NSMakeRange(index, 1)] isEqualToString:@">"]) {
                    break;
                }
                index++;
            }
        }
        if (index < text.length && [[text substringWithRange:NSMakeRange(index, 1)] isEqualToString:@" "]) {
            text = [text stringByReplacingCharactersInRange:NSMakeRange(index, 1) withString:@"&nbsp;"];
            index += 5;
        }
        index++;
    }
    return text;
}

+ (NSString *)transToHTML:(NSString *)text {
    if (!text || text.length == 0) {
        return @"";
    }
    // Restore spaces & new lines
    text = [self toCompatibleFormat:text];

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
    NSArray *newExp = @[@"<img src='$2'>",
                        @"<quote><div class='quoteblock'><font>引用自 [at]$2[/at] ：<br><br>$4<br><br></font></div></quote>",
                        @"<font size='$2'>$4</font>",
                        @"<font face='$2'>$4</font>",
                        @"<font color='$2'>$4</font>",
                        @"<font color='$2'>$4</font>",
                        @"<a href='/bbs/user?name=$2'>@$2</a>",
                        @"<a href='$2'>$2</a>",
                        @"<a href='$2'>$4</a>",
                        @"<b>$2</b>",
                        @"<i>$2</i>"];
    for (int i = 0; i < oriExp.count; i++) {
        NSRegularExpression *regExp = [NSRegularExpression regularExpressionWithPattern:oriExp[i] options:0 error:nil];
        text = [regExp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:newExp[i]];
    }
    return text;
}

+ (NSString *)removeHTML:(NSString *)text {
    if (!text || text.length == 0) {
        return text;
    }
    text = [self simpleEscapeHTML:text processLtGt:NO];
    
    NSRegularExpressionOptions options = NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators;

    // 去除注释
    NSString *expression = @"<!--.*?-->";
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:expression options:options error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    
    // 去除style内容
    expression = @"<style[^>]*>.*?</style>";
    regexp = [NSRegularExpression regularExpressionWithPattern:expression options:options error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];

    // 处理 <div> 为换行
    expression = @"<div[^>]*>(.*?)</div>";
    regexp = [NSRegularExpression regularExpressionWithPattern:expression options:options error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"$1\n"];

    // 处理 <p> 为换行
    expression = @"<p[^>]*>(.*?)</p>";
    regexp = [NSRegularExpression regularExpressionWithPattern:expression options:options error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"$1\n"];

    // 处理 <span> 为不换行
    expression = @"<span[^>]*>(.*?)</span>";
    regexp = [NSRegularExpression regularExpressionWithPattern:expression options:options error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"$1"];
    
    // 去除所有HTML标签
    expression = @"<[^>]+>";
    regexp = [NSRegularExpression regularExpressionWithPattern:expression options:options error:nil];
    text = [regexp stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    
    text = [text stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    text = [text stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    // NSLog(@"%@", text);
    return text;
}

+ (NSString *)md5:(NSString *)str { // 字符串MD5值算法
    if (!str) {
        return @"";
    }
    const char* cStr=[str UTF8String];
    CC_LONG dataLength = (CC_LONG)[str lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    unsigned char digist[CC_MD5_DIGEST_LENGTH]; // CC_MD5_DIGEST_LENGTH = 16
    CC_MD5(cStr, dataLength, digist);
    NSMutableString* outPutStr = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int  i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [outPutStr appendFormat:@"%02X", digist[i]];// 小写 x 表示输出的是小写 MD5 ，大写 X 表示输出的是大写 MD5
    }
    return [outPutStr copy];
}

+ (NSString *)getSigForData:(id)data {
    NSError *error = nil;
    NSData *dataJson = [NSJSONSerialization dataWithJSONObject:data
                                                       options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys
                                                         error:&error];
    if (!error) {
        NSString *dataString = [[NSString alloc] initWithData:dataJson encoding:NSUTF8StringEncoding];
        if (dataString) {
            return [self md5:[dataString stringByAppendingString:SALT]];
        }
    }
    return nil;
}

+ (NSString *)doDevicePlatform { // 获取设备信息
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    // return platform;
    NSDictionary *dict = @{
        // Simulator
        @"x86_64": @"iOS Simulator",
        @"arm64": @"iOS Simulator",
    };
    
    if (dict[platform]) {
        platform = dict[platform];
    }
    
    // NSLog(@"Platform = %@",platform);
    return platform;
}

@end
