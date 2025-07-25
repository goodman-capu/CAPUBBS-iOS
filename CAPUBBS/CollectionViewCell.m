//
//  CollectionViewCell.m
//  CAPUBBS
//
//  Created by 范志康 on 15/11/11.
//  Copyright © 2015年 熊典. All rights reserved.
//

#import "CollectionViewCell.h"

@implementation CollectionViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    self.backgroundColor = [UIColor clearColor];
    
    [self.icon setRounded:YES];
}

@end
