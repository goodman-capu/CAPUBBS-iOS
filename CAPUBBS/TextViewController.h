//
//  TextViewController.h
//  CAPUBBS
//
//  Created by 范志康 on 15/3/29.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TextViewController : CustomTableViewController<UITextViewDelegate> {
    MBProgressHUD *hud;
    int color;
    NSArray *colors;
    NSArray *colorNames;
    NSArray *fontSizes;
    NSArray *fontNames;
    int fontSize;
    BOOL isBold;
    BOOL isItalics;
    BOOL isUnderscore;
    BOOL isDelete;
    int numberOfInserts;
}

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentColor;
@property (weak, nonatomic) IBOutlet UISlider *sliderSize;
@property (weak, nonatomic) IBOutlet UILabel *labelSize;
@property (weak, nonatomic) IBOutlet UISwitch *switchBold;
@property (weak, nonatomic) IBOutlet UISwitch *switchItalics;
@property (weak, nonatomic) IBOutlet UISwitch *switchUnderscore;
@property (weak, nonatomic) IBOutlet UISwitch *switchDelete;
@property (weak, nonatomic) IBOutlet UILabel *labelPreview;
@property (weak, nonatomic) IBOutlet UITextView *textInput;
@property NSString *defaultText;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonUndo;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAdd;

@end
