//
//  iSmartNewsPopupViewController.m
//  iSmartNewsDemo
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsPopupViewController.h"
#import "iSmartNewsInternal.h"

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

@implementation iSmartNewsPopupViewController{
    BOOL _statusBarHooked;
    BOOL _forceUnload;
}

- (iSmartNewsModalPanel*)panel{
    if (!_panel){
        [self view];
    }
    return _panel;
}

- (void)loadView
{
    UIView* view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.view = view;
    [self.view setBackgroundColor:[UIColor clearColor]];
}

- (void)dealloc
{
    [self restoreStatusBar:NO];
}

- (UIViewController*)topController:(UIViewController*)controller
{
    UIViewController* c = [controller presentedViewController];
    if (c == controller || !c){
        return controller;
    }
    return [self topController:c];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.panel setNeedsLayout];
}

- (void)restoreStatusBar:(BOOL)animated
{
    if (_statusBarHooked)
    {
        _statusBarHooked = NO;
        [[UIApplication sharedApplication] iSmartNews_hideStatusbar:NO animated:animated];
        
        if ([[[UIDevice currentDevice] systemVersion] hasPrefix:@"8."]){
            // async help to run code on application window not on smartnews one!!!
            dispatch_async(dispatch_get_main_queue(), ^{
                
                id (*statusBarWindowFunc)(id,SEL) = (id (*)(id,SEL))objc_msgSend;
                void (*setOrientationFunc)(id,SEL, long long, id) = (void (*)(id,SEL, long long, id))objc_msgSend;
                
                id const statusBarWindow = statusBarWindowFunc([UIApplication sharedApplication],NSSelectorFromString(@"statusBarWindow"));
                
                UIViewController* const top = [self topController:[[[UIApplication sharedApplication] keyWindow] rootViewController]];
                
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([[UIApplication sharedApplication] statusBarOrientation] != top.interfaceOrientation){
                    setOrientationFunc(statusBarWindow,NSSelectorFromString(@"setOrientation:animationParameters:"), top.interfaceOrientation, nil);
                }
#pragma clang diagnostic pop                
            });
        }
    }
}

- (void)forceUnload
{
    _forceUnload = YES;
    [_panel removeFromSuperview];
    _panel = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0)
        self.wantsFullScreenLayout = YES;
#pragma clang diagnostic pop
    
    if (!_forceUnload)
    {
        _panel = [[iSmartNewsModalPanel alloc] initWithFrame:[self.view bounds]];
        [_panel setPadding:UIEdgeInsetsZero];
        [_panel setMargin:UIEdgeInsetsZero];
        [_panel setBorderWidth:0];
        [self.view addSubview:_panel];
        
        [_panel setHideAnimationTarget:self];
        [_panel setHideAnimationAction:@selector(panelWillDisappear:)];
    }
}

- (void)panelWillDisappear:(iSmartNewsModalPanel*)panel
{
    if ([panel isEqual:_panel])
    {
        [self restoreStatusBar:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self restoreStatusBar:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];

    if (!_statusBarHooked)
    {
        _statusBarHooked = YES;
        [[UIApplication sharedApplication] iSmartNews_hideStatusbar:YES animated:animated];
    }
    
    for (UIWindow* window in [[UIApplication sharedApplication] windows])
        [[window iSmartNewsFindFirstResponder_findFirstResponder] resignFirstResponder];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _panel.disableBuiltinAnimations = self.disableBuiltinAnimations;
    _panel.customAnimation = self.customAnimation;
    _panel.removeAdsPosition = self.removeAdsPosition;
    
    if (self.disableBuiltinAnimations)
    {
        [_panel showImmediately];
    }
    else
    {
        [_panel showFromPoint:CGPointMake(_panel.superview.bounds.size.width/2, _panel.superview.bounds.size.height/2)];
        
        if (!_statusBarHooked)
        {
            _statusBarHooked = YES;
            [[UIApplication sharedApplication] iSmartNews_hideStatusbar:YES animated:YES];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [_panel setIsReady:YES];
    });
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
