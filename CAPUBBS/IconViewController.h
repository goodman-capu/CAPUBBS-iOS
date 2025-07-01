//
//  IconViewController.h
//  CAPUBBS
//
//  Created by 范志康 on 15/3/17.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AnimatedImageView.h"

@interface IconViewController : CustomCollectionViewController<UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
    NSArray *iconNames;
    MBProgressHUD *hud;
    AnimatedImageView *previewImageView;
    int newIconNum;
    int oldIconNum;
    int largeCellSize;
    int smallCellSize;
}

@property NSString *userIcon;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonUpload;

@end
