//
//  CommonDefinitions.h
//  CAPUBBS
//
//  Created by 范志康 on 2016/9/29.
//  Copyright © 2016年 熊典. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef CommonDefinitions_h
#define CommonDefinitions_h

#define DEFAULT_SERVER_URL @"https://www.chexie.net"
#define APP_GROUP_IDENTIFIER @"group.net.chexie.capubbs"

#define REPORT_EMAIL @[@"beidachexie@163.com"]
#define FEEDBACK_EMAIL @[@"goodman.capu@gmail.com", @"beidachexie@163.com"]
#define COPYRIGHT @"Copyright®  2001 - 2025\nPowered by：CAPU ver 3.0"
#define EULA @"本论坛作为北京大学自行车协会内部以及自行车爱好者之间交流平台，不欢迎任何商业广告和无关话题。\n用户对自己发布的所有言论、图片和信息内容承担全部法律和道德责任，禁止发布违法、虚假、侵权、骚扰、攻击性或其他不当内容。\n本平台对上述内容实行零容忍政策。管理员有权删除相关内容，并视情况禁言或封禁用户。\n您可以举报违规内容或行为，管理员会在24小时内处理举报请求。\n继续使用即表示您已阅读并同意遵守本协议。"

#define BOARDS @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"9", @"28"]
#define BOARD_TITLE_MAP @{@"1": @"车协工作区", @"2": @"行者足音", @"3": @"车友宝典", @"4": @"纯净水", @"5": @"考察与社会", @"6": @"五湖四海", @"7": @"一技之长", @"9": @"竞赛竞技", @"28": @"网站维护"}

#define NOTIFICATION [NSNotificationCenter defaultCenter]
#define MANAGER [NSFileManager defaultManager]
#define DEFAULTS [NSUserDefaults standardUserDefaults]
#define GROUP_DEFAULTS [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_IDENTIFIER]
#define CHEXIE [GROUP_DEFAULTS objectForKey:@"URL"]
#define UID [GROUP_DEFAULTS objectForKey:@"uid"]
#define PASS [GROUP_DEFAULTS objectForKey:@"pass"]
#define TOKEN [GROUP_DEFAULTS objectForKey:@"token"]
#define USERINFO [GROUP_DEFAULTS objectForKey:@"userInfo"]
#define HOTPOSTS [GROUP_DEFAULTS objectForKey:@"hotPosts"]
#define SIMPLE_VIEW [[GROUP_DEFAULTS objectForKey:@"simpleView"] boolValue]

#define BLUE [UIColor colorWithRed:45.0/255 green:144.0/255 blue:220.0/255 alpha:1.0]
#define GREEN_DARK [UIColor colorWithRed:115.0/255 green:170.0/255 blue:135.0/255 alpha:1.0]
#define GREEN_LIGHT [UIColor colorWithRed:154.0/255 green:191.0/255 blue:165.0/255 alpha:1.0]
#define GREEN_BACK [UIColor colorWithRed:221.0/255 green:236.0/255 blue:222.0/255 alpha:1.0]
#define GRAY_PATTERN [UIColor colorWithPatternImage:[UIImage imageNamed:@"软件背景"]]
#define SUCCESSMARK [UIImage imageNamed:@"successmark"]
#define FAILMARK [UIImage imageNamed:@"failmark"]
#define QUESTIONMARK [UIImage imageNamed:@"questionmark"]
#define PLACEHOLDER [UIImage imageNamed:@"placeholder"]
#define CACHE_DIRECTORY [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]
#define IMAGE_CACHE_PATH [CACHE_DIRECTORY stringByAppendingString:@"/IconCache"]
#define ICON_NAMES @[@"dahlia.jpeg", @"whiterose.jpeg", @"red%20rose.jpeg", @"bowling.jpeg", @"yellow%20daisy.jpeg", @"snowflake.jpeg", @"zebra.jpeg", @"football.jpeg", @"smack.jpeg", @"target.jpeg", @"gingerbread%20man.jpeg", @"leaf.jpeg", @"soccer.jpeg", @"poppy.jpeg", @"earth.jpeg", @"turntable.jpeg", @"nest.jpeg", @"piano.jpeg", @"penguin.jpeg", @"dandelion.jpeg", @"lotus.jpeg", @"drum.jpeg", @"basketball.jpeg", @"ying%20yang.jpeg", @"sandollar.jpeg", @"flower.jpeg", @"owl.jpeg", @"zen.jpeg", @"medal.jpeg", @"sunflower.jpeg", @"fortune%20cookie.jpeg", @"cactus.jpeg", @"parrot.jpeg", @"hockey.jpeg", @"guitar.jpeg", @"violin.jpeg", @"baseball.jpeg", @"lightning.jpeg", @"chalk.jpeg", @"8ball.jpeg", @"eagle.jpeg", @"tennis.jpeg", @"golf.jpeg"]

#define BUNDLE_IDENTIFIER [[NSBundle mainBundle] bundleIdentifier]
#define APP_VERSION [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]
#define APP_BUILD [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]
#define IS_CELLULAR ([ReachabilityManager sharedManager].currentNetworkType == NetworkTypeCellular)

#define MAX_ID_NUM 10
#define MAX_HOT_NUM 40
#define ID_NUM [[DEFAULTS objectForKey:@"IDNum"] intValue]
#define HOT_NUM [[DEFAULTS objectForKey:@"hotNum"] intValue]
#define IS_SUPER_USER (ID_NUM == MAX_ID_NUM && HOT_NUM == MAX_HOT_NUM)

static inline void dispatch_main_async_safe(dispatch_block_t block) {
    dispatch_async(dispatch_get_main_queue(), block);
}

static inline void dispatch_main_sync_safe(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

static inline void dispatch_global_default_async(dispatch_block_t block) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), block);
}

static inline void dispatch_main_after(double seconds, dispatch_block_t block) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

static inline void dispatch_global_after(double seconds, dispatch_block_t block) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), block);
}

#define WEB_VIEW_MAX_HEIGHT 100000
#define EMPTY_HTML @"<html><head></head><body></body></html>"
#define JQUERY_MIN_JS [[NSBundle mainBundle] pathForResource:@"jquery.min" ofType:@"js"]
#define INJECTION_JS [[NSBundle mainBundle] pathForResource:@"injection" ofType:@"js"]
#define SALT @"3UhvI9LXQy69lrUd" // Never change it

#endif /* CommonDefinitions_h */
