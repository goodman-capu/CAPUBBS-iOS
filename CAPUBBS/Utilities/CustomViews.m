//
//  CustomViews.m
//  CAPUBBS
//
//  Created by Zhikang Fan on 9/26/25.
//  Copyright © 2025 熊典. All rights reserved.
//

#import "CustomViews.h"

@implementation UIView (LiquidGlass)

- (void)applyLiquidGlassWithCorner:(UICornerConfiguration *)corner
                             clear:(BOOL)clear
                       interactive:(BOOL)interactive {
    // Remove any existing UIVisualEffectView
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
    }
    
    // Remove existing background color
    self.backgroundColor = [UIColor clearColor];
    
    UIGlassEffect *effect = [UIGlassEffect effectWithStyle:clear ? UIGlassEffectStyleClear : UIGlassEffectStyleRegular];
    effect.interactive = interactive;
    UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
    effectView.frame = self.bounds;
    effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    effectView.userInteractionEnabled = interactive;
    effectView.cornerConfiguration = corner;

    [self insertSubview:effectView atIndex:0];
}

@end
