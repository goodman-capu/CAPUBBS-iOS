//
//  AnimatedImageView.m
//  CAPUBBS
//
//  Created by 熊典 on 14-8-17.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "AnimatedImageView.h"

@implementation AnimatedImageView {
    NSString * latestUrl;
    BOOL rounded;
}

- (void)setRounded:(BOOL)isRounded {
    rounded = isRounded;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.masksToBounds = YES;
    if (rounded) {
        self.layer.cornerRadius = self.frame.size.width / 2;
    } else {
        self.layer.cornerRadius = 0.0f;
    }
}

- (void)setImage:(UIImage *)image {
    latestUrl = nil;
    [super setImage:image];
}

- (void)setImageInternal:(UIImage *)image {
    [super setImage:image];
}

- (void)setImage:(UIImage *)image blurred:(BOOL)blurred animated:(BOOL)animated {
    if (image && blurred) {
        image = [UIImageEffects imageByApplyingBlurToImage:image withRadius:40 tintColor:[UIColor colorWithWhite:0.93 alpha:0.9] saturationDeltaFactor:4 maskImage:nil];
    }
    if (animated) {
        [UIView transitionWithView:self
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            [self setImage:image];
        } completion:nil];
    } else {
        [self setImage:image];
    }
}

- (void)setGif:(NSString *)imageName {
    dispatch_global_default_async(^{
        NSString *filePath = [[NSBundle mainBundle] pathForResource:imageName ofType:nil];
        NSData *fileData = [NSData dataWithContentsOfFile:filePath];
        dispatch_main_async_safe(^{
            [self _setGifWithData:fileData internal:NO];
        });
    });
}

- (void)_setGifWithData:(NSData *)data internal:(BOOL)internal {
    SDAnimatedImage *image = [[SDAnimatedImage alloc] initWithData:data];
    // Loop forever
    self.shouldCustomLoopCount = YES;
    self.animationRepeatCount = 0;
    if (internal) {
        [self setImageInternal:image];
    } else {
        [self setImage:image];
    }
}

- (void)setUrl:(NSString *)urlToSet {
    NSString *newUrl = [AnimatedImageView transIconURL:urlToSet];
    if ([newUrl isEqualToString:latestUrl]) {
        return;
    }
    if (newUrl.length == 0) {
        NSLog(@"Failed to translate icon URL - %@", urlToSet);
        return;
    }
    latestUrl = newUrl;
    [self loadImageWithPlaceholder:YES];
}

- (NSString *)getUrl {
    return latestUrl;
}

- (void)loadImageWithPlaceholder:(BOOL)showPlaceholder {
    [NOTIFICATION removeObserver:self];
    NSString *imageUrl = latestUrl;
    NSString *filePath = [NSString stringWithFormat:@"%@/%@", ICON_CACHE_PATH, [Helper md5:imageUrl]];
    NSData *data = [MANAGER contentsAtPath:filePath];
    NSString *oldInfo = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (data.length > 0 && ![oldInfo hasPrefix:@"loading"]) { // 缓存存在的话直接加载缓存
        dispatch_main_async_safe(^{
            if (SIMPLE_VIEW) {
                [self setImageInternal:[UIImage imageWithData:data]];
            } else {
                [self _setGifWithData:data internal:YES];
            }
        });
        if (imageUrl.length > 0) {
            [NOTIFICATION postNotificationName:[@"imageSet" stringByAppendingString:imageUrl] object:nil userInfo:@{@"data": data}];
        }
    } else if (imageUrl.length > 0) {
        if (showPlaceholder) {
            dispatch_main_async_safe(^{
                [self setImageInternal:PLACEHOLDER];
            });
        }
        [NOTIFICATION addObserver:self selector:@selector(loadImageWithPlaceholder:) name:[@"imageGet" stringByAppendingString:imageUrl] object:nil];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSTimeZone *beijingTimeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
        [formatter setTimeZone:beijingTimeZone];
        if ([oldInfo hasPrefix:@"loading"]) {
            NSDate *oldDate = [formatter dateFromString:[oldInfo substringFromIndex:@"loading".length]];
            if ([[NSDate date] timeIntervalSinceDate:oldDate] < 60) { // 上次加载图片时间不超过一分钟
                return;
            }
        }
        NSString *newInfo = [@"loading" stringByAppendingString:[formatter stringFromDate:[NSDate date]]];
        [AnimatedImageView checkIconCachePath];
        [MANAGER createFileAtPath:filePath contents:[newInfo dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
        dispatch_global_default_async(^{
            [self startLoadingUrl:imageUrl withPlaceholder:showPlaceholder];
        });
    }
}

- (void)startLoadingUrl:(NSString *)imageUrl withPlaceholder:(BOOL)hasPlaceholder {
    NSString *filePath = [NSString stringWithFormat:@"%@/%@", ICON_CACHE_PATH, [Helper md5:imageUrl]];
    BOOL shouldSkipLoading = [[GROUP_DEFAULTS objectForKey:@"iconOnlyInWifi"] boolValue] && IS_CELLULAR;
    if (!shouldSkipLoading) {
        // NSLog(@"Load Img - %@", imageUrl);
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageUrl]];
        UIImage *image = [UIImage imageWithData:imageData];
        ImageFileType imageType = [AnimatedImageView fileType:imageData];
        if (imageType != ImageFileTypeUnknown) {
            if (![AnimatedImageView isAnimated:imageData]) {
                imageData = [AnimatedImageView resizeImage:image];
            }
            // NSLog(@"Icon Type:%@, Size:%dkb", imageType, (int)(imageData.length/1024));
            [AnimatedImageView checkIconCachePath];
            [MANAGER createFileAtPath:filePath contents:imageData attributes:nil];
            [NOTIFICATION postNotificationName:[@"imageGet" stringByAppendingString:imageUrl] object:nil];
            return;
        }
    }
    [MANAGER removeItemAtPath:filePath error:nil];
    if (!hasPlaceholder) {
        dispatch_main_async_safe(^{
            [self setImageInternal:PLACEHOLDER];
        });
    }
    if (!shouldSkipLoading) {
        NSLog(@"Image Load Failed - %@", imageUrl);
    }
}

+ (NSData *)resizeImage:(UIImage *)oriImage {
    BOOL hasAlpha = [oriImage hasAlphaChannel:NO];
    UIImage *resizeImage = oriImage;
    int maxWidth = 300; // 详细信息界面图片大小80 * 80，3x模式下可保证清晰
    if (oriImage.size.width > maxWidth) {
        CGFloat scaledHeight = maxWidth * oriImage.size.height / oriImage.size.width;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(maxWidth, scaledHeight), !hasAlpha, 0);
        [oriImage drawInRect:CGRectMake(0, 0, maxWidth, maxWidth * oriImage.size.height / oriImage.size.width)];
        resizeImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    if (hasAlpha) { // 带透明信息的png不可转换成jpeg否则丢失透明性
        return UIImagePNGRepresentation(resizeImage);
    } else {
        return UIImageJPEGRepresentation(resizeImage, 0.75);
    }
}

+ (BOOL)isAnimated:(NSData *)imageData {
    if (!imageData) {
        return NO;
    }
    SDAnimatedImage *animatedImage = [[SDAnimatedImage alloc] initWithData:imageData];
    return animatedImage && animatedImage.sd_imageFrameCount > 1;
}

+ (ImageFileType)fileType:(NSData *)imageData {
    if (!imageData || imageData.length == 0) {
        return ImageFileTypeUnknown;
    }
    
    NSString *textPrefix = [[NSString alloc] initWithData:[imageData subdataWithRange:NSMakeRange(0, MIN(1024, imageData.length))] encoding:NSUTF8StringEncoding];
    if ([[textPrefix lowercaseString] containsString:@"<svg"]) {
        return ImageFileTypeSVG;
    }

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (!source) {
        return ImageFileTypeUnknown;
    }

    CFStringRef utiString = CGImageSourceGetType(source);
    UTType *type = nil;
    if (utiString) {
        type = [UTType typeWithIdentifier:(__bridge NSString *)utiString];
    }
    CFRelease(source);

    if (!type) {
        return ImageFileTypeUnknown;
    }

    if ([type conformsToType:UTTypeJPEG]) {
        return ImageFileTypeJPEG;
    }
    if ([type conformsToType:UTTypePNG]) {
        return ImageFileTypePNG;
    }
    if ([type conformsToType:UTTypeGIF]) {
        return ImageFileTypeGIF;
    }
    if ([type conformsToType:UTTypeHEIC]) {
        return ImageFileTypeHEIC;
    }
    if ([type conformsToType:UTTypeHEIF]) {
        return ImageFileTypeHEIF;
    }
    if ([type conformsToType:UTTypeWebP]) {
        return ImageFileTypeWEBP;
    }
    // Only iOS 16+ supports native avif rendering
    if (@available(iOS 16.0, *)) {
        if ([type.identifier isEqualToString:@"public.avif"]) {
            return ImageFileTypeAVIF;
        }
    }

    return ImageFileTypeUnknown;
}

+ (NSString *)fileExtension:(ImageFileType)type {
    switch (type) {
        case ImageFileTypeSVG:
            return @"svg";
        case ImageFileTypeJPEG:
            return @"jpg";
        case ImageFileTypePNG:
            return @"png";
        case ImageFileTypeGIF:
            return @"gif";
        case ImageFileTypeHEIC:
            return @"heic";
        case ImageFileTypeHEIF:
            return @"heif";
        case ImageFileTypeWEBP:
            return @"webp";
        case ImageFileTypeAVIF:
            return @"avif";
        default:
            return nil;
    }
}

+ (void)checkIconCachePath {
    if ([MANAGER fileExistsAtPath:ICON_CACHE_PATH]) {
        return;
    }
    // 如果没有图片缓存目录则创建目录，并配置跳过iCloud备份
    [MANAGER createDirectoryAtPath:ICON_CACHE_PATH withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *cacheURL = [NSURL fileURLWithPath:ICON_CACHE_PATH];
    [cacheURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
}

+ (NSString *)transIconURL:(NSString *)iconUrl { // 转换用户头像地址函数
    if (iconUrl.length == 0) {
        return @"";
    }
    if (!([iconUrl hasPrefix:@"http://"] || [iconUrl hasPrefix:@"https://"] || [iconUrl hasPrefix:@"ftp://"])) {
        if ([iconUrl hasPrefix:@"/"]) {
            iconUrl = [NSString stringWithFormat:@"%@%@", CHEXIE, iconUrl];
        } else if ([iconUrl hasPrefix:@".."]) {
            iconUrl = [NSString stringWithFormat:@"%@/bbs/content/%@", CHEXIE, [iconUrl substringFromIndex:@"..".length]];
        } else {
            iconUrl = [NSString stringWithFormat:@"%@/bbsimg/i/%@.gif", CHEXIE, iconUrl];
        }
    }
    iconUrl = [iconUrl stringByReplacingOccurrencesOfString:@" " withString:@"%20"]; // URL中有空格的处理
    // NSLog(@"Icon URL:%@", icon);
    return iconUrl;
}

@end
