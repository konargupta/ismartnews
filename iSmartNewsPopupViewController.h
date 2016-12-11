//
//  iSmartNewsPopupViewController.h
//  iSmartNewsDemo
//
//

#import <UIKit/UIKit.h>
#import "iSmartNewsPublic.h"

@class iSmartNewsModalPanel;

@interface iSmartNewsPopupNavigationController : UINavigationController
@property (nonatomic,assign) BOOL allowAllIphoneOrientations;
@property (nonatomic,assign) UIInterfaceOrientationMask orientationMask;
@end

@interface iSmartNewsPopupViewController : UIViewController
@property (nonatomic,strong) iSmartNewsModalPanel* panel;

@property (nonatomic,assign) BOOL disableBuiltinAnimations;
@property (nonatomic,copy) NSString* customAnimation;
@property (nonatomic,copy) NSString* removeAdsPosition;
- (void)restoreStatusBar:(BOOL)animated;
- (void)forceUnload;
@end
