//
//  AppDelegate.h
//  CAPUBBS
//
//  Created by 熊典 on 14-2-16.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ActionPerformer.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    ActionPerformer *performer;
}

@property (strong, nonatomic) UIWindow *window;

@end
