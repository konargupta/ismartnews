//
//  iSmartNewsWindow.h
//  iSmartNewsDemo
//
//

#import <UIKit/UIKit.h>
#import "iSmartNewsPublic.h"

@interface iSmartNewsWindow : UIWindow
@property (nonatomic,assign) UIInterfaceOrientationMask orientationMask;
- (void)stop;
- (void)killWindow;
+ (instancetype)newsWindow;
@end
