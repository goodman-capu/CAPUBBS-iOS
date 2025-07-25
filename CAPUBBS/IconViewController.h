//
//  IconViewController.h
//  CAPUBBS
//
//  Created by 范志康 on 15/3/17.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import "TOCropViewController.h"
#import "AnimatedImageView.h"

@interface IconViewController : CustomCollectionViewController<UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate, TOCropViewControllerDelegate> {
    NSArray *iconNames;
    MBProgressHUD *hud;
    AnimatedImageView *previewImageView;
    int newIconNum;
    int oldIconNum;
    int largeCellSize;
    int smallCellSize;
    BOOL imageHasAlpha;
    BOOL useCamera;
}

@property NSString *userIcon;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonUpload;

@end
