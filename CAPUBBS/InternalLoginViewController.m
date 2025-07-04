//
//  InternalLoginViewController.m
//  CAPUBBS
//
//  Created by 熊典 on 14-2-20.
//  Copyright (c) 2014年 熊典. All rights reserved.
//

#import "InternalLoginViewController.h"
#import "LoginViewController.h"

@interface InternalLoginViewController ()

@end

@implementation InternalLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GRAY_PATTERN;
    UIView *targetView = self.navigationController ? self.navigationController.view : self.view;
    hud = [[MBProgressHUD alloc] initWithView:targetView];
    [targetView addSubview:hud];
    
    self.textUid.text = self.defaultUid;
    self.textPass.text = self.defaultPass;
    [self.buttonLogin.layer setCornerRadius:10.0];
    if (self.textUid.text.length == 0) {
        [self.textUid becomeFirstResponder];
    }
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (shouldPop == NO) {
        if (self.textUid.text.length > 0 && self.textPass.text.length > 0) {
            [self login:nil];
        }
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (IBAction)didEndOnExit:(UITextField*)sender {
    [self.textPass becomeFirstResponder];
}

- (IBAction)login:(id)sender {
    [self.textPass resignFirstResponder];
    [self.textUid resignFirstResponder];
    NSString *uid = self.textUid.text;
    NSString *pass = self.textPass.text;
    if (uid.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"用户名不能为空" cancelAction:^(UIAlertAction *action) {
            [self.textUid becomeFirstResponder];
        }];
        return;
    }
    if (pass.length == 0) {
        [self showAlertWithTitle:@"错误" message:@"密码不能为空" cancelAction:^(UIAlertAction *action) {
            [self.textPass becomeFirstResponder];
        }];
        return;
    }
    shouldPop = NO;
    [hud showWithProgressMessage:@"正在登录"];
    NSDictionary *dict = @{
        @"username" : uid,
        @"password" : [Helper md5:pass],
    };
    [Helper callApiWithParams:dict toURL:@"login" callback:^(NSArray *result, NSError *err) {
        if (err || result.count == 0) {
            [hud hideWithFailureMessage:@"登录失败"];
//            [self showAlertWithTitle:@"登录失败" message:[err localizedDescription]];
            return ;
        }
        int code = [result[0][@"code"] intValue];
        if (code == 0) {
            [hud hideWithSuccessMessage:@"登录成功"];
        } else {
            [hud hideWithFailureMessage:@"登录失败"];
        }
        if (code == 0) {
            if ([UID length] > 0 && ![uid isEqualToString:UID]) { // 注销之前的账号
                [Helper callApiWithParams:nil toURL:@"logout" callback:^(NSArray *result, NSError *err) {}];
                NSLog(@"Logout - %@", UID);
            }
            [GROUP_DEFAULTS setObject:uid forKey:@"uid"];
            [GROUP_DEFAULTS setObject:pass forKey:@"pass"];
            [GROUP_DEFAULTS setObject:result[0][@"token"] forKey:@"token"];
            [LoginViewController updateIDSaves];
            NSLog(@"Login - %@", uid);
            [NOTIFICATION postNotificationName:@"userChanged" object:nil userInfo:nil];
            shouldPop = YES;
            dispatch_main_after(0.5, ^{
                [self.navigationController popViewControllerAnimated:YES];
            });
            return;
        }
        if (code == 1) {
            [self showAlertWithTitle:@"登录失败" message:@"密码错误！" cancelAction:^(UIAlertAction *action) {
                [self.textPass becomeFirstResponder];
            }];
        } else if (code == 2) {
            [self showAlertWithTitle:@"登录失败" message:@"用户名不存在！" cancelAction:^(UIAlertAction *action) {
                [self.textUid becomeFirstResponder];
            }];
        } else {
            [self showAlertWithTitle:@"登录失败" message:@"发生未知错误！"];
        }
    }];
}

@end
