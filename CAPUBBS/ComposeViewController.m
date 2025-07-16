//
//  ComposeViewController.m
//  CAPUBBS
//
//  Created by 熊典 on 14-2-19.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "ComposeViewController.h"
#import <StoreKit/StoreKit.h>
#import "PreviewViewController.h"
#import "TextViewController.h"
#import "ContentViewController.h"
#import "AnimatedImageView.h"

@interface ComposeViewController ()

@end

@implementation ComposeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GRAY_PATTERN;
    self.textBody.layer.cornerRadius = 6;
    self.textBody.layer.borderColor = GREEN_LIGHT.CGColor;
    self.textBody.layer.borderWidth = 0.5;
    self.textBody.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    
    UIView *targetView = self.navigationController ? self.navigationController.view : self.view;
    hud = [[MBProgressHUD alloc] initWithView:targetView];
    [targetView addSubview:hud];
    
    [self initiateToolBar];
    if (!self.bid || [self.bid isEqualToString:@"hot"]) {
        self.bid = @"";
    }
    if (!self.tid) {
        self.tid = @"";
    }
    if (self.defaultContent) {
        self.textBody.text = self.defaultContent;
    } else {
        self.textBody.text = @"";
    }
    if (self.defaultTitle) {
        self.textTitle.text = self.defaultTitle;
    }
    
    [NOTIFICATION addObserver:self selector:@selector(keyboardChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [NOTIFICATION addObserver:self selector:@selector(insertContent:) name:@"addContent" object:nil];
    [NOTIFICATION addObserver:self selector:@selector(undo:) name:@"undo" object:nil];
    [NOTIFICATION addObserver:self selector:@selector(done:) name:@"publishContent" object:nil];

    if (self.tid.length == 0) {
        self.title = @"发表新帖";
        if ([BOARDS containsObject:self.bid]) {
            if (self.defaultTitle.length > 0) {
                [self.textBody becomeFirstResponder];
            } else {
                [self.textTitle becomeFirstResponder];
            }
        }
    } else {
        if (self.isEdit) {
            self.title = @"编辑帖子";
        } else {
            self.title = @"发表回复";
        }
        [self.textBody becomeFirstResponder];
    }
    [self updateAttachments];
    
    self.textTitle.delegate = self;
    self.textBody.delegate = self;
    if (self.defaultSigIndex.length > 0) {
        int sigIndex = [self.defaultSigIndex intValue];
        if (sigIndex >= 0 && sigIndex <= 3) {
            self.segmentSig.selectedSegmentIndex = sigIndex;
        }
    }
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateDismissable];
//    if (![[DEFAULTS objectForKey:@"FeatureText2.1"] boolValue]) {
//        [self showAlertWithTitle:@"新功能！" message:@"新增插入带颜色、字号、样式字体的功能" cancelTitle:@"我知道了"];
//        [DEFAULTS setObject:@(YES) forKey:@"FeatureText2.1"];
//    }
    if (![[DEFAULTS objectForKey:@"FeaturePreview2.2"] boolValue]) {
        [self showAlertWithTitle:@"Tips" message:@"发帖前可以预览，所见即所得\n向左滑动或者点击右上方小眼睛前往" cancelTitle:@"我知道了"];
        [DEFAULTS setObject:@(YES) forKey:@"FeaturePreview2.2"];
    }
    
    if (![Helper checkLogin:NO]) {
        [self showAlertWithTitle:@"错误" message:@"您未登录，请先登录再发帖" cancelAction:^(UIAlertAction *action) {
            [self dismiss];
        }];
        return;
    } else {
        [self checkBoard];
    }
    
    if (self.showEditOthersAlert) {
        [self showAlertWithTitle:@"您在编辑他人的帖子" message:@"如果成功发布，作者将被替换成您，签名档也将被替换。请确保您有权限操作！" cancelTitle:@"我知道了"];
        self.showEditOthersAlert = NO;
    }
    
    activity = [[NSUserActivity alloc] initWithActivityType:[BUNDLE_IDENTIFIER stringByAppendingString:@".compose"]];
    [self updateActivity];
    [activity becomeCurrent];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [activity invalidate];
}

- (void)updateActivity {
    if (self.bid.length > 0 && self.tid.length > 0) {
        activity.webpageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/bbs/content/?tid=%@&bid=%@", CHEXIE, self.tid, self.bid]];
    } else if (self.bid.length > 0) {
        activity.webpageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/bbs/main/?bid=%@", CHEXIE, self.bid]];
    } else {
        activity.webpageURL = nil;
    }
    activity.userInfo = self.isEdit ? @{
        @"type" : @"compose",
        @"title" : self.textTitle.text,
        @"content" : self.textBody.text,
        @"bid" : self.bid,
        @"tid" : self.tid,
        @"floor" : self.floor,
    } : @{
        @"type" : @"compose",
        @"title" : self.textTitle.text,
        @"content" : self.textBody.text,
        @"bid" : self.bid,
        @"tid" : self.tid,
    };
    activity.title = self.title;
}

- (BOOL)shouldDisableClose {
    NSString *title = self.textTitle.text;
    NSString *content = self.textBody.text;
    if (content.length > 0 && ![content isEqualToString:self.defaultContent] &&
        ![content isEqualToString:[DEFAULTS objectForKey:@"savedBody"]]) {
        return YES;
    }
    if (title.length > 0 && ![title isEqualToString:self.defaultTitle] &&
        ![title isEqualToString:[DEFAULTS objectForKey:@"savedTitle"]]) {
        return YES;
    }
    return NO;
}

- (void)updateDismissable {
    // 如果有输入文字，不允许点击外部关闭
    self.modalInPresentation = [self shouldDisableClose];
}

- (BOOL)checkBoard {
    if ([BOARDS containsObject:self.bid]) {
        return YES;
    }
    
    self.isEdit = NO;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"请选择发帖的版块" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (int i = 0; i < BOARDS.count; i++) {
        NSString *bid = BOARDS[i];
        [alertController addAction:[UIAlertAction actionWithTitle:[Helper getBoardTitle:bid] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.bid = bid;
            self.title = [NSString stringWithFormat:@"%@ @ %@", self.title, [Helper getBoardTitle:self.bid]];
            [self.textTitle becomeFirstResponder];
            [self updateActivity];
        }]];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self dismiss];
    }]];
    alertController.popoverPresentationController.sourceView = self.navigationController.navigationBar;
    alertController.popoverPresentationController.sourceRect = self.navigationController.navigationBar.bounds;
    [self presentViewControllerSafe:alertController];
    return NO;
}

- (void)updateAttachments {
    if (self.isEdit && self.attachments && self.attachments.count > 0) {
        [self.buttonAttachments setTitle:[NSString stringWithFormat:@"📎%ld", self.attachments.count] forState:UIControlStateNormal];
    } else {
        self.buttonAttachments.hidden = YES;
    }
}

- (NSString *)shortenFileName:(NSString *)name {
    NSString *fileName = [name stringByDeletingPathExtension];
    if (fileName.length > 15) {
        NSString *extension = [name pathExtension];
        NSString *prefix = [fileName substringToIndex:8];
        NSString *suffix = [fileName substringFromIndex:fileName.length - 4];
        name = [NSString stringWithFormat:@"%@...%@.%@", prefix, suffix, extension];
    }
    return name;
}

- (void)textViewDidChange:(UITextView *)textView {
    [self updateActivity];
    [self updateDismissable];
}

- (void)keyboardChange:(NSNotification *)info {
    CGRect keyboardFrame = [info.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval animationDuration = [info.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = [info.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16;
    
    // 将键盘坐标从 window 坐标系转换为当前 view 的坐标系
    CGRect keyboardFrameInView = [self.view convertRect:keyboardFrame fromView:nil];
    
    CGFloat overlap = CGRectGetMaxY(self.view.bounds) - keyboardFrameInView.origin.y;
    if (overlap < 0) {
        overlap = 0;
    }
    
    CGFloat bottomSafeAreaInset = self.view.safeAreaInsets.bottom;
    CGFloat newConstant = overlap - bottomSafeAreaInset;
    if (newConstant < 0) {
        newConstant = 0;
    }
    
    [UIView animateWithDuration:animationDuration delay:0 options:options animations:^{
        self.constraintBottom.constant = newConstant + 15;
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)initiateToolBar {
    toolbarEditor = [[DEFAULTS objectForKey:@"toolbarEditor"] intValue];
    keyboardToolView = [AppDelegate keyboardToolViewWithLeftButtons:@[
        [AppDelegate keyboardToolButtonWithTitle:@"📥" target:self action:@selector(saveDraft:)],
        [AppDelegate keyboardToolButtonWithTitle:@"📤" target:self action:@selector(restoreDraft:)]
    ] rightButtons:@[
        [AppDelegate keyboardToolButtonWithTitle:@"🔔" target:self action:@selector(addAt:)],
        [AppDelegate keyboardToolButtonWithTitle:@"🔗" target:self action:@selector(addLink:)],
        [AppDelegate keyboardToolButtonWithTitle:@"🎨" target:self action:@selector(addText:)],
        [AppDelegate keyboardToolButtonWithTitle:@"😀" target:self action:@selector(addFace:)],
        [AppDelegate keyboardToolButtonWithTitle:@"📷" target:self action:@selector(addPic:)]
    ]];
    
    [self showToolbar];
}

- (void)showToolbar {
    if (toolbarEditor == 0) {
        self.textBody.inputAccessoryView = nil;
        [self.viewTools setHidden:NO];
        self.constraintTop.constant = 66;
    } else if (toolbarEditor == 1) {
        self.textBody.inputAccessoryView = keyboardToolView;
        [self.viewTools setHidden:YES];
        self.constraintTop.constant = 8;
    } else if (toolbarEditor == 2) {
        self.textBody.inputAccessoryView = nil;
        [self.viewTools setHidden:YES];
        self.constraintTop.constant = 8;
    }
    [self.textBody reloadInputViews];
}

- (void)insert:(NSString *)content {
    [[self.textBody undoManager] beginUndoGrouping];
    [self.textBody insertText:content];
    [[self.textBody undoManager] endUndoGrouping];
}

- (void)insertContent:(NSNotification *)notification {
    [self insert:notification.userInfo[@"HTML"]];
}

- (void)undo:(NSNotification *)notification {
    dispatch_main_async_safe(^{
        [[self.textBody undoManager] undo];
    });
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (NSString *)getAttachsString {
    if (!self.attachments || self.attachments.count == 0) {
        return @"";
    }
    NSMutableArray *attachmentIds = [NSMutableArray array];
    for (NSDictionary *attachment in self.attachments) {
        [attachmentIds addObject:attachment[@"id"]];
    }
    return [attachmentIds componentsJoinedByString:@" "];
}

- (IBAction)done:(id)sender {
    if (self.textTitle.text.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"请输入标题！" cancelAction:^(UIAlertAction *action) {
            [self.textTitle becomeFirstResponder];
        }];
        return;
    }
    if (self.textBody.text.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"请输入帖子内容！" cancelAction:^(UIAlertAction *action) {
            [self.textBody becomeFirstResponder];
        }];
        return;
    }
    if (![self checkBoard]) {
        return;
    }
    [self.textTitle resignFirstResponder];
    [self.textBody resignFirstResponder];
    if ([[DEFAULTS objectForKey:@"autoSave"] boolValue]) // 自动保存
    {
        [DEFAULTS setObject:self.textTitle.text forKey:@"savedTitle"];
        [DEFAULTS setObject:self.textBody.text forKey:@"savedBody"];
    }
    [hud showWithProgressMessage:@"发表中"];
    NSString *content = [Helper toCompatibleFormat:self.textBody.text];
    NSDictionary *dict = self.isEdit ? @{
        @"bid" : self.bid,
        @"tid" : self.tid,
        @"title" : self.textTitle.text,
        @"text" : content,
        @"sig" : [NSString stringWithFormat:@"%ld", (long)self.segmentSig.selectedSegmentIndex],
        @"pid" : self.floor,
        @"attachs": [self getAttachsString]
    }: @{
        @"bid" : self.bid,
        @"tid" : self.tid,
        @"title" : self.textTitle.text,
        @"text" : content,
        @"sig" : [NSString stringWithFormat:@"%ld", (long)self.segmentSig.selectedSegmentIndex]
    };
    [Helper callApiWithParams:dict toURL:@"post" callback:^(NSArray *result, NSError *err) {
        if (err || result.count == 0) {
            NSLog(@"%@", err);
            [hud hideWithFailureMessage:@"发表失败"];
            return;
        }
        NSInteger code = [result[0][@"code"] integerValue];
        if (code == 0) {
            [hud hideWithSuccessMessage:@"发表成功"];
            [SKStoreReviewController requestReviewInScene:self.view.window.windowScene];
        } else {
            [hud hideWithFailureMessage:@"发表失败"];
        }
        switch (code) {
            case 0:{
                [NOTIFICATION postNotificationName:@"refreshContent" object:nil userInfo:@{
                    @"isEdit" : @(self.isEdit),
                    @"floor" : self.isEdit ? self.floor : @"",
                }];
                if (!self.isEdit) {
                    [NOTIFICATION postNotificationName:@"refreshList" object:nil userInfo:nil];
                }
                dispatch_main_after(0.5, ^{
                    [self dismiss];
                });
                break;
            }
            case 1:{
                [self showAlertWithTitle:@"错误" message:@"密码错误，请重新登录！"];
                break;
            }
            case 2:{
                [self showAlertWithTitle:@"错误" message:@"用户不存在，请重新登录！"];
                break;
            }
            case 3:{
                [self showAlertWithTitle:@"错误" message:@"您的账号被封禁，请联系管理员！"];
                break;
            }
            case 4:{
                [self showAlertWithTitle:@"错误" message:@"您的操作过频繁，请稍后再试！"];
                break;
            }
            case 5:{
                [self showAlertWithTitle:@"错误" message:@"文章被锁定，无法操作！"];
                break;
            }
            case 6:{
                [self showAlertWithTitle:@"错误" message:@"帖子不存在或服务器错误！"];
                break;
            }
            case 7:{
                [self showAlertWithTitle:@"错误" message:@"您的权限不够，无法操作！"];
                break;
            }
            case -25:{
                [self showAlertWithTitle:@"错误" message:@"您长时间未登录，请重新登录！"];
                break;
            }
            default:{
                [self showAlertWithTitle:@"错误" message:@"发生未知错误！"];
                break;
            }
        }
    }];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)shouldShowDismissWarning {
    NSString *title = self.textTitle.text;
    NSString *content = self.textBody.text;
    if (content.length > 0 && ![content isEqualToString:self.defaultContent] &&
        ![content isEqualToString:[DEFAULTS objectForKey:@"savedBody"]]) {
        return YES;
    }
    if (title.length > 0 && ![title isEqualToString:self.defaultTitle] &&
        ![title isEqualToString:[DEFAULTS objectForKey:@"savedTitle"]]) {
        return YES;
    }
    return NO;
}

- (IBAction)cancel:(id)sender {
    if ([self shouldDisableClose]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"确定退出" message:@"您有尚未发表的内容，建议先保存草稿，确定继续退出？" preferredStyle:UIAlertControllerStyleActionSheet];
        [alertController addAction:[UIAlertAction actionWithTitle:@"退出" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self dismiss];
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        if ([sender isKindOfClass:[UIBarButtonItem class]]) {
            alertController.popoverPresentationController.barButtonItem = sender;
        }
        [self presentViewControllerSafe:alertController];
    } else {
        [self dismiss];
    }
}

- (IBAction)addPic:(id)sender {
    if (self.presentedViewController) {
        return;
    }
    NSString *text = [self.textBody.text substringWithRange:self.textBody.selectedRange];
    if (text.length > 0) {
        NSRange range = self.textBody.selectedRange;
        self.textBody.text = [self.textBody.text stringByReplacingCharactersInRange:self.textBody.selectedRange withString:[NSString stringWithFormat:@"[img]%@[/img]", text]];
        range.length += 11;
        self.textBody.selectedRange = range;
        return;
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"选择图片来源" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:@"网址链接" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *alertControllerLink = [UIAlertController alertControllerWithTitle:@"插入照片"
                                                                       message:@"请输入图片链接"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        __weak typeof(alertControllerLink) weakAlertController = alertControllerLink; // 避免循环引用
        [alertControllerLink addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"链接";
            textField.keyboardType = UIKeyboardTypeURL;
        }];
        [alertControllerLink addAction:[UIAlertAction actionWithTitle:@"取消"
                                                  style:UIAlertActionStyleCancel
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self.textBody becomeFirstResponder];
        }]];
        [alertControllerLink addAction:[UIAlertAction actionWithTitle:@"插入"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            __strong typeof(weakAlertController) strongAlertController = weakAlertController;
            if (!strongAlertController) {
                return;
            }
            NSString *url = strongAlertController.textFields[0].text;
            [self insert:[NSString stringWithFormat:@"[img]%@[/img]", url]];
            [self.textBody becomeFirstResponder];
        }]];
        [self presentViewControllerSafe:alertControllerLink];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"照片图库" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = 20; // 最多一次选20张
        config.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewControllerSafe:picker];
    }]];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"拍照" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
            imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
            imagePicker.mediaTypes = @[UTTypeImage.identifier];
            imagePicker.delegate = self;
            [self presentViewControllerSafe:imagePicker];
        }]];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    UIButton *button = sender;
    alertController.popoverPresentationController.sourceView = button;
    alertController.popoverPresentationController.sourceRect = button.bounds;
    [self presentViewControllerSafe:alertController];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(nonnull NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    NSURL *imageUrl = info[UIImagePickerControllerImageURL];
    if ([MANAGER fileExistsAtPath:imageUrl.path]) {
        [MANAGER removeItemAtURL:imageUrl error:nil];
    }
    [picker dismissViewControllerAnimated:YES completion:^{
        [self.textTitle resignFirstResponder];
        [self.textBody resignFirstResponder];
        [self uploadOneImage:image withCallback:^(NSString *url) {
            dispatch_main_async_safe((^{
                if (url) {
                    [self insert:[NSString stringWithFormat:@"\n[img]%@[/img]\n",url]];
                }
                [self.textBody becomeFirstResponder];
            }));
        }];
    }];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    NSMutableArray<UIImage *> *selectedImages = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    
    for (PHPickerResult *result in results) {
        if ([result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
            dispatch_group_enter(group);
            [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage *image, NSError *error) {
                if (image) {
                    @synchronized (selectedImages) {
                        [selectedImages addObject:image];
                    }
                }
                dispatch_group_leave(group);
            }];
        }
    }
    
    [picker dismissViewControllerAnimated:YES completion:^{
        // 所有图片加载完后开始上传
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            [self.textTitle resignFirstResponder];
            [self.textBody resignFirstResponder];
            [self uploadImages:selectedImages index:0];
        });
    }];
}

- (void)uploadImages:(NSArray<UIImage *> *)images index:(NSInteger)index {
    if (index >= images.count) {
        [self.textBody becomeFirstResponder];
        return;
    }
    [self uploadOneImage:images[index] withCallback:^(NSString *url) {
        dispatch_main_async_safe((^{
            if (url) {
                [self insert:[NSString stringWithFormat:@"[img]%@[/img]",url]];
            }
            [self uploadImages:images index:index + 1];
        }));
    }];
}

- (void)uploadOneImage:(UIImage *)image withCallback:(void (^)(NSString *url))callback {
    if (!image || image.size.width == 0 || image.size.height == 0) {
        [self showAlertWithTitle:@"警告" message:@"图片不合法，无法获取长度 / 宽度！" confirmTitle:@"好" confirmAction:^(UIAlertAction *action) {
            callback(nil);
        }];
        return;
    }
    if (image.size.width <= 1000 && image.size.height <= 1000) {
        [self compressAndUploadImage:image withCallback:callback];
    } else {
        [self askForResizeImage:image withCallback:callback];
    }
}

CGSize scaledSizeForImage(UIImage *image, CGFloat maxLength) {
    if (!image) {
        return CGSizeZero;
    }

    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    CGFloat scale = (width > height) ? maxLength / width : maxLength / height;

    if (scale >= 1.0) {
        return CGSizeZero; // 原图太小，无需缩放
    }

    return CGSizeMake(width * scale, height * scale);
}


- (void)askForResizeImage:(UIImage *)image withCallback:(void (^)(NSString *url))callback {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"选择图片大小" message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    // 添加预览图
    // 1. 获取压缩后的图片
    UIImage *thumbnailImage = image;
    CGSize thumbnailSize = scaledSizeForImage(image, 500);
    if (!CGSizeEqualToSize(thumbnailSize, CGSizeZero)) {
        thumbnailImage = [self resizeImage:image toSize:thumbnailSize opaque:NO];
    }
    // 2. 创建图片附件 (Text Attachment)
    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    CGFloat targetHeight = 150.0;
    CGFloat targetCornerRadius = 8.0;
    CGFloat scaleFactor = thumbnailImage.size.height / targetHeight;
    attachment.image = [thumbnailImage imageByApplyingCornerRadius:targetCornerRadius * scaleFactor];
    attachment.bounds = CGRectMake(0, 0, targetHeight * attachment.image.size.width / attachment.image.size.height, targetHeight); // 保持图片宽高比
    // 3. 将附件转为富文本
    NSAttributedString *imageAttributedString = [NSAttributedString attributedStringWithAttachment:attachment];
    // 4. 创建完整的富文本消息
    NSMutableAttributedString *finalMessage = [[NSMutableAttributedString alloc] initWithString:@"\n"];
    [finalMessage appendAttributedString:imageAttributedString];
    // 5. 使用 KVC 设置 attributedMessage
    [alertController setValue:finalMessage forKey:@"attributedMessage"];

    int recommendedSizes = 0;
    // 多种缩图尺寸（最长边限制）
    for (NSNumber *size in @[@800, @1600, @2400]) {
        CGSize newSize = scaledSizeForImage(image, size.floatValue);
        if (CGSizeEqualToSize(newSize, CGSizeZero)) {
            continue; // 跳过，无需缩放
        }
        NSString *title = [NSString stringWithFormat:@"压缩图 (%d×%d)", (int)newSize.width, (int)newSize.height];
        [alertController addAction:[UIAlertAction actionWithTitle:title
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
            UIImage *resizedImage = [self resizeImage:image toSize:newSize opaque:![image hasAlphaChannel:YES]];
            [self compressAndUploadImage:resizedImage withCallback:callback];
        }]];
        recommendedSizes++;
    }
    [alertController addAction:[UIAlertAction actionWithTitle: [NSString stringWithFormat:@"原图 (%d×%d)", (int)image.size.width, (int)image.size.height]
                                                        style:recommendedSizes >= 3 ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        [self compressAndUploadImage:image withCallback:callback];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消上传" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        callback(nil);
    }]];
    [self presentViewControllerSafe:alertController];
}

- (void)compressAndUploadImage:(UIImage *)image withCallback:(void (^)(NSString *url))callback {
    [hud showWithProgressMessage:@"正在压缩"];
    dispatch_global_default_async(^{
        NSData *imageData;
        if ([image hasAlphaChannel:YES]) { // 带透明信息的png不可转换成jpeg否则丢失透明性
            imageData = UIImagePNGRepresentation(image);
        } else {
            float maxLength = IS_SUPER_USER ? 500 : 300;
            float ratio = 0.75;
            imageData = UIImageJPEGRepresentation(image, ratio);
            while (imageData.length >= maxLength * 1024 && ratio >= 0.2) {
                ratio *= 0.75;
                imageData = UIImageJPEGRepresentation(image, ratio);
            }
        }
        NSLog(@"Upload Image Size: %dkB", (int)imageData.length / 1024);
        if (imageData.length > 1024 * 1024) { // 1MB
            [hud hideWithFailureMessage:@"文件太大"];
            callback(nil);
            return;
        }
        
        NSString *extension = [AnimatedImageView fileExtension:[AnimatedImageView fileType:imageData]];
        [hud showWithProgressMessage:@"正在上传"];
        [Helper callApiWithParams:@{@"type": @"image", @"extension": extension, @"file": imageData} toURL:@"upload" callback:^(NSArray *result, NSError *err) {
            if (err || result.count == 0) {
                [hud hideWithFailureMessage:@"上传失败"];
                callback(nil);
                return;
            }
            int code = [result[0][@"code"] intValue];
            if (code == -1) {
                [hud hideWithSuccessMessage:@"上传成功"];
                callback(result[0][@"url"]);
            } else {
                [hud hideWithFailureMessage:code == 1 ? @"文件太大" : @"上传失败"];
                callback(nil);
            }
        }];
    });
}

- (UIImage *)resizeImage:(UIImage *)oriImage toSize:(CGSize)newSize opaque:(BOOL)opaque {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(newSize.width, newSize.height), opaque, 0);
    [oriImage drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage;
}

- (IBAction)enterPressed:(id)sender {
    [self.textBody becomeFirstResponder];
}

- (IBAction)saveDraft:(id)sender {
    if (self.presentedViewController) {
        return;
    }
    [self showAlertWithTitle:@"确认保存" message:@"保存草稿会覆盖之前的存档\n确定要继续吗？" confirmTitle:@"保存" confirmAction:^(UIAlertAction *action) {
        [self save];
        [hud showAndHideWithSuccessMessage:@"保存成功"];
    }];
}

- (IBAction)restoreDraft:(id)sender {
    if (self.presentedViewController) {
        return;
    }
    if ([[DEFAULTS objectForKey:@"savedTitle"] length] == 0 && [[DEFAULTS objectForKey:@"savedBody"] length] == 0) {
        [self showAlertWithTitle:@"错误" message:@"您还没有保存草稿"];
    } else {
        [self showAlertWithTitle:@"警告" message:@"恢复草稿会失去当前编辑的内容\n确定要继续吗？" confirmTitle:@"恢复" confirmAction:^(UIAlertAction *action) {
            if (self.textTitle.text.length > 0 && ![[DEFAULTS objectForKey:@"savedTitle"] isEqualToString:self.textTitle.text]) {
                [self showAlertWithTitle:@"检测到冲突！" message:[NSString stringWithFormat:@"草稿标题为：%@\n与当前标题不一致！\n请选择操作：", [DEFAULTS objectForKey:@"savedTitle"]] confirmTitle:@"继续恢复" confirmAction:^(UIAlertAction *action) {
                    [self restore];
                } cancelTitle:@"放弃恢复"];
            } else {
                [self restore];
            }
        }];
    }
}

- (void)save {
    [DEFAULTS setObject:self.textTitle.text forKey:@"savedTitle"];
    [DEFAULTS setObject:self.textBody.text forKey:@"savedBody"];
    self.restoreDraft.enabled = YES;
    [self updateDismissable];
    if ([[DEFAULTS objectForKey:@"savedTitle"] length] == 0 && [[DEFAULTS objectForKey:@"savedBody"] length] == 0) {
        self.restoreDraft.enabled = NO;
    }
}

- (void)restore {
    self.textTitle.text = [DEFAULTS objectForKey:@"savedTitle"];
    self.textBody.text = [DEFAULTS objectForKey:@"savedBody"];
    [self.textBody becomeFirstResponder];
    [self updateDismissable];
    [hud showAndHideWithSuccessMessage:@"恢复成功"];
}

- (IBAction)addAt:(id)sender {
    if (self.presentedViewController) {
        return;
    }
    NSString *text = [self.textBody.text substringWithRange:self.textBody.selectedRange];
    if (text.length > 0) {
        [self insert:[NSString stringWithFormat:@"[at]%@[/at]", text]];
        return;
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"插入@/引用"
                                                                   message:@"请输入用户和正文\n正文若为空将使用@形式"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(alertController) weakAlertController = alertController; // 避免循环引用
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"用户";
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"正文";
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"插入"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakAlertController) strongAlertController = weakAlertController;
        if (!strongAlertController) {
            return;
        }
        NSString *user = strongAlertController.textFields[0].text;
        NSString *body = strongAlertController.textFields[1].text;
        if (user.length == 0) {
            [self showAlertWithTitle:@"错误" message:@"用户不能为空"];
            return;
        }
        [self insert:body.length == 0 ? [NSString stringWithFormat:@"[at]%@[/at]", user] : [NSString stringWithFormat:@"[quote=%@]%@[/quote]\n", user, body]];
    }]];
    [self presentViewControllerSafe:alertController];
}

- (IBAction)addLink:(id)sender {
    if (self.presentedViewController) {
        return;
    }
    NSString *text = [self.textBody.text substringWithRange:self.textBody.selectedRange];
    if (text.length > 0) {
        NSString *textLower = text.lowercaseString;
        if ([textLower hasPrefix:@"http://"] || [textLower hasPrefix:@"https://"] || [textLower hasPrefix:@"/"]) {
            [self insert:[NSString stringWithFormat:@"[url]%@[/url]", text]];
            return;
        }
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"插入链接"
                                                                   message:@"请输入链接的标题和网址"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(alertController) weakAlertController = alertController; // 避免循环引用
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"标题";
        textField.text = text;
    }];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"网址";
        textField.keyboardType = UIKeyboardTypeURL;
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"插入"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakAlertController) strongAlertController = weakAlertController;
        if (!strongAlertController) {
            return;
        }
        NSString *title = strongAlertController.textFields[0].text;
        NSString *url = strongAlertController.textFields[1].text;
        if (url.length == 0) {
            [self showAlertWithTitle:@"错误" message:@"网址不能为空"];
            return;
        }
        [self insert:title.length > 0 ? [NSString stringWithFormat:@"[url=%@]%@[/url]", url, title] : [NSString stringWithFormat:@"[url]%@[/url]", url]];
    }]];
    [self presentViewControllerSafe:alertController];
}

- (void)addText:(id)sender {
    if (self.presentedViewController) {
        return;
    }
    [self performSegueWithIdentifier:@"addText" sender:sender];
}

- (void)addFace:(id)sender {
    if (self.presentedViewController) {
        return;
    }
    [self performSegueWithIdentifier:@"addFace" sender:sender];
}

-(void)clearWithFunction:(NSString *(^)(NSString *text))function {
    [self save];
    if (self.textBody.selectedRange.length > 0) {
        [self.textBody replaceRange:self.textBody.selectedTextRange withText:function([self.textBody.text substringWithRange:self.textBody.selectedRange])];
    } else {
        self.textBody.text = function(self.textBody.text);
    }
    [hud showAndHideWithSuccessMessage:@"清除成功"];
}

- (IBAction)seeAttachment:(id)sender {
    if (!self.isEdit || !self.attachments || self.attachments.count == 0) {
        return;
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"请选择对附件的操作" message:@"暂不支持上传附件。如果您需要上传附件，请前往网页版。" preferredStyle:UIAlertControllerStyleActionSheet];
    NSMutableArray *infos = [NSMutableArray array];
    for (NSDictionary *attachment in self.attachments) {
        NSString *shortName = [self shortenFileName:attachment[@"name"]];
        NSString *info = [NSString stringWithFormat:@"%@ (%@)", shortName, [Helper fileSize:[attachment[@"size"] intValue]]];
        [infos addObject:info];
        [alertController addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"删除：%@", shortName]
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
            [self showAlertWithTitle:@"确认删除附件" message:info confirmTitle:@"删除" confirmAction:^(UIAlertAction *action) {
                NSMutableArray *newAttachments = [self.attachments mutableCopy];
                [newAttachments removeObject:attachment];
                self.attachments = [newAttachments copy];
                [self updateAttachments];
            }];
        }]];
    }
    if (self.attachments.count > 1) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"删除所有附件"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
            [self showAlertWithTitle:@"确认删除所有附件" message:[infos componentsJoinedByString:@"\n"] confirmTitle:@"删除" confirmAction:^(UIAlertAction *action) {
                self.attachments = @[];
                [self updateAttachments];
            }];
        }]];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIButton *button = sender;
    alertController.popoverPresentationController.sourceView = button;
    alertController.popoverPresentationController.sourceRect = button.bounds;
    [self presentViewControllerSafe:alertController];
}

- (IBAction)clearFormat:(id)sender {
    NSString *hint = self.textBody.selectedRange.length > 0 ? @"选定范围" : @"所有";
    [self.textTitle resignFirstResponder];
    [self.textBody resignFirstResponder];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"请选择操作" message:@"清除前会自动保存草稿\n发帖前建议预览以确保格式正确" preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:@"清除HTML标签"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction * _Nonnull action) {
        [self showAlertWithTitle:@"提示" message:[NSString stringWithFormat:@"确认要清除%@的HTML标签吗？\n图片、链接、字体、颜色等会被尽量保留", hint] confirmTitle:@"清除" confirmAction:^(UIAlertAction *action) {
            [self clearWithFunction:^NSString *(NSString *text) {
                return [Helper removeHTML:text restoreFormat:YES];
            }];
        }];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"清除文字字体"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction * _Nonnull action) {
        [self showAlertWithTitle:@"提示" message:[NSString stringWithFormat:@"确认要清除%@的字体 [font] 标记吗", hint] confirmTitle:@"清除" confirmAction:^(UIAlertAction *action) {
            [self clearWithFunction:^NSString *(NSString *text) {
                return [text stringByReplacingOccurrencesOfString:@"\\[/?font(?:=[^\\]]+)?\\]"
                                                                    withString:@""
                                                                       options:NSRegularExpressionSearch
                                                                         range:NSMakeRange(0, text.length)];
            }];
        }];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"清除文字大小"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction * _Nonnull action) {
        [self showAlertWithTitle:@"提示" message:[NSString stringWithFormat:@"确认要清除%@的大小 [size] 标记吗", hint] confirmTitle:@"清除" confirmAction:^(UIAlertAction *action) {
            [self clearWithFunction:^NSString *(NSString *text) {
                return [text stringByReplacingOccurrencesOfString:@"\\[/?size(?:=[^\\]]+)?\\]"
                                                                    withString:@""
                                                                       options:NSRegularExpressionSearch
                                                                         range:NSMakeRange(0, text.length)];
            }];
        }];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"清除文字颜色"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction * _Nonnull action) {
        [self showAlertWithTitle:@"提示" message:[NSString stringWithFormat:@"确认要清除%@的颜色 [color] 标记吗", hint] confirmTitle:@"清除" confirmAction:^(UIAlertAction *action) {
            [self clearWithFunction:^NSString *(NSString *text) {
                return [text stringByReplacingOccurrencesOfString:@"\\[/?color(?:=[^\\]]+)?\\]"
                                                                    withString:@""
                                                                       options:NSRegularExpressionSearch
                                                                         range:NSMakeRange(0, text.length)];
            }];
        }];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"清除文字粗体"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction * _Nonnull action) {
        [self showAlertWithTitle:@"提示" message:[NSString stringWithFormat:@"确认要清除%@的粗体 [b] 标记吗", hint] confirmTitle:@"清除" confirmAction:^(UIAlertAction *action) {
            [self clearWithFunction:^NSString *(NSString *text) {
                return [text stringByReplacingOccurrencesOfString:@"\\[/?b\\]"
                                                                    withString:@""
                                                                       options:NSRegularExpressionSearch
                                                                         range:NSMakeRange(0, text.length)];
            }];
        }];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"清除文字斜体"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction * _Nonnull action) {
        [self showAlertWithTitle:@"提示" message:[NSString stringWithFormat:@"确认要清除%@的斜体 [i] 标记吗", hint] confirmTitle:@"清除" confirmAction:^(UIAlertAction *action) {
            [self clearWithFunction:^NSString *(NSString *text) {
                return [text stringByReplacingOccurrencesOfString:@"\\[/?i\\]"
                                                                    withString:@""
                                                                       options:NSRegularExpressionSearch
                                                                         range:NSMakeRange(0, text.length)];
            }];
        }];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UIButton *button = sender;
    alertController.popoverPresentationController.sourceView = button;
    alertController.popoverPresentationController.sourceRect = button.bounds;
    [self presentViewControllerSafe:alertController];
}

- (IBAction)setToolbar:(id)sender {
    toolbarEditor = (toolbarEditor + 1) % 3;
    [self showToolbar];
}

- (IBAction)swipeLeft:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self performSegueWithIdentifier:@"preview" sender:nil];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"preview"]) {
        PreviewViewController *dest = [segue destinationViewController];
        dest.textTitle = self.textTitle.text;
        dest.textBody = self.textBody.text;
        dest.attachments = self.attachments;
        dest.sig = (int)self.segmentSig.selectedSegmentIndex;
    }
    if ([segue.identifier isEqualToString:@"addText"] || [segue.identifier isEqualToString:@"addFace"]) {
        UIViewController *dest = [[[segue destinationViewController] viewControllers] firstObject];
        UIView *source;
        if (toolbarEditor == 0 && sender && [sender isKindOfClass:[UIView class]]) {
            source = sender;
        } else {
            source = self.buttonTools;
        }
        [AppDelegate setAdaptiveSheetFor:dest popoverSource:source halfScreen:YES];
    }
    if ([segue.identifier isEqualToString:@"addText"]) {
        TextViewController *dest = [[[segue destinationViewController] viewControllers] firstObject];
        dest.defaultText = [self.textBody.text substringWithRange:self.textBody.selectedRange];
    }
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

@end
