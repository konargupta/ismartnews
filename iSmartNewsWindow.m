//
//  iSmartNewsWindow.m
//  iSmartNewsDemo
//
//

#ifndef SMARTNEWS_COMPILE
//#define  SMARTNEWS_COMPILE 1
#endif
#if SMARTNEWS_COMPILE

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsWindow.h"

#ifndef STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO
# define STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#endif

@implementation iSmartNewsWindow{
    NSTimer* _timer;
    BOOL _k;
}

static __weak iSmartNewsWindow* cachedWindow = nil;

+ (instancetype)newsWindow
{
    if ([[[UIDevice currentDevice] systemVersion] hasPrefix:@"8."])
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fix_ios8_alertwindow:) name:UIWindowDidBecomeVisibleNotification object:nil];
        });
    }
    
    iSmartNewsWindow* w;
    w = cachedWindow;
    if (!w){
        w = [[self alloc] initWithFrame:CGRectZero];
        cachedWindow = w;
    }
    return w;
}

+ (void)fix_ios8_alertwindow:(NSNotification*)notification
{
    if ([notification.object class] == NSClassFromString(@"_UIAlertControllerShimPresenterWindow"))
    {
        UIWindow* alertWindow = notification.object;
        alertWindow.frame = [[self class] screenBounds];
    }
}

- (void)killWindow
{
    [self stop];
    [self setHidden:YES];
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self setRootViewController:nil];
}

+ (CGRect)screenBounds
{
    CGRect bounds = [UIScreen mainScreen].bounds;
    if ([[UIScreen mainScreen] respondsToSelector:@selector(fixedCoordinateSpace)]) {
        id<UICoordinateSpace> currentCoordSpace = [[UIScreen mainScreen] coordinateSpace];
        id<UICoordinateSpace> portraitCoordSpace = [[UIScreen mainScreen] fixedCoordinateSpace];
        bounds = [portraitCoordSpace convertRect:[[UIScreen mainScreen] bounds] fromCoordinateSpace:currentCoordSpace];
    }
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0){
        if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])){
            return CGRectMake(0, 0, MIN(bounds.size.width,bounds.size.height), MAX(bounds.size.width,bounds.size.height));
        }
        else {
            return CGRectMake(0, 0, MAX(bounds.size.width,bounds.size.height), MIN(bounds.size.width,bounds.size.height));
        }
    }
    else {
        return bounds;
    }
}

- (void)stop{
    [_timer invalidate];
    _timer = nil;
}

- (void)makeKeyAndVisible{
    [super makeKeyAndVisible];
    
    if (([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
        && ([[[UIDevice currentDevice] systemVersion] floatValue] < 9.0)){
        self.frame = [[self class] screenBounds];
    }
}

- (id)initWithFrame:(CGRect)frame{
    frame = [[self class] screenBounds];
    self = [super initWithFrame:frame];
    return self;
}

- (void)dealloc{
    [_timer invalidate];
    _timer = nil;
}

static BOOL is_playerView(UIView*v)
{
    static Class c = nil;
    if (!c)
        c = NSClassFromString(@"AVPlayerView");
    
    if (!c)
        return NO;
    
    if ([v isKindOfClass:c]){
        return YES;
    }
    
    for (UIView* s in [v subviews])
        if (is_playerView(s))
            return YES;
    
    return NO;
}

- (void)recheck
{
    if ([[[UIApplication sharedApplication] windows] indexOfObject:self] == NSNotFound)
        return;
    
    if (![self isKeyWindow])
    {
        if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            && STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
        {
            UIWindow* window = [[UIApplication sharedApplication] keyWindow];
            UIViewController* controller = window.rootViewController;
            UIView* view = [controller view];
            if (is_playerView(view))
            {
                [self setHidden:YES];
            }
            else
            {
                [self setHidden:NO];
                [self makeKeyAndVisible];
            }
        }
        else
        {
            if ([self isHidden])
                [self setHidden:NO];
            [self makeKeyAndVisible];
        }
    }
    else
    {
        if ([self isHidden])
            [self setHidden:NO];
    }
}

- (void)resignKeyWindow{
    [super resignKeyWindow];
    [_timer invalidate];
    _timer = nil;
}

- (void)becomeKeyWindow{
    [super becomeKeyWindow];

    if (!_timer){
        NSInvocation* inv = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(recheck)]];
        [inv setTarget:self];
        [inv setSelector:@selector(recheck)];
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:inv selector:@selector(invoke) userInfo:nil repeats:YES];
    }
}

@end

#endif//#if SMARTNEWS_COMPILE
