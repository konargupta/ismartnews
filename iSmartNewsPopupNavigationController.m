//
//  iSmartNewsPopupNavigationController.m
//  iSmartNewsDemo
//
//

#if SMARTNEWS_COMPILE

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsPopupNavigationController.h"

@implementation iSmartNewsPopupNavigationController

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (self.allowAllIphoneOrientations){
        return UIInterfaceOrientationMaskAll;
    }
    
    if (self.orientationMask != 0){
        return self.orientationMask;
    }
    
    return UIInterfaceOrientationMaskPortrait;
}

@end

#endif//#if SMARTNEWS_COMPILE
