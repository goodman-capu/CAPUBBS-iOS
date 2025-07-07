//
//  ContentCell.m
//  CAPUBBS
//
//  Created by 熊典 on 14-2-17.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "ContentCell.h"

@implementation ContentCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    self.backgroundColor = [UIColor clearColor];
    [self.icon setRounded:YES];
    self.webViewContainer.layer.cornerRadius = 10;
    self.webViewContainer.layer.borderColor = GREEN_LIGHT.CGColor;
    self.webViewContainer.layer.borderWidth = 1;
    self.webViewContainer.layer.masksToBounds = YES;
    self.webViewContainer.backgroundColor = [UIColor whiteColor];
    [self.webViewContainer initiateWebViewWithToken:NO];
    self.webViewContainer.webView.scrollView.scrollEnabled = NO;
    self.lzlTableView.backgroundColor = [UIColor clearColor];
}

- (void)dealloc {
    [self invalidateTimer];
}

- (void)invalidateTimer {
    if (self.webviewUpdateTimer && [self.webviewUpdateTimer isValid]) {
        [self.webviewUpdateTimer invalidate];
        self.webviewUpdateTimer = nil;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self invalidateTimer];
    // 加载空HTML以快速清空，防止reuse后还短暂显示之前的内容
    [self.webViewContainer.webView loadHTMLString:EMPTY_HTML baseURL:nil];
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath { 
    ContentLzlCell *cell = [tableView dequeueReusableCellWithIdentifier:@"lzl" forIndexPath:indexPath];
    NSDictionary *dict = self.lzlDetail[indexPath.row];
    cell.lzlAuthor.text = dict[@"author"];
    cell.lzlTime.text = dict[@"time"];
    // Fit into one line
    cell.lzlText.text = [dict[@"text"] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    [cell.lzlIcon setUrl:dict[@"icon"]];
    
    if (indexPath.row == [self tableView:tableView numberOfRowsInSection:indexPath.section] - 1) {
        cell.separatorInset = UIEdgeInsetsMake(0, 10000, 0, 0); // 隐藏
    } else {
        cell.separatorInset = UIEdgeInsetsZero; // 正常显示
    }
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.lzlDetail ? self.lzlDetail.count : 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.buttonLzl sendActionsForControlEvents:UIControlEventTouchUpInside];
}

@end

@implementation ContentLzlCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    self.backgroundColor = [UIColor clearColor];
    [self.lzlIcon setRounded:YES];
}

@end
