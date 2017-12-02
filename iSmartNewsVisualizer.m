//
//  iSmartNewsVisualizer.m
//  iSmartNewsDemo
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsVisualizer.h"

#import "iSmartNews.h"
#import "iSmartNewsInternal.h"

#import "iSmartNewsLocalization.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <StoreKit/StoreKit.h>


id doNothing(id self, SEL selector, ...)
{
    return nil;
}

typedef NS_ENUM(NSInteger, iSmartNewsVisualizerInjectDataState)
{
    iSmartNewsVisualizerInjectNotNeed    = 0,
    iSmartNewsVisualizerInjectWasStarted = 1,
    iSmartNewsVisualizerInjectWasFailed  = 2,
};



EXTERN_OR_STATIC INLINE_INTERNAL_ATTRIBUTES UIColor* colorFromRGBString(NSString* rgbString)
{
    if ([rgbString length] < 6)
        return nil;
    
    const char* rgbStringRaw = [rgbString cStringUsingEncoding:NSASCIIStringEncoding];
    long colorValue = strtol(rgbStringRaw, NULL, 16);
    
    unsigned char r, g, b;
    b = colorValue & 0xFF;
    g = (colorValue >> 8) & 0xFF;
    r = (colorValue >> 16) & 0xFF;
    
    UIColor* resultColor = [UIColor colorWithRed:(float)r/255.0f green:(float)g/255.0f blue:(float)b/255.0f alpha:1];
    
    return resultColor;
}

@interface UIWebViewStopLoadDelegate : NSObject<UIWebViewDelegate>
@end

@implementation UIWebViewStopLoadDelegate

+(instancetype) sharedInstanse
{
    static UIWebViewStopLoadDelegate* sharedInstanse = nil;
    if (sharedInstanse == nil)
    {
        sharedInstanse = [[UIWebViewStopLoadDelegate alloc] init];
    }
    return sharedInstanse;
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return NO;
}
@end

@interface SNShowUIWebView: UIWebView<UIWebViewDelegate>{
    __strong id _self;
}
@end

@implementation SNShowUIWebView

+ (void)load
{
    [self loadCookies];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveCookies) name:UIApplicationWillTerminateNotification object:nil];
}

+ (void)loadCookies
{
    NSData* data = [NSData dataWithContentsOfFile:[self storagePath]];
    if (!data){
        return;
    }

    NSMutableArray *cookies;
    @try
    {
        cookies = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
    }
    @catch(...){}
    
    if (!cookies){
        return;
    }
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    for (NSDictionary* cookieData in cookies) {
        [cookieStorage setCookie:[NSHTTPCookie cookieWithProperties:cookieData]];
    }
}

+ (NSString*)storagePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    return [NSString stringWithFormat:@"%@/sn.cookies.data", paths[0]];
}

+ (void)saveCookies
{
    NSMutableArray* cookieData = [NSMutableArray new];
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie* cookie in [cookieStorage cookies]) {
        NSMutableDictionary* cookieDictionary = [NSMutableDictionary new];
        cookieDictionary[NSHTTPCookieName] = cookie.name;
        cookieDictionary[NSHTTPCookieValue] = cookie.value;
        cookieDictionary[NSHTTPCookieDomain] = cookie.domain;
        cookieDictionary[NSHTTPCookiePath] = cookie.path;
        cookieDictionary[NSHTTPCookieSecure] = (cookie.isSecure ? @"YES" : @"NO");
        cookieDictionary[NSHTTPCookieVersion] = [NSString stringWithFormat:@"%lu", (unsigned long)cookie.version];
        if (cookie.expiresDate) cookieDictionary[NSHTTPCookieExpires] = cookie.expiresDate;
        
        [cookieData addObject:cookieDictionary];
    }
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cookieData];
    [data writeToFile:[self storagePath] atomically:TRUE];
}

+ (instancetype)webViewWithRequest:(NSURLRequest*)request
{
    SNShowUIWebView* w = [[SNShowUIWebView alloc] initWithFrame:CGRectZero];
    [w loadRequest:request];
    return w;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    [self setDelegate:self];
    return self;
}

#pragma mark - UIWebViewDelegate <NSObject>

- (void)loadRequest:(NSURLRequest *)request
{
    assert(!_self);
    [super loadRequest:request];
    _self = self;
    [self performSelector:@selector(kill) withObject:nil afterDelay:60.0];
}

- (void)kill
{
    [self stop];
}

- (void)stop
{
    [self stopLoading];
 
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(kill) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stop) object:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _self = nil;
    });
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stop) object:nil];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stop) object:nil];
    [self performSelector:@selector(stop) withObject:nil afterDelay:1.0];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self stop];
}

@end

@interface SNWebView : UIWebView
@end

const int SNWebViewBlurEffectViewTag        = 11001;
const int SNWebViewActivityIndicatorViewTag = 11002;

@implementation SNWebView
{
    BOOL    _showLoading;
    UIView* _loadingView;
    
    BOOL _allowVerticalScroll;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self _applyScale];
    }
    return self;
}

- (void)_applyScale
{
    if ([self respondsToSelector:@selector(scrollView)])
    {
        UIScrollView *scroll = [self scrollView];
        
        const float zoomByWidth  = self.bounds.size.width/scroll.contentSize.width;
        const float zoomByHeight = self.bounds.size.height/scroll.contentSize.height;
        
        float minZoom = _allowVerticalScroll ? zoomByWidth : (MIN(zoomByWidth,zoomByHeight));
        
        if (minZoom > FLT_EPSILON)
        {
            [scroll setZoomScale:minZoom animated:YES];
            NSString* jsCommand = [NSString stringWithFormat:@"document.body.style.zoom = %f;",minZoom];
            [self stringByEvaluatingJavaScriptFromString:jsCommand];
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self _applyScale];
    
    if (_loadingView)
    {
        UIView* superview = self;
        
        if ([[_loadingView superview] isEqual:superview] == NO)
        {
            [superview addSubview:_loadingView];
        }
        
        _loadingView.frame = [_loadingView superview].frame;
        [[_loadingView superview] bringSubviewToFront:_loadingView];
        
        UIActivityIndicatorView* activityIndicatorView = [_loadingView viewWithTag:SNWebViewActivityIndicatorViewTag];
        
        activityIndicatorView.center = _loadingView.center;
        
        if ([activityIndicatorView isAnimating] == NO)
        {
            [activityIndicatorView startAnimating];
        }
    }
}

-(void)dealloc
{
    iSmartNewsLog(@"SNWebView : %p dealloc", self);
}

-(void)showLoading:(BOOL) showLoading style:(NSDictionary*) style
{
    if (showLoading == _showLoading)
        return;
    
    _showLoading = showLoading;
    
    float osv = [[[UIDevice currentDevice] systemVersion] floatValue];
    
    if (_showLoading)
    {
        NSDictionary* showLoadingStyle = [style objectForKey:@"show_loading"];
        
        UIBlurEffectStyle blurStyle   = UIBlurEffectStyleDark;
        UIColor* backgroundColorStyle = [UIColor clearColor];
        UIColor* activityColor = nil;
        
        NSString* blurName = [showLoadingStyle objectForKey:@"blur"];
        if ([blurName length] > 0)
        {
            if      ([blurName isEqualToString:@"extralight"])  blurStyle = UIBlurEffectStyleExtraLight;
            else if ([blurName isEqualToString:@"light"])       blurStyle = UIBlurEffectStyleLight;
            else if ([blurName isEqualToString:@"dark"])        blurStyle = UIBlurEffectStyleDark;
            else if ([blurName isEqualToString:@"regular"])     blurStyle = (osv >= 10.0) ? UIBlurEffectStyleRegular : UIBlurEffectStyleLight;
            else if ([blurName isEqualToString:@"none"])        blurStyle = NSNotFound;
        }
        
        NSString* backgroundColorDescription = [showLoadingStyle objectForKey:@"backround"];
        if ([backgroundColorDescription length] > 0)
            backgroundColorStyle = colorFromRGBString(backgroundColorDescription);
        
        NSString* activityColorDescription = [showLoadingStyle objectForKey:@"indicator"];
        if ([activityColorDescription length] > 0)
            activityColor = colorFromRGBString(activityColorDescription);
        
        self.backgroundColor = backgroundColorStyle;
        self.opaque = NO;
        
        _loadingView = [[UIView alloc] initWithFrame:[self bounds]];
        _loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        UIVisualEffectView* effectView = nil;
        
        if (blurStyle != NSNotFound)
        {
            UIBlurEffect* effect = [UIBlurEffect effectWithStyle:blurStyle];
            effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
            
            [_loadingView addSubview:effectView];
            
            effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            effectView.frame = [_loadingView frame];
        }
        
        UIActivityIndicatorView* activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        if (activityColor != nil)
            activityIndicatorView.color = activityColor;
        
        [_loadingView addSubview:activityIndicatorView];
        activityIndicatorView.center = _loadingView.center;
        activityIndicatorView.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin);
        
        //[activityIndicatorView startAnimating];
        
        effectView.tag = SNWebViewBlurEffectViewTag;
        activityIndicatorView.tag = SNWebViewActivityIndicatorViewTag;
        
        [self setNeedsLayout];
    }
    else
    {
        UIActivityIndicatorView* activityIndicatorView = [_loadingView viewWithTag:SNWebViewActivityIndicatorViewTag];
        [activityIndicatorView stopAnimating];
        
        [_loadingView removeFromSuperview];
        _loadingView = nil;
    }
}

- (void)configureContentSizeScaleAndBehaviour:(NSDictionary*) description
{
    //Default values
    BOOL disableLongTap     = YES;
    BOOL scaleContent       = YES;
    BOOL allowVerticalScroll = NO;
    
    
    if ([description objectForKey:@"allowVerticalScroll"])
    {
        allowVerticalScroll = [[description objectForKey:@"allowVerticalScroll"] boolValue];
    }
    
    if (disableLongTap)
    {
        [self disableBadGestureRecognizer:self];
    }
    
    if (allowVerticalScroll)
    {
        _allowVerticalScroll = YES;
        [self disableScroll:UIScrollViewModeHorizontal];
    }
    else
    {
        _allowVerticalScroll = NO;
        [self disableScroll:(UIScrollViewModeHorizontal | UIScrollViewModeVertical)];
    }
    
    if (scaleContent)
    {
        [self setScalesPageToFit:YES];
        [self setContentMode:UIViewContentModeScaleAspectFit];
        
        [self _applyScale];
    }
}

-(void)disableScroll:(UIScrollViewMode) mode
{
    [self disableScroll:mode forView:self level:4];
}

-(void)disableScroll:(UIScrollViewMode) mode forView:(UIView*) view level:(NSUInteger) level
{
    if ([view isKindOfClass:[UIScrollView class]])
    {
        UIScrollView* scrollView = (UIScrollView*)view;
        
        if (mode > 0)
        {
            if (((mode & UIScrollViewModeHorizontal) > 0) && ((mode & UIScrollViewModeVertical) > 0))
            {
                scrollView.scrollEnabled = NO;
                scrollView.bounces = NO;
                scrollView.alwaysBounceVertical   = NO;
                scrollView.alwaysBounceHorizontal = NO;
            }
            else if ((mode & UIScrollViewModeHorizontal) > 0)
            {
                scrollView.horizontalScrollDisable = YES;
            }
            else if ((mode & UIScrollViewModeVertical) > 0)
            {
                scrollView.verticalScrollDisable = YES;
            }
        }
        else
        {
            scrollView.scrollEnabled = YES;
            scrollView.horizontalScrollDisable = NO;
            scrollView.verticalScrollDisable = NO;
        }
        
        return;
    }
    else
    {
        if (--level == 0)
            return;
        
        for (UIView* subview in [view subviews])
        {
            [self disableScroll:mode forView:subview level:level];
        }
    }
}

- (void)disableBadGestureRecognizer:(UIView*)view
{
}

@end

@interface iSmartNewsVisualizer() <UIAlertViewDelegate>

//@property (nonatomic,assign,readwrite) BOOL isShown;

//Popup
@property (nonatomic,strong) iSmartNewsWindow*                   popupWindow;
@property (nonatomic,strong) iSmartNewsPopupViewController*      popupViewController;

@property (nonatomic,strong) SNWebView*                          contentWebView;

@end

static int gNewsVisualizerInstCounter = 0;


@implementation iSmartNewsVisualizer
{
    BOOL _activated; //Show requested
    BOOL _shown;     //Start loading content
    
    BOOL _presented; //Shown on window
    BOOL _loaded;    //Content loaded
    
    BOOL _ready;     //Content ready
    
    BOOL _closing;
    BOOL _closed;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIAlertView*    _alertView;
#pragma clang diagnostic pop
    
    NSInteger       _okIndex;
    NSInteger       _reviewIndex;
    NSInteger       _remindIndex;
    NSInteger       _cancelIndex;
    
    NSURL* _url;
    NSString* _localWeb;
    
    BOOL _isDirectAction;

    BOOL _showRemoveAdsButton;
    iSmartNewsVisualizerAppearance _appearance;
    NSDictionary* _appearanceStyle;
    
    //Additional
    NSTimer*  _showDelayTimer;
    NSString* _reviewType;
    
    //Injection
    NSMutableDictionary* _injectData;
    NSMutableDictionary* _newInjectData;
    
#if JS_CONTEXT
    JSContext* _injectContext;
#endif
}

@synthesize isPresented     = _presented;
@synthesize appearanceStyle = _appearanceStyle;

#pragma mark - Initialization
+ (void)load
{
    NSString* tmp = NSTemporaryDirectory();
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmp error:NULL];
    for (NSString* item in files)
    {
        NSString* fullPath = [tmp stringByAppendingString:item];
        
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
        
        if (!isDirectory && [item hasPrefix:@"smartnewstmp-"] && [[item pathExtension] isEqualToString:@"zip"]){
            [[NSFileManager defaultManager] removeItemAtPath:fullPath error:NULL];
        }
        else if (isDirectory && [item hasPrefix:@"smartnews-"]){
            [[NSFileManager defaultManager] removeItemAtPath:fullPath error:NULL];
        }
    }
}

- (id)initAlertViewVisualizerWithDescription:(NSDictionary*) description
{
    NSString* title     = [description objectForKey:iSmartNewsMessageTitleKey];
    NSString* message   = [description objectForKey:iSmartNewsMessageTextKey];
    NSString* cancel    = [description objectForKey:iSmartNewsMessageCancelKey];
    NSString* ok        = [description objectForKey:iSmartNewsMessageActionKey];
    NSString* review    = [description objectForKey:iSmartNewsMessageReviewKey];
    NSString* remind    = [description objectForKey:iSmartNewsMessageRemindKey];
    
    NSString* url       = [description objectForKey:iSmartNewsMessageUrlKey];
    
    if ([ok isEqualToString:@"default"])
    {
        ok = NSLocalizedString(@"OK",);
    }
    
    ok = (url?(ok?ok:NSLocalizedString(@"OK",)):nil);
    
    self = [self initAlertViewVisualizerWithTitle:title message:message cancel:cancel ok:ok review:review remind:remind];
    if (self)
    {
        _reviewType = [description objectForKey:iSmartNewsMessageReviewTypeKey];
        _appearanceStyle = [description objectForKey:iSmartNewsMessageStyleKey];
    }
    return self;
}

- (id)initAlertViewVisualizerWithTitle:(NSString*)title message:(NSString*)message cancel:(NSString*)cancel ok:(NSString*)ok review:(NSString*)review remind:(NSString*)remind
{
    self = [super init];
    if (self)
    {
        //Prepare values
        if ([review isEqualToString:@"default"])
        {
            review = news_reviewRate();
        }
        
        if (review)
        {
            if ([title isEqualToString:@"default"])
            {
                title = news_reviewTitle();
            }
            
            if ([message isEqualToString:@"default"])
            {
                message = news_reviewMessage();
            }
        }
        
        if ([cancel isEqualToString:@"default"])
        {
            cancel = NSLocalizedString(@"Cancel",);
        }

        if ([remind isEqualToString:@"default"])
        {
            remind = news_reviewLater();
        }
        
        if (++gNewsVisualizerInstCounter == 1)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"iSmartNewsWillShowNotification" object:nil];
        }
        
        _appearance = isnVisualizerAppearancePopup;
        
        _orientationMask = 0;
        _okIndex = -1;
        _reviewIndex = -1;
        _remindIndex = -1;
        _cancelIndex = -1;
        
        int nButtons = 0;
        if (ok) nButtons++;
        if (review) nButtons++;
        if (remind) nButtons++;
        if (cancel) nButtons++;
        
        const BOOL nativeBehaviour = YES;
        
    
#pragma warning repleace deprecated UIAlertView
#pragma clang diagnostic push                                           //UIAlertView
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (nativeBehaviour && (nButtons == 2))
        {
            _alertView = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:nil];
            
            if (cancel){
                _cancelIndex = [_alertView addButtonWithTitle:cancel];
            }
            
            if (remind){
                _remindIndex = [_alertView addButtonWithTitle:remind];
            }
            
            if (review){
                _reviewIndex = [_alertView addButtonWithTitle:review];
            }
            
            if (ok){
                _okIndex = [_alertView addButtonWithTitle:ok];
            }
        }
        else if (nButtons <= 2)
        {
            if (ok){
                if (!_alertView){
                    _alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:ok
                                                  otherButtonTitles:nil];
                    _okIndex = _alertView.cancelButtonIndex;
                }
                else {
                    _okIndex = [_alertView addButtonWithTitle:ok];
                }
            }
            
            if (review){
                if (!_alertView){
                    _alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
                    _reviewIndex = [_alertView addButtonWithTitle:review];
                    _alertView.cancelButtonIndex = _reviewIndex;
                }
                else {
                    _reviewIndex = [_alertView addButtonWithTitle:review];
                }
            }
            
            if (remind){
                if (!_alertView){
                    _alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
                    _remindIndex = [_alertView addButtonWithTitle:remind];
                    _alertView.cancelButtonIndex = _remindIndex;
                }
                else{
                    _remindIndex = [_alertView addButtonWithTitle:remind];
                }
            }
            
            if (cancel){
                if (!_alertView){
                    _alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
                    _cancelIndex = [_alertView addButtonWithTitle:cancel];
                    _alertView.cancelButtonIndex = _cancelIndex;
                }
                else {
                    _cancelIndex = [_alertView addButtonWithTitle:cancel];
                }
            }
        }
        else //(nButtons > 2) || (nButtons == 2 && nativeBehaviour == NO)
        {
            //Review always at top!
            
            if (review){
                if (!_alertView){
                    _alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
                    _reviewIndex = [_alertView addButtonWithTitle:review];
                }
                else {
                    _reviewIndex = [_alertView addButtonWithTitle:review];
                }
            }
            
            if (ok){
                if (!_alertView){
                    _alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
                    _okIndex = [_alertView addButtonWithTitle:ok];
                }
                else {
                    _okIndex = [_alertView addButtonWithTitle:ok];
                }
            }
            
            if (remind){
                if (!_alertView){
                    _alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
                    _remindIndex = [_alertView addButtonWithTitle:remind];
                }
                else{
                    _remindIndex = [_alertView addButtonWithTitle:remind];
                }
            }
            
            if (cancel){
                if (!_alertView){
                    _alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
                    _cancelIndex = [_alertView addButtonWithTitle:cancel];
                    _alertView.cancelButtonIndex = _cancelIndex;
                }
                else {
                    _cancelIndex = [_alertView addButtonWithTitle:cancel];
                    _alertView.cancelButtonIndex = _cancelIndex;
                }
            }
        }
#pragma clang diagnostic pop                                                //UIAlertView
    }
    return self;
}

- (id)initWebViewVisualizerWithURL:(NSURL*)url showRemoveAdsButton:(BOOL)showRemoveAdsButton
{
    self = [self initWebViewVisualizerWithURL:url appearance:isnVisualizerAppearancePopup showRemoveAdsButton:showRemoveAdsButton];
    return self;
}

- (id)initWebViewVisualizerWithURL:(NSURL*)url appearance:(iSmartNewsVisualizerAppearance) appearance showRemoveAdsButton:(BOOL)showRemoveAdsButton
{
    self = [super init];
    if (self)
    {
        if (!url)
        {
            self = nil;
            return nil;
        }
        
        _appearance = appearance;
        
        if (_appearance == isnVisualizerAppearancePopup)
        {
            if (++gNewsVisualizerInstCounter == 1)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"iSmartNewsWillShowNotification" object:nil];
            }
        }
        
        _url = url;
        _showRemoveAdsButton = showRemoveAdsButton;
    }
    return self;
}

- (id)initDirectActionVisualizerWithURL:(NSURL*)url
{
    self = [super init];
    if (self)
    {
        _url = url;
        _isDirectAction = YES;
    }
    return self;
}

- (void)dealloc
{
    if (_appearance == isnVisualizerAppearancePopup)
    {
        if (--gNewsVisualizerInstCounter == 0)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"iSmartNewsDidHideNotification" object:nil];
        }
        
        void (^notify)() = ^{
            if (--gNewsVisualizerInstCounter == 0){
                [[NSNotificationCenter defaultCenter] postNotificationName:@"iSmartNewsDidHideNotification" object:nil];
            }
        };
        
        if ([NSThread isMainThread])
        {
            notify();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), [notify copy]);
        }
    }
    
    if (_localWeb)
    {
        [[NSFileManager defaultManager] removeItemAtPath:_localWeb error:NULL];
    }
    
    iSmartNewsLog(@"visualizer : %p dealloc", self);
}

#pragma mark Show
- (void)_show
{
    [_showDelayTimer invalidate];
    _showDelayTimer = nil;
    
    if (_shown)
    {
        return;
    }
    
    _shown = YES;
    _ready = NO;
    
    if (_alertView)
    {
        [self setIsPresented:YES]; //Show immediately
        [self postOnShow];
        
        [self hideKeyBoard];
        [_alertView show];
    }
    else if (_isDirectAction)
    {
        BOOL actionWasStarted = NO;
        
        if ([[_url host] isEqualToString:@"review.io"])
        {
            NSArray* pathComponents = [[_url pathComponents] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                return ![evaluatedObject isEqualToString:@"/"];
            }]];
            
            if ([pathComponents count] >= 1 &&  ([@[@"open"] indexOfObject:[pathComponents firstObject]] != NSNotFound))
            {
                NSString* actionType = [pathComponents firstObject];
                
                if ([actionType isEqualToString:@"open"])
                {
                    NSString* reviewType = [pathComponents count] > 1 ? [pathComponents lastObject] : nil;
                    NSDictionary* additionalInfo = (reviewType != nil)?@{@"reviewType" : reviewType}:nil;
                    
                    actionWasStarted = [[iSmartNewsActions sharedInstance] performAction:iSmartNewsActionReviewOpen item:nil additionalInfo:additionalInfo completionHandler:^(NSString *action, NSDictionary *additionalInfo, BOOL success) {
                        
                        if (success)
                        {
                            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickOpenReview:)];
                            [self _notifyAboutClose:@"review"];
                        }
                        else
                        {
                            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidFail:)];
                            [self _notifyAboutClose:@"fail"];
                        }
                    }];
                }
            }
        }
        
        if (actionWasStarted)
        {
            [self postOnShow];
        }
        else //unknown action
        {
            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidFail:)];
            [self _notifyAboutClose:@"fail"];
        }
    }
    else
    {
        //Web showing with delay for loading
        
        if ([[[_url absoluteString] pathExtension] isEqualToString:@"zip"])
        {
#pragma warning repleace deprecated NSURLConnection
#pragma clang diagnostic push                                   //NSURLConnection
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:_url]
                                               queue:[NSOperationQueue mainQueue]
                                   completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
                                       dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
                                           NSString* zip = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"smartnewstmp-%f.zip",CFAbsoluteTimeGetCurrent()]];
                                           [data writeToFile:zip atomically:YES];
                                           assert(!_localWeb);
                                           _localWeb = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"smartnews-%f",CFAbsoluteTimeGetCurrent()]];
                                           [[NSFileManager defaultManager] createDirectoryAtPath:_localWeb withIntermediateDirectories:YES attributes:nil error:NULL];
                                           const BOOL unzipped = smartnews_unzip([zip UTF8String], [_localWeb UTF8String]) == 0;
                                           [[NSFileManager defaultManager] removeItemAtPath:zip error:NULL];
                                           if (!unzipped
                                               || (![[NSFileManager defaultManager] fileExistsAtPath:[_localWeb stringByAppendingPathComponent:@"index.html"]])
                                               ){
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidFail:)];
                                                   [self _notifyAboutClose:@"fail"];
                                               });
                                               return;
                                           }
                                           
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               self.contentWebView = [[SNWebView alloc] initWithFrame:CGRectMake(0,0,1,1)];
                                               self.contentWebView.accessibilityLabel = @"iSNWeb";
                                               self.contentWebView.accessibilityHint = @"iSNWeb";
                                               self.contentWebView.accessibilityIdentifier = @"iSNWeb";
                                               [self.contentWebView setDelegate:(id<UIWebViewDelegate>)self];
                                               [self.contentWebView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[_localWeb stringByAppendingPathComponent:@"index.html"]]]];
                                           });
                                       });
                                   }];
#pragma clang diagnostic pop                                   //NSURLConnection
        }
        else
        {
            self.contentWebView = [[SNWebView alloc] initWithFrame:CGRectMake(0,0,1,1)];
            self.contentWebView.accessibilityLabel = @"iSNWeb";
            self.contentWebView.accessibilityHint = @"iSNWeb";
            self.contentWebView.accessibilityIdentifier = @"iSNWeb";
            [self.contentWebView setDelegate:(id<UIWebViewDelegate>)self];
            [self.contentWebView loadRequest:[NSURLRequest requestWithURL:_url]];
        }
        
        if ([_appearanceStyle objectForKey:@"show_loading"] != nil)
        {
            [self webViewConfigureAndShow];
        }
    }
}

- (void)showWithDelayRange:(NSRange) delayRange
{
    if (_activated){
        return;
    }
    
    _activated = YES;
    
    if (delayRange.location == 0 && delayRange.length == 0)
    {
        [self _show];
    }
    else
    {
        const NSUInteger delay = delayRange.location + arc4random_uniform((uint32_t)delayRange.length);
        _showDelayTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(_show) userInfo:nil repeats:NO];
    }
}

#pragma mark - Properties

- (NSURL*)url
{
    return _url;
}

#pragma warning repleace deprecated UIAlertView
#pragma clang diagnostic push                                           //UIAlertView
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark - UIAlertView Delegate
- (void)alertViewCancel:(UIAlertView *)alertView
{
    if ( alertView != _alertView)
        return;
    
    _alertView.delegate = nil;
    
    [self setIsPresented:NO];
    
    [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickCancel:)];
    [self _notifyAboutClose:@"cancel"];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView != _alertView)
        return;
    
    _alertView.delegate = nil;
    
    [self setIsPresented:NO];
    
    if (buttonIndex == _cancelIndex)
    {
        [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickCancel:)];
        [self _notifyAboutClose:@"cancel"];
    }
    else
    {
        if (buttonIndex == _okIndex)
        {
            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickOk:)];
            [self _notifyAboutClose:@"ok"];
        }
        else if (buttonIndex == _reviewIndex)
        {
            NSDictionary* additionalInfo = (_reviewType != nil)?@{@"reviewType" : _reviewType}:nil;
            BOOL actionWasStarted = [[iSmartNewsActions sharedInstance] performAction:iSmartNewsActionReviewOpen item:nil additionalInfo:additionalInfo completionHandler:^(NSString *action, NSDictionary *additionalInfo, BOOL success) {
                
                if (success)
                {
                    [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickOpenReview:)];
                    [self _notifyAboutClose:@"review"];
                }
                else
                {
                    [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidFail:)];
                    [self _notifyAboutClose:@"fail"];
                }
            }];
            
            if (!actionWasStarted)
            {
                [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidFail:)];
                [self _notifyAboutClose:@"fail"];
            }
        }
        else if (buttonIndex == _remindIndex)
        {
            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickRemindLaterReview:)];
            [self _notifyAboutClose:@"remind"];
        }
    }
}

#pragma clang diagnostic pop                                //UIAlertView

#pragma mark -



#pragma mark - UIWebView Delegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (_loaded){
        return;
    }
    
    if (self.contentWebView != webView)
        return;
    
    if ([self.contentWebView isLoading])
        return;
    
    _loaded = YES;
    
    if (_presented)
    {
        if (([_appearanceStyle objectForKey:@"show_loading"] == nil) || _ready)
        {
            return;
        }
    }
    
    iSmartNewsLog(@"visualizer : webViewDidFinishLoad");
    
    iSmartNewsVisualizerInjectDataState injectState = [self webViewInjectData];
    if (injectState == iSmartNewsVisualizerInjectNotNeed)
    {
        iSmartNewsLog(@"visualizer : webViewDidFinishLoad : InjectNotNeed");
        _appearanceStyle = nil;
        _ready = YES;
        [self webViewConfigureAndShow];
    }
    else if (injectState == iSmartNewsVisualizerInjectWasFailed)
    {
        iSmartNewsLog(@"visualizer : webViewDidFinishLoad : InjectWasFailed");
        [self webViewFailedShowHandler];
    }
    else
    {
        assert(injectState == iSmartNewsVisualizerInjectWasStarted);
        iSmartNewsLog(@"visualizer : webViewDidFinishLoad : InjectWasStarted");
    }
}

-(void)webViewConfigureAndShow
{    
    [self setIsPresented:YES]; //Really show
    
    if (_loaded)
    {
        [self postOnShow];
    }

    if (_appearance == isnVisualizerAppearancePopup)
    {
        iSmartNewsLog(@"visualizer : webViewConfigureAndShow : configure popup");
        [self hideKeyBoard];
        
        if (self.popupWindow == nil)
        {
            self.popupWindow = [iSmartNewsWindow newsWindow];
            self.popupWindow.orientationMask = self.orientationMask;
            self.popupWindow.windowLevel = UIWindowLevelAlert + 1;
            [self.popupWindow setBackgroundColor:[UIColor clearColor]];
        }
        
        if ((self.popupViewController == nil) || ([self contentWebView].superview == nil))
        {
            self.popupViewController = [iSmartNewsPopupViewController new];
            iSmartNewsContentStatus status = _ready ? iSmartNewsContentReady : iSmartNewsContentLoading;
            [self.popupViewController.panel placeContent:[self contentWebView] status:status];
        }
        
        self.popupViewController.panel.delegate = (NSObject<iSmartNewsPanelDelegate>*)self;
        
        iSmartNewsPopupNavigationController* ctrl = (iSmartNewsPopupNavigationController*)self.popupWindow.rootViewController;
        if (ctrl == nil)
        {
            ctrl = [[iSmartNewsPopupNavigationController alloc] initWithRootViewController:self.popupViewController];
            ctrl.allowAllIphoneOrientations = self.allowAllIphoneOrientations;
        }
        
        [self applyPopupStyle];
        
        self.popupViewController.disableBuiltinAnimations = NO;

        if (self.orientationMask != 0)
        {
            ctrl.orientationMask = self.orientationMask;
        }
        
        [self.popupViewController setModalPresentationStyle:UIModalPresentationCustom];
        [self.popupViewController setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];
        //[self presentViewController:ivc animated:YES completion:nil];
        
        if ([self.popupWindow isKeyWindow] == NO)
        {
            self.popupWindow.rootViewController = ctrl;
            [self.popupWindow makeKeyAndVisible];
        }
        
        if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
            ctrl.view.frame = ctrl.view.superview.bounds;
    }
    else if (_appearance == isnVisualizerAppearanceEmbedded)
    {
        UIView* contentView = [self contentWebView];
        
        [self applyEmbeddedStyle];
        
        iSmartNewsLog(@"visualizer : webViewConfigureAndShow : place content to embedded %p", contentView);
        iSmartNewsContentStatus status = _ready ? iSmartNewsContentReady : iSmartNewsContentLoading;
        [self.embeddedPanel placeContent:contentView status:status];
    }
    
    // NOTE: Setup JS version variable last (after other vars) only!
    NSString *jsCommand = [NSString stringWithFormat:@"_SNVER = '%@';", iSmartNewsVersion];
    [self.contentWebView stringByEvaluatingJavaScriptFromString:jsCommand];
    
    [UIView animateWithDuration:0.35 animations:^ { [self.contentWebView setAlpha:1.f]; }];
    
    
    if (_appearance == isnVisualizerAppearancePopup)
    {
        if (_showRemoveAdsButton)
        {
            self.popupViewController.panel.showRemoveAdsButton = YES;
        }
    }
    
    if ((_ready == NO) && ([_appearanceStyle objectForKey:@"show_loading"] != nil))
    {
        [self applyLoadingStyle:_appearanceStyle];
        [self.contentWebView showLoading:YES style:_appearanceStyle];
    }
    else
    {
        [self.contentWebView showLoading:NO style:_appearanceStyle];
    }
    
    iSmartNewsLog(@"visualizer : webViewConfigureAndShow : finished");
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (self.contentWebView != webView)
        return;
    
    iSmartNewsLog(@"visualizer : didFailLoadWithError");
    
    [self webViewFailedShowHandler];
}

-(void) webViewFailedShowHandler
{
    iSmartNewsLog(@"visualizer : webViewFailedShowHandler");
    
#if JS_CONTEXT
    _injectContext = nil;
#endif
    
    //Showing failed
    _ready = NO;
    _closing = YES;
    
    [self setIsPresented:NO];
    
    [self.contentWebView setDelegate:[UIWebViewStopLoadDelegate sharedInstanse]];
    [self.contentWebView stopLoading];
    
    [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidFail:)];
    [self _notifyAboutClose:@"fail"];
    
    iSmartNewsLog(@"visualizer : webViewFailedShowHandler -> closeWebView");
    [self closeWebView];
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (self.contentWebView != webView)
        return YES;
    
    NSURL *requestURL = [request URL];
    
    if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
        (
         ([[requestURL scheme] hasPrefix:@"close"])
         || [[requestURL host] isEqualToString:@"close.io"]
         || [[requestURL host] isEqualToString:@"cancel.io"]
         )
        )
    {
        iSmartNewsLog(@"visualizer : close.io -> closeWebView");
        [self closeWebView];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickNothing:)];
            [self _notifyAboutClose:@"nothing"];
        });
        
        return NO;
    }
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
                 (
                  [[requestURL host] isEqualToString:@"review.io"]
                 ))
    {
        iSmartNewsLog(@"visualizer : review.io -> closeWebView");
        [self closeWebView];
        
        NSArray* pathComponents = [[requestURL pathComponents] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return ![evaluatedObject isEqualToString:@"/"];
        }]];

        if ([pathComponents count] >= 1
            &&  ([@[@"open",@"cancel",@"remind"] indexOfObject:[pathComponents firstObject]] != NSNotFound)){
            
            NSString* actionType = [pathComponents firstObject];
            
            if ([actionType isEqualToString:@"open"])
            {
                NSString* reviewType = [pathComponents count] > 1 ? [pathComponents lastObject] : nil;
                NSDictionary* additionalInfo = (reviewType != nil)?@{@"reviewType" : reviewType}:nil;
                
                BOOL actionWasStarted = [[iSmartNewsActions sharedInstance] performAction:iSmartNewsActionReviewOpen item:nil additionalInfo:additionalInfo completionHandler:^(NSString *action, NSDictionary *additionalInfo, BOOL success) {
                
                    if (success)
                    {
                        [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickOpenReview:)];
                        [self _notifyAboutClose:@"review"];
                    }
                    else
                    {
                        [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidFail:)];
                        [self _notifyAboutClose:@"fail"];
                    }
                }];
                
                if (!actionWasStarted)
                {
                    [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidFail:)];
                    [self _notifyAboutClose:@"fail"];
                }
            }
            else if ([actionType isEqualToString:@"cancel"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickCancelReview:)];
                    [self _notifyAboutClose:@"cancel_review"];
                });
            }
            else if ([actionType isEqualToString:@"remind"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickRemindLaterReview:)];
                    [self _notifyAboutClose:@"remind"];
                });
            }
        }
        else {
            UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickNothing:)];
                [self _notifyAboutClose:@"nothing"];
                [[UIApplication sharedApplication] endBackgroundTask:task];
            });
        }
        
        
        return NO;
    }
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
        (
         ([[requestURL scheme] hasPrefix:@"removeads"]) ||
         [[requestURL host] isEqualToString:@"removeads.io"]
         )
        )
    {
        iSmartNewsLog(@"visualizer : removeads -> closeWebView");
        [self closeWebView];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickRemoveAds:)];
            [self _notifyAboutClose:@"remove_ads"];
        });
        
        return NO;
    }
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) && [[self delegate] isCallBackURL:requestURL])
    {
        NSString* callBackType = [[self delegate] isCallBackURL:requestURL]; //Dupilcate call, but simple ...
        
        BOOL closeCurrenNews = [callBackType isEqualToString:@"callback"];
        NSString* notifyAboutCloseType = nil;
        
        if (closeCurrenNews)
        {
            iSmartNewsLog(@"visualizer : callback -> closeWebView");
            [self closeWebView];
            notifyAboutCloseType = callBackType;
        }
        else
        {
            notifyAboutCloseType = nil;
        }
        
        [self callBackProcessing:requestURL callType:callBackType notifyAboutClose:notifyAboutCloseType];
        
        return NO;
    }
    else if (([[requestURL scheme] hasPrefix:@"http"]) && (navigationType == UIWebViewNavigationTypeLinkClicked))
    {
        BOOL ok = ![[UIApplication sharedApplication] openURL:requestURL];
        
        if (!ok)
        {
            iSmartNewsLog(@"visualizer : link -> closeWebView");
            [self closeWebView];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickLink:)];
                [self _notifyAboutClose:@"link"];
            });
        }
        
        return ok;
    }
    
    return YES;
}

#pragma mark Config
- (void)applyLoadingStyle:(NSDictionary*) style
{
    if (_appearance == isnVisualizerAppearancePopup)
    {
        self.popupViewController.panel.closeButton.hidden = YES;
        self.popupViewController.panel.removeAdsButton.hidden = YES;
        self.popupViewController.panel.actionButton.hidden = YES;
        
        self.popupViewController.disableBuiltinAnimations = YES;
        
        NSDictionary* showLoadingStyle = [style objectForKey:@"show_loading"];
        
        NSString* animationName = [showLoadingStyle objectForKey:@"animation"];
        if (([animationName length] > 0) && ([animationName isEqualToString:@"none"] != YES))
        {
            self.popupViewController.disableBuiltinAnimations = NO;
            self.popupViewController.customAnimation = animationName;
        }
    }
}

- (void)applyPopupStyle
{
    assert(_appearance == isnVisualizerAppearancePopup);
    
    id isTransparent = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"transparentBackground"];
    if ([isTransparent isKindOfClass:[NSString class]] && ![isTransparent isEqualToString:@""]
        
        && (
            [[isTransparent lowercaseString] isEqualToString:@"yes"]
            || [[isTransparent lowercaseString] isEqualToString:@"true"]
            || [[isTransparent lowercaseString] isEqualToString:@"on"]
            || ([(NSString*)isTransparent intValue] != 0)
            )
        
        ){
        self.contentWebView.opaque = NO;
        self.contentWebView.backgroundColor = [UIColor clearColor];
        self.contentWebView.backgroundColor = [UIColor clearColor];
        [self.popupViewController.panel setContentColor:[UIColor clearColor]];
    }
    
    id disableBuiltinClose = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"disableBuiltinClose"];
    if ([disableBuiltinClose isKindOfClass:[NSString class]] && ![disableBuiltinClose isEqualToString:@""]
        
        && (
            [[disableBuiltinClose lowercaseString] isEqualToString:@"yes"]
            || [[disableBuiltinClose lowercaseString] isEqualToString:@"true"]
            || [[disableBuiltinClose lowercaseString] isEqualToString:@"on"]
            || ([(NSString*)disableBuiltinClose intValue] != 0)
            )
        
        ){
        self.popupViewController.panel.closeButton.hidden = YES;
    }
    else
    {
        self.popupViewController.panel.closeButton.hidden = NO;
    }
    
    id disableBuiltinAnimations = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"disableBuiltinAnimations"];
    if ([disableBuiltinAnimations isKindOfClass:[NSString class]] && ![disableBuiltinAnimations isEqualToString:@""]
        
        && (
            [[disableBuiltinAnimations lowercaseString] isEqualToString:@"yes"]
            || [[disableBuiltinAnimations lowercaseString] isEqualToString:@"true"]
            || [[disableBuiltinAnimations lowercaseString] isEqualToString:@"on"]
            || ([(NSString*)disableBuiltinAnimations intValue] != 0)
            )
        
        ){
        self.popupViewController.disableBuiltinAnimations = YES;
    }
    
    id customAnimation = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"animation"];
    if ([customAnimation isKindOfClass:[NSString class]] && ![customAnimation isEqualToString:@""]){
        self.popupViewController.customAnimation = customAnimation;
    }
    
    id removeAdsPosition = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"removeAdsPosition"];
    if ([removeAdsPosition isKindOfClass:[NSString class]] && ![removeAdsPosition isEqualToString:@""]){
        self.popupViewController.removeAdsPosition = removeAdsPosition;
    }
    
    id closePosition = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"closePosition"];
    if ([closePosition isKindOfClass:[NSString class]] && ![closePosition isEqualToString:@""]){
        self.popupViewController.panel.closePosition = closePosition;
    }
    
    BOOL allowVerticalScroll = NO;
    id isAllowVerticalScroll = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"allowVerticalScroll"];
    if ([isAllowVerticalScroll isKindOfClass:[NSString class]] && ![isAllowVerticalScroll isEqualToString:@""]
        
        && (
            [[isAllowVerticalScroll lowercaseString] isEqualToString:@"yes"]
            || [[isAllowVerticalScroll lowercaseString] isEqualToString:@"true"]
            || [[isAllowVerticalScroll lowercaseString] isEqualToString:@"on"]
            || ([(NSString*)isAllowVerticalScroll intValue] != 0)
            )
        
        ){
        allowVerticalScroll = YES;
    }
    
    NSMutableDictionary* description = [NSMutableDictionary new];
    
    if (allowVerticalScroll)
        [description setObject:@(YES) forKey:@"allowVerticalScroll"];
    
    [[self contentWebView] configureContentSizeScaleAndBehaviour:description];
}

-(void)applyEmbeddedStyle
{
    assert(_appearance == isnVisualizerAppearanceEmbedded);
    
    id isTransparent = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"transparentBackground"];
    if ([isTransparent isKindOfClass:[NSString class]] && ![isTransparent isEqualToString:@""]
        
        && (
            [[isTransparent lowercaseString] isEqualToString:@"yes"]
            || [[isTransparent lowercaseString] isEqualToString:@"true"]
            || [[isTransparent lowercaseString] isEqualToString:@"on"]
            || ([(NSString*)isTransparent intValue] != 0)
            )
        
        ){
        self.contentWebView.opaque = NO;
        self.contentWebView.backgroundColor = [UIColor clearColor];
        self.contentWebView.backgroundColor = [UIColor clearColor];
        [self.embeddedPanel setBackgroundColor:[UIColor clearColor]];
    }
    
    BOOL allowVerticalScroll = NO;
    id isAllowVerticalScroll = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"allowVerticalScroll"];
    if ([isAllowVerticalScroll isKindOfClass:[NSString class]] && ![isAllowVerticalScroll isEqualToString:@""]
        
        && (
            [[isAllowVerticalScroll lowercaseString] isEqualToString:@"yes"]
            || [[isAllowVerticalScroll lowercaseString] isEqualToString:@"true"]
            || [[isAllowVerticalScroll lowercaseString] isEqualToString:@"on"]
            || ([(NSString*)isAllowVerticalScroll intValue] != 0)
            )
        
        ){
        allowVerticalScroll = YES;
    }
    
    NSMutableDictionary* description = [NSMutableDictionary new];
    
    if (allowVerticalScroll)
        [description setObject:@(YES) forKey:@"allowVerticalScroll"];
    
    [[self contentWebView] configureContentSizeScaleAndBehaviour:description];
}

#if JS_CONTEXT
-(JSContext*) _getJSContext
{
    JSContext* context = nil;
    
    @try
    {
        NSString* keyPath = @"documentView.webView.mainFrame.javaScriptContext";
        assert([@"documentView.webView.mainFrame.javaScriptContext" isEqualToString:keyPath]);
        context = [self.contentWebView valueForKeyPath:keyPath]; // Undocumented access to UIWebView's JSContext
    }
    @catch(NSException* e)
    {
        context = nil;
    }
    
    return context;
}
#endif

-(iSmartNewsVisualizerInjectDataState) webViewInjectData
{
#if JS_CONTEXT
    assert(_injectContext == nil);
    
    _injectContext = [self _getJSContext];
    JSValue* injectDataValue   = [_injectContext.globalObject valueForProperty:@"injectdata"];

    NSObject* injectDataObject = [injectDataValue toObject];
#else
    NSString* injectDataString = [self.contentWebView stringByEvaluatingJavaScriptFromString:@"(function(){ try{ if(typeof injectdata !== 'undefined'){ return JSON.stringify(injectdata);} return null;} catch(e){return null;}; })();"];
    NSObject* injectDataObject = nil;
    if ([injectDataString length] > 0)
    {
        NSError* error = nil;
        @try
        {
            injectDataObject = [NSJSONSerialization JSONObjectWithData:[injectDataString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableLeaves error:&error];
        }
        @catch(NSException* e)
        {
            injectDataObject = nil;
        }
        
        if (error != nil)
            injectDataObject = nil;
    }
#endif
    
    if (injectDataObject == nil)
    {
        return iSmartNewsVisualizerInjectNotNeed;
    }
    else
    {
        if ([injectDataObject isKindOfClass:[NSDictionary class]] != YES)
        {
            iSmartNewsLog(@"visualizer : webViewInjectData : injectData in not object");
            return iSmartNewsVisualizerInjectWasFailed;
        }
        
        if ([(NSDictionary*)injectDataObject count] == 0)
        {
            iSmartNewsLog(@"visualizer : webViewInjectData : injectData was empty");
            return iSmartNewsVisualizerInjectWasFailed;
        }
        
        assert(_injectData    == nil);
        assert(_newInjectData == nil);
        
        _injectData    = [(NSDictionary*)injectDataObject mutableCopy];
        _newInjectData = [NSMutableDictionary new];
        
        [self performSelector:@selector(_webViewInjectData) withObject:nil afterDelay:0.0f];
        
        return iSmartNewsVisualizerInjectWasStarted;
    }
}

-(void) _webViewInjectData
{
    if ([_injectData count] == 0)
    {
        if ([_newInjectData count] == 0)
        {
            iSmartNewsLog(@"visualizer : webViewInjectData : new injectData was empty");
            [self webViewFailedShowHandler];
            return;
        }
        
        iSmartNewsLog(@"visualizer : webViewInjectData : update injectData and show");
        
#if JS_CONTEXT
        assert(_injectContext != nil);
        JSValue* value = [JSValue valueWithObject:_newInjectData inContext:_injectContext];
        
        [_injectContext.globalObject setValue:value forProperty:@"injectdata"];
        
        JSValue* refreshMethod = [_injectContext objectForKeyedSubscript:@"updateTextElements"];
        
        if ([refreshMethod isObject])
        {
            @try
            {
                [refreshMethod callWithArguments:@[]];
                
                _injectContext = nil;
                _appearanceStyle = nil;
                [self webViewConfigureAndShow];
            }
            @catch(NSException* e)
            {
                [self webViewFailedShowHandler];
            }
        }
        else
        {
            [self webViewFailedShowHandler];
        }
#else
        NSError* error = nil;
        NSData* newInjectDataRaw = [NSJSONSerialization dataWithJSONObject:_newInjectData options:0 error:&error];
        NSString* newInjectDataString = [[NSString alloc] initWithData:newInjectDataRaw encoding:NSUTF8StringEncoding];
        
        NSString* refreshCode = [NSString stringWithFormat:@"(function(){ injectdata = %@; updateTextElements(); return \"sucessfull\";})();", newInjectDataString];
        NSString* result = [self.contentWebView stringByEvaluatingJavaScriptFromString:refreshCode];
        
        if ([result isEqualToString:@"sucessfull"])
        {
            _appearanceStyle = nil;
            _ready = YES;
            [self webViewConfigureAndShow];
        }
        else
        {
            [self webViewFailedShowHandler];
        }
#endif
        
#if JS_CONTEXT
        _injectContext = nil;
#endif
        return;
    }
    
    assert([_injectData count] > 0);
    

    //Get single objects
    NSString* additionalObjectName = [[_injectData allKeys] firstObject];
    
    NSDictionary* additionalObjectDescription = [_injectData objectForKey:additionalObjectName];
    [_injectData removeObjectForKey:additionalObjectName];
    
    if (gAdditionalObjectDescriptionsGetter == nil)
    {
        [self webViewFailedShowHandler];
        return;
    }

    BOOL additionalObjectDescriptionsGetterWasRunning = gAdditionalObjectDescriptionsGetter(additionalObjectDescription, ^(NSDictionary* descriptions, BOOL success) {
        
        if (success != YES)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self webViewFailedShowHandler];
            });
            return;
        }
        
        assert(  ([descriptions count] == 0) ||
                (([descriptions count] == 1) && ([[[descriptions allKeys] firstObject] isEqualToString:additionalObjectName])));
        
        NSMutableDictionary* newAdditionalObjectDescription = [additionalObjectDescription mutableCopy];
        NSDictionary* returnedAdditionalObjectDescription   = [descriptions objectForKey:additionalObjectName];
        
        [newAdditionalObjectDescription addEntriesFromDictionary:returnedAdditionalObjectDescription];
         
        @synchronized(self)
        {
            [_newInjectData setObject:newAdditionalObjectDescription forKey:additionalObjectName];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self _webViewInjectData];
        });
    });
    
    //Restore value
    if (additionalObjectDescriptionsGetterWasRunning == NO)
    {
        @synchronized(self)
        {
            [_newInjectData setObject:additionalObjectDescription forKey:additionalObjectName];
        }
     
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self _webViewInjectData];
        });
    }
}

#pragma mark - Actions & Notifications

-(NSString*) isCallBackURL:(NSURL*) url
{
    assert(0 && "Call delegate for this");
    return [[self delegate] isCallBackURL:url];
}

-(void) callBackProcessing:(NSURL*) url callType:(NSString*) callType notifyAboutClose:(NSString*) closeType
{
    NSDictionary* userInfo = [[self delegate] makeUserInfoForCallBackURL:url callType:callType uuid:self.metaUUID];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickCallback:userInfo:) userInfo:userInfo];
        
        if ([closeType length] > 0)
        {
            [self _notifyAboutClose:closeType];
        }
    });
}

-(void)setIsPresented:(BOOL)presented
{
    if (_presented != presented)
    {
        _presented = presented;
        
        if (_presented)
        {
            if ((self.stateNotificationReceiver != nil) && ([self.stateNotificationReceiver respondsToSelector:@selector(visualizerWillShowMessage:)]))
            {
                [self.stateNotificationReceiver visualizerWillShowMessage:self];
            }
        }
        else
        {
            if ((self.stateNotificationReceiver != nil) && ([self.stateNotificationReceiver respondsToSelector:@selector(visualizerFinishedShowingMessage:)]))
            {
                [self.stateNotificationReceiver visualizerFinishedShowingMessage:self];
            }
        }
    }
}

- (void)_notifyAboutClose:(NSString*)type
{
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:iSmartNewsDidCloseNewsItemNotification
                                                                                          object:[self owner]
                                                                                        userInfo:@{@"uuid":(self.metaUUID?self.metaUUID:@"null"),@"type":type}]
                                               postingStyle:NSPostWhenIdle];
}

- (void)postOnShow
{
    if (self.shownBlock)
    {
        self.shownBlock();
        self.shownBlock = nil;
    }
    
    if (self.onShow)
    {
        NSURL* onShowURL = [NSURL URLWithString:self.onShow];
        
        NSString* callBackType = [[self delegate] isCallBackURL:onShowURL];
        
        if ([callBackType length] > 0)
        {
            //For disable any "close/hide" actions
            [self callBackProcessing:onShowURL callType:@"callquietly" notifyAboutClose:nil];
        }
        else
        {
            NSString* s = [self.onShow stringByReplacingOccurrencesOfString:@"${VID}" withString:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
            
            if ([s rangeOfString:@"${URL}"].location != NSNotFound){
                if (_url){
                    NSCharacterSet *chars = NSCharacterSet.URLQueryAllowedCharacterSet;
                    NSString* encodedString = [[_url absoluteString] stringByAddingPercentEncodingWithAllowedCharacters:chars];
                    s = [s stringByReplacingOccurrencesOfString:@"${URL}" withString:encodedString];
                }
                else {
                    s = [s stringByReplacingOccurrencesOfString:@"${URL}" withString:@"alert"];
                }
            }
            
            NSURL* url = [NSURL URLWithString:s];
            if (url){
                NSURLRequest* request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10];
                [SNShowUIWebView webViewWithRequest:request];
            }
        }
    }
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:iSmartNewsDidShowNewsItemNotification
                                                                                          object:[self owner]
                                                                                        userInfo:@{@"uuid":(self.metaUUID?self.metaUUID:@"null")}]
                                               postingStyle:NSPostWhenIdle];
}

- (void)callDelegateAndExtendLifeForOneMoreRunloopCycle:(SEL)aSelector
{
    [self callDelegateAndExtendLifeForOneMoreRunloopCycle:aSelector userInfo:nil];
}

- (void)callDelegateAndExtendLifeForOneMoreRunloopCycle:(SEL)aSelector userInfo:(id)userInfo
{
    // to be should we are alive after [delegate visualizerDidFail:self];
    // problem found by Stepan Gulyi:
    // 2016-12-09 13:58:00.266203 Voice Translator[4151:836286] *** -[iSmartNewsVisualizer _notifyAboutClose:]: message sent to deallocated instance 0x174762340
    dispatch_async(dispatch_get_main_queue(), ^{
        [self description];
    });
    
    id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
    //self.delegate = nil;
    
    NSUInteger numberOfParameters = 0;
    NSString* aSelectorName = NSStringFromSelector(aSelector);
    NSUInteger colonPosition  = [aSelectorName length];
    while(([aSelectorName length] > 0) && (colonPosition != NSNotFound))
    {
        colonPosition = ([aSelectorName rangeOfString:@":" options:NSBackwardsSearch range:NSMakeRange(0, colonPosition)]).location;
        
        if (colonPosition != NSNotFound)
            numberOfParameters++;
        else
            break;
    }
    
    assert(numberOfParameters >= 1);
    
    if ([delegate respondsToSelector:aSelector]){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        switch (numberOfParameters)
        {
            case 2:     [delegate performSelector:aSelector withObject:self withObject:userInfo]; break;
            case 1:
            default:    [delegate performSelector:aSelector withObject:self]; break;
        }
#pragma clang diagnostic pop
    }
}

- (void)forceHide
{
    [_showDelayTimer invalidate];
    _showDelayTimer = nil;
    
    if (_alertView)
    {
        [_alertView setDelegate:nil];
        
        if (_shown)
        {
            [_alertView dismissWithClickedButtonIndex:_alertView.cancelButtonIndex animated:NO];
        }
        else
        {
            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickNothing:)];
            [self _notifyAboutClose:@"nothing"];
        }
        
        _alertView = nil;
    }
    else
    {
        iSmartNewsLog(@"visualizer : forceHide -> closeWebView");
        [self closeWebView];
    }
}

- (BOOL)respondsToSelector:(SEL)aSelector{
    return [super respondsToSelector:aSelector];
}

- (void)closeWebView
{
    if (_closing || _closed)
    {
        iSmartNewsLog(@"visualizer : closeWebView - rejected");
        return;
    }
    
    iSmartNewsLog(@"visualizer : closeWebView");
    
    BOOL logicallyShown = _shown;
    
    _closing = YES;
    
    [self.contentWebView setDelegate:[UIWebViewStopLoadDelegate sharedInstanse]];
    [self.contentWebView stopLoading];
    
    if (!logicallyShown)
    {
        [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickNothing:)];
        [self _notifyAboutClose:@"nothing"];
        
        if (!_presented)
        {
            iSmartNewsLog(@"visualizer : closeWebView - not logically shown");
            return;
        }
    }
    
    //Notify panel for start hide animation
    //Or manual hide
    if (self.popupViewController.panel)
    {
        iSmartNewsLog(@"visualizer : closeWebView - hide panel");
        [self.popupViewController.panel hide:iSmartNewsPanelCloseForced];
    }
    else
    {
        iSmartNewsLog(@"visualizer : closeWebView - directly cleanup");
        [self cleanupWebView];
        
        _closing = NO;
        _closed = YES;
    }
    
    [self setIsPresented:NO];
}

- (void)cleanupWebView
{
    if (!_presented)
    {
        iSmartNewsLog(@"visualizer : cleanupWebView - check rejection conditions");
        
        if ((self.contentWebView == nil) || (_appearance != isnVisualizerAppearancePopup))
        {
            iSmartNewsLog(@"visualizer : cleanupWebView - rejected");
            return;
        }
    }
    
    iSmartNewsLog(@"visualizer : cleanupWebView - start");
    
    _presented = NO;
    
    const BOOL cleaning = (self.contentWebView != nil);
    
    if (_appearance == isnVisualizerAppearancePopup)
    {
        if (!self.popupWindow)
        {
            iSmartNewsLog(@"visualizer : cleanupWebView - empty window = break");
            return;
        }

        [self.popupViewController forceUnload];
        
        [self.popupViewController.panel placeContent:nil];
        [self.popupViewController.panel removeFromSuperview];
        
        self.popupViewController.panel.delegate = nil;
        self.popupViewController.panel = nil;
        
        // NOTE: iOS will make previous key automatically! And proper window become active.
        
        if ([[self.popupWindow rootViewController] isKindOfClass:[UINavigationController class]]){
            UIViewController* controller = [[(UINavigationController*)[self.popupWindow rootViewController] viewControllers] objectAtIndex:0];
            if ([controller isKindOfClass:[iSmartNewsPopupViewController class]]){
                [(iSmartNewsPopupViewController*)controller restoreStatusBar:NO];
            }
        }
        
        [self.popupWindow killWindow];
        
        self.popupViewController = nil;
        self.popupWindow = nil;
        
        iSmartNewsLog(@"visualizer : cleanupWebView - window killed");
    }
    else
    {
        iSmartNewsLog(@"visualizer : cleanupWebView - non popup");
    }
    
    if (!cleaning){
        return;
    }
    
    [self.contentWebView setDelegate:[UIWebViewStopLoadDelegate sharedInstanse]];
    [self.contentWebView stopLoading];
    self.contentWebView = nil;
    
    _injectData    = nil;
    _newInjectData = nil;
    
    if (_appearance == isnVisualizerAppearancePopup)
    {
        iSmartNewsLog(@"visualizer : cleanupWebView - restore");
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIWindow* w = [[UIApplication sharedApplication] keyWindow];
            if ([w isKindOfClass:[iSmartNewsWindow class]])
            {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                iSmartNewsLog(@"visualizer : cleanupWebView - restore - break");
                return;
            }
            
            UIViewController* c = [w rootViewController];
            while (c.presentedViewController)
                c = c.presentedViewController;
            
            UIViewController* vc = [UIViewController new];
            [vc.view setBackgroundColor:[UIColor clearColor]];
            [UIViewController attemptRotationToDeviceOrientation];
            
            if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
            {
                Class cls = [w.rootViewController class];
                if (cls && [NSStringFromClass(cls) rangeOfString:@"UIAlert"].location != NSNotFound)
                {
                    if (
                        (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                        || ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) && (MAX([UIScreen mainScreen].bounds.size.width,[UIScreen mainScreen].bounds.size.height) > 720.0) )// 6+
                        ){
                        // do nothing
                    }
                    else
                    {
                        [w setFrame:[[UIScreen mainScreen] bounds]];
                    }
                    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                    iSmartNewsLog(@"visualizer : cleanupWebView - non alert");
                    return;
                }
            }
            else if ([[[UIDevice currentDevice] systemVersion] floatValue] < 6.5)
            {
                [w setFrame:[[UIScreen mainScreen] bounds]];
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                iSmartNewsLog(@"visualizer : cleanupWebView - legacy");
                return;
            }
            
            if (![c isViewLoaded] && c.view.window)
            {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                iSmartNewsLog(@"visualizer : cleanupWebView - unknown");
                return;
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                iSmartNewsLog(@"visualizer : cleanupWebView - default");
            });

            if ([[[UIDevice currentDevice] systemVersion] hasPrefix:@"7."]){
                [c presentViewController:vc animated:NO completion:^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [vc dismissViewControllerAnimated:NO completion:^{
                        }];
                    });
                }];
            }
        });
    }
}

- (void)panel:(UIView<iSmartNewsPanelProtocol>*)panel didCloseWithType:(iSmartNewsPanelCloseType)type
{
    iSmartNewsLog(@"visualizer : panel - didCloseWithType %d", type);
    
    [self cleanupWebView];
    
    _closing = NO;
    _closed = YES;
    
    if (type != iSmartNewsPanelCloseForced)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (type == iSmartNewsPanelCloseSimple)
            {
                [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickCancel:)];
                [self _notifyAboutClose:@"cancel"];
            }
            else if (type == iSmartNewsPanelCloseRemoveAds)
            {
                [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickRemoveAds:)];
                [self _notifyAboutClose:@"remove_ads"];
            }
        });
    }
}

- (void)panelDidChangeStatus:(UIView<iSmartNewsPanelProtocol>*)panel
{
//    if (_appearance == isnVisualizerAppearancePopup)
//    {
//        if ([self.popupViewController.panel isReady])
//        {
//            [[self contentWebView] configureContentSizeScaleAndBehaviour:nil];
//        }
//    }
}

#pragma mark - Utils
- (void)hideKeyBoard
{
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}
@end


#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

