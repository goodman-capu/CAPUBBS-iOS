//
//  ComposeViewController.h
//  CAPUBBS
//
//  Created by 熊典 on 14-2-19.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>

@interface ComposeViewController : CustomViewController<UITextFieldDelegate, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate> {
    MBProgressHUD *hud;
    NSUserActivity *activity;
    int toolbarEditor;
    UIView *keyboardToolView;
}

@property (weak, nonatomic) IBOutlet UITextField *textTitle;
@property (weak, nonatomic) IBOutlet UITextView *textBody;
@property (weak, nonatomic) IBOutlet UIButton *saveDraft;
@property (weak, nonatomic) IBOutlet UIButton *restoreDraft;
@property (weak, nonatomic) IBOutlet UIButton *buttonPic;
@property (weak, nonatomic) IBOutlet UIButton *buttonTools;
@property (weak, nonatomic) IBOutlet UIButton *buttonAttachments;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentSig;
@property (weak, nonatomic) IBOutlet UIView *viewTools;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *constraintTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *constraintBottom;

@property NSString *bid;
@property NSString *tid;
@property NSArray *attachments;
@property NSString *defaultTitle;
@property NSString *defaultContent;
@property NSString *floor;
@property BOOL isEdit;
@property BOOL showEditOthersAlert;
@property NSString *defaultSigIndex;

@end
