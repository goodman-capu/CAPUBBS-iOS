//
//  CommonDefinitions.h
//  CAPUBBS
//
//  Created by 范志康 on 2016/9/29.
//  Copyright © 2016年 熊典. All rights reserved.
//

#ifndef CommonDefinitions_h
#define CommonDefinitions_h

#define REPORT_EMAIL @[@"fa_pku@sina.com", @"beidachexie@163.com"]
#define FEEDBACK_EMAIL @[@"goodman.capu@qq.com", @"beidachexie@163.com"]
#define COPYRIGHT @"Copyright®  2001 - 2016\nPowered by：CAPU ver 3.0"
#define EULA @"本论坛作为北京大学自行车协会内部以及自行车爱好者之间交流平台，不欢迎任何商业广告和无关话题。发言者对自己发表的任何言论、信息负责。"

#define NUMBERS @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"9", @"28"]

#define NOTIFICATION [NSNotificationCenter defaultCenter]
#define DEFAULTS [NSUserDefaults standardUserDefaults]
#define MANAGER [NSFileManager defaultManager]
#define CHEXIE [DEFAULTS objectForKey:@"URL"]
#define UID [DEFAULTS objectForKey:@"uid"]
#define PASS [DEFAULTS objectForKey:@"pass"]
#define TOKEN [DEFAULTS objectForKey:@"token"]
#define USERINFO [DEFAULTS objectForKey:@"userInfo"]
#define BLUE [UIColor colorWithRed:45.0/255 green:144.0/255 blue:220.0/255 alpha:1.0]
#define GREEN_DARK [UIColor colorWithRed:115.0/255 green:170.0/255 blue:135.0/255 alpha:1.0]
#define GREEN_LIGHT [UIColor colorWithRed:154.0/255 green:191.0/255 blue:165.0/255 alpha:1.0]
#define GREEN_BACK [UIColor colorWithPatternImage:[UIImage imageNamed:@"背景色"]]
#define GRAY_PATTERN [UIColor colorWithPatternImage:[UIImage imageNamed:@"软件背景"]]
#define SUCCESSMARK [UIImage imageNamed:@"successmark"]
#define FAILMARK [UIImage imageNamed:@"failmark"]
#define QUESTIONMARK [UIImage imageNamed:@"questionmark"]
#define IOS [[[UIDevice currentDevice] systemVersion] floatValue]
#define BUNDLE_IDENTIFIER [[NSBundle mainBundle] bundleIdentifier]
#define IS_CELLULAR ([[Reachability reachabilityForLocalWiFi] currentReachabilityStatus] == NotReachable && [[Reachability reachabilityForInternetConnection] currentReachabilityStatus] != NotReachable)

#define MAX_ID_NUM 10
#define MAX_HOT_NUM 40
#define ID_NUM [[DEFAULTS objectForKey:@"IDNum"] intValue]
#define HOT_NUM [[DEFAULTS objectForKey:@"hotNum"] intValue]
#define IS_SUPER_USER (ID_NUM == MAX_ID_NUM && HOT_NUM == MAX_HOT_NUM)

#define dispatch_main_sync_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_sync(dispatch_get_main_queue(), block);\
}

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

#endif /* CommonDefinitions_h */
