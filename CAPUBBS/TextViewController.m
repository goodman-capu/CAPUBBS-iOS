//
//  TextViewController.m
//  CAPUBBS
//
//  Created by 范志康 on 15/3/29.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import "TextViewController.h"

#define DEFAULT_COLOR 10
#define DEFAULT_FONT_SIZE 3


@interface TextViewController ()

@end

@implementation TextViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GRAY_PATTERN;
    self.preferredContentSize = CGSizeMake(400, 0);
    UIView *targetView = self.navigationController ? self.navigationController.view : self.view;
    hud = [[MBProgressHUD alloc] initWithView:targetView];
    [targetView addSubview:hud];
    
    self.textInput.backgroundColor = [UIColor clearColor];
    self.textInput.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    self.textInput.text = self.defaultText;
    self.textInput.delegate = self;
    
    colors = @[[UIColor redColor], [UIColor orangeColor], [UIColor yellowColor], [UIColor greenColor], [UIColor cyanColor], [UIColor blueColor], [UIColor purpleColor], [UIColor whiteColor], [UIColor grayColor], [UIColor blackColor], [UIColor blackColor]];
    colorNames = @[@"red", @"orange", @"yellow", @"green", @"cyan", @"blue", @"purple", @"white", @"gray", @"black", @"default"];
    fontSizes = @[@10, @13, @16, @16, @18, @24, @32, @48];
    fontNames = @[@"ArialMT", @"Arial-BoldMT"];
    
    [self setDefault];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.dragging) {
        [self.view endEditing:YES];
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    [self updateInfo];
}

- (BOOL)shouldDisableClose {
    NSString *text = [self getInsertText];
    return ![text isEqualToString:self.textInput.text] || ![self.textInput.text isEqualToString:self.defaultText];
}

- (void)updateInfo {
    self.title = numberOfInserts > 0 ? [NSString stringWithFormat:@"已插入%d个样式", numberOfInserts] : @"插入样式";
    self.buttonUndo.enabled = numberOfInserts > 0;
    self.modalInPresentation = [self shouldDisableClose];
    
    NSString *previewText = self.textInput.text.length > 0 ? self.textInput.text : @"北大车协 CAPU";
    NSMutableAttributedString *textPreview = [[NSMutableAttributedString alloc] initWithString:previewText];
    int size = [[fontSizes objectAtIndex:fontSize] intValue];
    NSRange range = NSMakeRange(0, textPreview.length);
    
    [textPreview addAttribute:NSForegroundColorAttributeName value:[colors objectAtIndex:color] range:range];
    if ([[colorNames objectAtIndex:color] isEqualToString:@"white"]) {
        [self.labelPreview setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.2]];
    } else {
        [self.labelPreview setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.2]];
    }
    UIFontDescriptor *desc = [UIFontDescriptor fontDescriptorWithName:[fontNames objectAtIndex:isBold] size:size];
    if (isItalics) {
        CGAffineTransform matrix = CGAffineTransformMake(1, 0, tanf(15 * (CGFloat)M_PI / 180), 1, 0, 0);
        desc = [UIFontDescriptor fontDescriptorWithName:[fontNames objectAtIndex:isBold] matrix:matrix];
    }
    [textPreview addAttribute:NSFontAttributeName value:[UIFont fontWithDescriptor:desc size:size] range:range];
    if (isUnderscore) {
        [textPreview addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
    }
    if (isDelete) {
        [textPreview addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
    }
    
    //NSLog(@"Update Status");
    self.labelPreview.attributedText = textPreview;
}

- (NSString *)getInsertText {
    NSString *text = self.textInput.text;
    if (text.length == 0) {
        return text;
    }
    if (fontSize != DEFAULT_FONT_SIZE) {
        text = [NSString stringWithFormat:@"[size=%d]%@[/size]", [self getActualFontSize], text];
    }
    if (color != DEFAULT_COLOR) {
        text = [NSString stringWithFormat:@"[color=%@]%@[/color]", [colorNames objectAtIndex:color], text];
    }
    if (isBold) {
        text = [NSString stringWithFormat:@"[b]%@[/b]", text];
    }
    if (isItalics) {
        text = [NSString stringWithFormat:@"[i]%@[/i]", text];
    }
    if (isUnderscore) {
        text = [NSString stringWithFormat:@"<u>%@</u>", text];
    }
    if (isDelete) {
        text = [NSString stringWithFormat:@"<strike>%@</strike>", text];
    }
    return text;
}

- (int)getActualFontSize {
    return fontSize >= 3 ? fontSize : fontSize + 1;
}

- (void)setFontLabel {
    if (fontSize == 3) {
        self.labelSize.text = @"默认";
    } else {
        self.labelSize.text = [NSString stringWithFormat:@"%d号", [self getActualFontSize]];
    }
}

- (void)setDefault {
    color = DEFAULT_COLOR;
    fontSize = DEFAULT_FONT_SIZE;
    isBold = NO;
    isItalics = NO;
    isUnderscore = NO;
    isDelete = NO;
    [self.segmentColor setSelectedSegmentIndex:color];
    [self.sliderSize setValue:fontSize];
    [self setFontLabel];
    [self.switchBold setOn:isBold];
    [self.switchItalics setOn:isItalics];
    [self.switchUnderscore setOn:isUnderscore];
    [self.switchDelete setOn:isDelete];
    [self updateInfo];
}

- (IBAction)changeColor:(UISegmentedControl *)sender {
    color = (int)sender.selectedSegmentIndex;
    [self updateInfo];
}

- (IBAction)changeSize:(UISlider *)sender {
    int oriSize = fontSize;
    fontSize = round(sender.value);
    [sender setValue:fontSize];
    if (fontSize != oriSize) {
        [self setFontLabel];
        [self updateInfo];
    }
}

- (IBAction)changeBold:(id)sender {
    isBold = self.switchBold.isOn;
    [self updateInfo];
}

- (IBAction)changeItalics:(id)sender {
    isItalics = self.switchItalics.isOn;
    [self updateInfo];
}

- (IBAction)changeUnderscore:(id)sender {
    isUnderscore = self.switchUnderscore.isOn;
    [self updateInfo];
}

- (IBAction)changeDelete:(id)sender {
    isDelete = self.switchDelete.isOn;
    [self updateInfo];
}

- (IBAction)done:(id)sender {
    if ([self shouldDisableClose]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"确定退出" message:@"您有尚未插入的内容，确定继续退出？" preferredStyle:UIAlertControllerStyleActionSheet];
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

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)undo:(id)sender {
    [NOTIFICATION postNotificationName:@"undo" object:nil];
    numberOfInserts--;
    [self updateInfo];
}

- (IBAction)addText:(id)sender {
    NSString *text = [self getInsertText];
    if (text.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"您还未输入正文内容" cancelAction:^(UIAlertAction *action) {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
            dispatch_main_after(0.5, ^{
                [self.textInput becomeFirstResponder];
            });
        }];
        return;
    }
    if ([text isEqualToString:self.textInput.text]) {
        [self showAlertWithTitle:@"错误" message:@"您还未选择任何字体样式"];
        return;
    }
    
    numberOfInserts++;
    [self updateInfo];
    [NOTIFICATION postNotificationName:@"addContent" object:nil userInfo:@{ @"HTML" : text }];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"插入成功" message:@"是否继续操作？" preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:@"清空输入并继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.textInput.text = @"";
        [self updateInfo];
        [self.textInput becomeFirstResponder];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"直接继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.textInput becomeFirstResponder];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"返回发帖" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    alertController.popoverPresentationController.barButtonItem = self.buttonAdd;
    [self presentViewControllerSafe:alertController];
}

#pragma mark - Table view data source

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        [self setDefault];
        [hud showAndHideWithSuccessMessage:@"恢复默认"];
    }
}

@end
