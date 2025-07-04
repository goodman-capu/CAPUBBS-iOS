//
//  SettingViewController.h
//  CAPUBBS
//
//  Created by 熊典 on 14-2-20.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AnimatedImageView.h"

@interface SettingViewController : CustomTableViewController {
    MBProgressHUD *hud;
    BOOL isCalculatingCache;
}

@property (weak, nonatomic) IBOutlet AnimatedImageView *iconUser;
@property (weak, nonatomic) IBOutlet UILabel *textUid;
@property (weak, nonatomic) IBOutlet UILabel *textUidInfo;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellUser;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoLogin;
@property (weak, nonatomic) IBOutlet UISwitch *switchVibrate;
@property (weak, nonatomic) IBOutlet UISwitch *switchPic;
@property (weak, nonatomic) IBOutlet UISwitch *switchIcon;
@property (weak, nonatomic) IBOutlet UILabel *iconCacheSize;
@property (weak, nonatomic) IBOutlet UILabel *appCacheSize;
@property (weak, nonatomic) IBOutlet UILabel *defaultSize;
@property (weak, nonatomic) IBOutlet UIStepper *stepperSize;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoSave;
@property (weak, nonatomic) IBOutlet UISwitch *switchSimpleView;
@property (weak, nonatomic) IBOutlet UISwitch *switchChangeBackground;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentDirection;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentEditTool;

+ (unsigned long long)fileSizeAtPath:(NSString *)filePath;
+ (unsigned long long)folderSizeAtPath:(NSString *)folderPath;

@end
