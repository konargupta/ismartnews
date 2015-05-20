//
//  iSmartNewsPopupNavigationController.h
//  iSmartNewsDemo
//
//

#if SMARTNEWS_COMPILE

#import <UIKit/UIKit.h>

@interface iSmartNewsPopupNavigationController : UINavigationController
@property (nonatomic,assign) BOOL allowAllIphoneOrientations;
@property (nonatomic,assign) UIInterfaceOrientationMask orientationMask;
@end

#endif//#if SMARTNEWS_COMPILE
