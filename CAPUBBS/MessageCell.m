//
//  MessageCell.m
//  CAPUBBS
//
//  Created by 范志康 on 15/4/17.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import "MessageCell.h"

@implementation MessageCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    self.backgroundColor = [UIColor clearColor];
    
    [self.imageIcon setRounded:YES];
    self.labelNum.layer.masksToBounds = YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self.labelNum layoutIfNeeded];
    self.labelNum.layer.cornerRadius = self.labelNum.frame.size.height / 2; // 圆形
}

@end
