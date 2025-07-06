//
//  AnimatedImageView.h
//  CAPUBBS
//
//  Created by 熊典 on 14-8-17.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SDWebImage/SDAnimatedImage.h>
#import <SDWebImage/SDAnimatedImageView.h>

typedef NS_ENUM(int, ImageFileType) {
    ImageFileTypeUnknown = 0,
    ImageFileTypeJPEG,
    ImageFileTypePNG,
    ImageFileTypeGIF,
    ImageFileTypeHEIC,
    ImageFileTypeHEIF,
    ImageFileTypeWEBP  // iOS 14+
};

@interface AnimatedImageView : SDAnimatedImageView

- (void)setRounded:(BOOL)isRounded;
- (void)setImage:(UIImage *)image blurred:(BOOL)blurred animated:(BOOL)animated;
- (void)setGif:(NSString *)imageName;
- (void)setUrl:(NSString *)urlToSet;
- (NSString *)getUrl;
+ (NSString *)transIconURL:(NSString *)iconUrl;
+ (BOOL)isAnimated:(NSData *)imageData;
+ (BOOL)isAlpha:(UIImage *)image;
+ (ImageFileType)fileType:(NSData *)imageData;
+ (NSString *)fileExtension:(ImageFileType)type;
+ (void)checkPath;

@end
