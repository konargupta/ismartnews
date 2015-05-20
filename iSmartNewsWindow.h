//
//  iSmartNewsWindow.h
//  iSmartNewsDemo
//
//

#if SMARTNEWS_COMPILE

#import <UIKit/UIKit.h>

@interface iSmartNewsWindow : UIWindow
@property (nonatomic,assign) UIInterfaceOrientationMask orientationMask;
- (void)stop;
- (void)killWindow;
+ (instancetype)newsWindow;
@end

#endif//#if SMARTNEWS_COMPILE
