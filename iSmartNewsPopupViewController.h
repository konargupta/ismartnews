//
//  iSmartNewsPopupViewController.h
//  iSmartNewsDemo
//
//

#if SMARTNEWS_COMPILE

#import <UIKit/UIKit.h>

@class iSmartNewsModalPanel;

@interface iSmartNewsPopupViewController : UIViewController
@property (nonatomic,strong) iSmartNewsModalPanel* panel;
@property (nonatomic,strong) UIWebView* webView;
@property (nonatomic,assign) BOOL disableBuiltinAnimations;
@property (nonatomic,copy) NSString* customAnimation;
@property (nonatomic,copy) NSString* removeAdsPosition;
- (void)restoreStatusBar:(BOOL)animated;
- (void)forceUnload;
@end

#endif//#if SMARTNEWS_COMPILE
