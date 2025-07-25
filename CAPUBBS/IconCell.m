//
//  IconCell.m
//  CAPUBBS
//
//  Created by 范志康 on 15/3/17.
//  Copyright (c) 2015年 熊典. All rights reserved.
//

#import "IconCell.h"

@implementation IconCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    self.backgroundColor = [UIColor clearColor];
    
    self.icon.layer.borderColor = GREEN_LIGHT.CGColor;
    [self.icon setRounded:YES];
}

@end
