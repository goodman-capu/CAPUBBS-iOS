//
//  LzlCell.m
//  CAPUBBS
//
//  Created by XiongDian on 14/9/21.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "LzlCell.h"

@implementation LzlCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    self.backgroundColor = [UIColor clearColor];
    self.textMain.backgroundColor = [UIColor clearColor];
    
    self.imageBottom.alpha = 0.8;
    [self.icon setRounded:YES];
    self.textPost.layer.cornerRadius = 10;
    self.textPost.scrollsToTop = NO;
}

@end
