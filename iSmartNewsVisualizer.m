//
//  iSmartNewsVisualizer.m
//  iSmartNewsDemo
//
//

#if SMARTNEWS_COMPILE

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsVisualizer.h"
#import <UIKit/UIKit.h>
#import "iSmartNewsZip.h"

#ifndef STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO
# define STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#endif

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

@implementation SNWebView
@end

@interface iSmartNewsVisualizer() <UIAlertViewDelegate>
@property (nonatomic,strong) iSmartNewsWindow*                   popupWindow;
@property (nonatomic,strong) SNWebView*                          popupWebView;
@property (nonatomic,strong) iSmartNewsPopupViewController*      popupViewController;
@end

static int gNewsVisualizerInstCounter = 0;

@implementation iSmartNewsVisualizer {
    BOOL _presented;
    NSInteger _okIndex;
    NSInteger _reviewIndex;
    NSInteger _remindIndex;
    NSInteger _cancelIndex;
    NSURL* _url;
    UIAlertView*    _alertView;
    BOOL _showRemoveAdsButton;
    BOOL _activated;
    BOOL _shown;
    BOOL _loaded;
    NSString* _localWeb;
    NSTimer*    _delayTimer;
    BOOL _closing;
    BOOL _closed;
}

- (id)initAlertViewVisualizerWithTitle:(NSString*)title message:(NSString*)message cancel:(NSString*)cancel ok:(NSString*)ok review:(NSString*)review remind:(NSString*)remind
{
    self = [super init];
    if (self)
    {
        if (++gNewsVisualizerInstCounter == 1){
            [[NSNotificationCenter defaultCenter] postNotificationName:@"iSmartNewsWillShowNotification" object:nil];
        }
        
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
        
        if (nButtons <= 2){
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
        else {
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
    }
    return self;
}

- (void)dealloc
{
    void (^notify)() = ^{
        if (--gNewsVisualizerInstCounter == 0){
            [[NSNotificationCenter defaultCenter] postNotificationName:@"iSmartNewsDidHideNotification" object:nil];
        }
    };
    
    if ([NSThread isMainThread]){
        notify();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), [notify copy]);
    }
    
    if (_localWeb)
    {
        [[NSFileManager defaultManager] removeItemAtPath:_localWeb error:NULL];
    }
}

- (id)initWebViewVisualizerWithURL:(NSURL*)url showRemoveAdsButton:(BOOL)showRemoveAdsButton
{
    self = [super init];
    if (self)
    {
        if (!url)
        {
            self = nil;
            return nil;
        }
        
        if (++gNewsVisualizerInstCounter == 1){
            [[NSNotificationCenter defaultCenter] postNotificationName:@"iSmartNewsWillShowNotification" object:nil];
        }
        
        _url = url;
        _showRemoveAdsButton = showRemoveAdsButton;
    }
    return self;
}

- (void)hideKeyBoard
{
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

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

- (void)_show
{
    [_delayTimer invalidate];
    _delayTimer = nil;
    
    if (_shown){
        return;
    }
    
    _shown = YES;
    
    if (_alertView)
    {
        [self postOnShow];
        [self hideKeyBoard];
        [_alertView show];
    }
    else
    {
        if ([[[_url absoluteString] pathExtension] isEqualToString:@"zip"])
        {
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
                                                   id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
                                                   self.delegate = nil;
                                                   
                                                   if ([delegate respondsToSelector:@selector(visualizerDidFail:)]){
                                                       [delegate visualizerDidFail:self];
                                                   }
                                               });
                                               return;
                                           }
                                           
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               self.popupWebView = [[SNWebView alloc] initWithFrame:CGRectMake(0,0,1,1)];
                                               self.popupWebView.accessibilityLabel = @"iSNWeb";
                                               self.popupWebView.accessibilityHint = @"iSNWeb";
                                               self.popupWebView.accessibilityIdentifier = @"iSNWeb";
                                               [self.popupWebView setDelegate:(id<UIWebViewDelegate>)self];
                                               [self.popupWebView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[_localWeb stringByAppendingPathComponent:@"index.html"]]]];
                                           });
                                       });
                                   }];
        }
        else
        {
            self.popupWebView = [[SNWebView alloc] initWithFrame:CGRectMake(0,0,1,1)];
            self.popupWebView.accessibilityLabel = @"iSNWeb";
            self.popupWebView.accessibilityHint = @"iSNWeb";
            self.popupWebView.accessibilityIdentifier = @"iSNWeb";
            [self.popupWebView setDelegate:(id<UIWebViewDelegate>)self];
            [self.popupWebView loadRequest:[NSURLRequest requestWithURL:_url]];
        }
    }
}

- (void)show
{
    if (_activated){
        return;
    }
    
    _activated = YES;
    
    if (self.delayRange.location == 0 && self.delayRange.length == 0){
        [self _show];
    }
    else {
        const NSUInteger delay = self.delayRange.location + arc4random_uniform((uint32_t)self.delayRange.length);
        _delayTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(_show) userInfo:nil repeats:NO];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertViewCancel:(UIAlertView *)alertView
{
    if ( alertView != _alertView)
        return;
    
    _alertView.delegate = nil;
    
    id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
    self.delegate = nil;
    
    if ([delegate respondsToSelector:@selector(visualizerDidClickCancel:)]){
        [delegate visualizerDidClickCancel:self];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView != _alertView)
        return;
    
    _alertView.delegate = nil;
    
    if (buttonIndex == _cancelIndex)
    {
        id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
        self.delegate = nil;
        
        if ([delegate respondsToSelector:@selector(visualizerDidClickCancel:)]){
            [delegate visualizerDidClickCancel:self];
        }
    }
    else
    {
        if (buttonIndex == _okIndex){
            
            id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
            self.delegate = nil;
            
            if ([delegate respondsToSelector:@selector(visualizerDidClickOk:)]){
                [delegate visualizerDidClickOk:self];
            }
        }
        else if (buttonIndex == _reviewIndex){

            
                if (self.iTunesId)
                {
                    NSURL* url = [self reviewURL:self.iTunesId];
                    if (url
                        && [[UIApplication sharedApplication] canOpenURL:url]
                        && [[UIApplication sharedApplication] openURL:url])
                    {
                        id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
                        self.delegate = nil;
                        
                        if ([delegate respondsToSelector:@selector(visualizerDidClickOpenReview:)]){
                            [delegate visualizerDidClickOpenReview:self];
                        }
                    }
                    else
                    {
                        id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
                        self.delegate = nil;
                        
                        if ([delegate respondsToSelector:@selector(visualizerDidFail:)]){
                            [delegate visualizerDidFail:self];
                        }
                    }
                }
                else
                {
                    id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
                    self.delegate = nil;
                    
                    if ([delegate respondsToSelector:@selector(visualizerDidFail:)]){
                        [delegate visualizerDidFail:self];
                    }
                }

        }
        else if (buttonIndex == _remindIndex){
            
            id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
            self.delegate = nil;
            
            if ([delegate respondsToSelector:@selector(visualizerDidClickRemindLaterReview:)]){
                [delegate visualizerDidClickRemindLaterReview:self];
            }
        }
    }
}

#pragma mark -

- (void)postOnShow
{
    if (self.shownBlock)
    {
        self.shownBlock();
        self.shownBlock = nil;
    }
    
    if (self.onShow){
        
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

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (_loaded){
        return;
    }
    
    _loaded = YES;
    
    if (self.popupWebView != webView)
        return;
    
    if ([self.popupWebView isLoading])
        return;
    
    if (_presented)
        return;
    
    _presented = YES;
    
    [self postOnShow];
    [self hideKeyBoard];
    
    self.popupViewController = [iSmartNewsPopupViewController new];
    self.popupViewController.webView = self.popupWebView;
    
    id isTransparent = [self.popupWebView stringByEvaluatingJavaScriptFromString:@"transparentBackground"];
    if ([isTransparent isKindOfClass:[NSString class]] && ![isTransparent isEqualToString:@""]
        
        && (
            [[isTransparent lowercaseString] isEqualToString:@"yes"]
            || [[isTransparent lowercaseString] isEqualToString:@"true"]
            || [[isTransparent lowercaseString] isEqualToString:@"on"]
            || ([(NSString*)isTransparent intValue] != 0)
            )
        
        ){
        self.popupWebView.opaque = NO;
        self.popupWebView.backgroundColor = [UIColor clearColor];
        self.popupWindow.backgroundColor = [UIColor clearColor];
        [self.popupViewController.panel setContentColor:[UIColor clearColor]];
    }

    id disableBuiltinClose = [self.popupWebView stringByEvaluatingJavaScriptFromString:@"disableBuiltinClose"];
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
    
    id disableBuiltinAnimations = [self.popupWebView stringByEvaluatingJavaScriptFromString:@"disableBuiltinAnimations"];
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
    
    id customAnimation = [self.popupWebView stringByEvaluatingJavaScriptFromString:@"animation"];
    if ([customAnimation isKindOfClass:[NSString class]] && ![customAnimation isEqualToString:@""]){
        self.popupViewController.customAnimation = customAnimation;
    }
    
    id removeAdsPosition = [self.popupWebView stringByEvaluatingJavaScriptFromString:@"removeAdsPosition"];
    if ([removeAdsPosition isKindOfClass:[NSString class]] && ![removeAdsPosition isEqualToString:@""]){
        self.popupViewController.removeAdsPosition = removeAdsPosition;
    }
    
    id closePosition = [self.popupWebView stringByEvaluatingJavaScriptFromString:@"closePosition"];
    if ([closePosition isKindOfClass:[NSString class]] && ![closePosition isEqualToString:@""]){
        self.popupViewController.panel.closePosition = closePosition;
    }
    
    self.popupViewController.panel.delegate = (NSObject<iSmartNewsModalPanelDelegate>*)self;
    
    self.popupWindow = [iSmartNewsWindow newsWindow];
    self.popupWindow.orientationMask = self.orientationMask;
    self.popupWindow.windowLevel = UIWindowLevelAlert + 1;
    [self.popupWindow setBackgroundColor:[UIColor clearColor]];
    
    iSmartNewsPopupNavigationController* ctrl = [[iSmartNewsPopupNavigationController alloc] initWithRootViewController:self.popupViewController];
    ctrl.allowAllIphoneOrientations = self.allowAllIphoneOrientations;
    
    if (self.orientationMask != 0){
        ctrl.orientationMask = self.orientationMask;
    }
    self.popupWindow.rootViewController = ctrl;
    [self.popupWindow makeKeyAndVisible];
    
    if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
        ctrl.view.frame = ctrl.view.superview.bounds;
    
    [self.popupWebView setScalesPageToFit:YES];
    [self.popupWebView setContentMode:UIViewContentModeScaleAspectFit];
    
    if ([self.popupWebView respondsToSelector:@selector(scrollView)])
    {
        UIScrollView *scroll=[self.popupWebView scrollView];
        
        const float zoom1=self.popupWebView.bounds.size.width/scroll.contentSize.width;
        const float zoom2=self.popupWebView.bounds.size.height/scroll.contentSize.height;
        [scroll setZoomScale:MIN(zoom1,zoom2) animated:YES];
        
        NSString *jsCommand = [NSString stringWithFormat:@"document.body.style.zoom = %f;",MIN(zoom1,zoom2)];
        [self.popupWebView stringByEvaluatingJavaScriptFromString:jsCommand];
    }
    
    [UIView animateWithDuration:0.35 animations:^ { [self.popupWebView setAlpha:1.f]; }];
    
    if (_showRemoveAdsButton)
    {
        self.popupViewController.panel.showRemoveAdsButton = YES;
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (self.popupWebView != webView)
        return;
    
    if (!_loaded)
    {
        [self.popupWebView setDelegate:nil];
        [self.popupWebView stopLoading];
        
        id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
        self.delegate = nil;
        
        if ([delegate respondsToSelector:@selector(visualizerDidFail:)]){
            [delegate visualizerDidFail:self];
        }
    }
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
{
    if (self.popupWebView != webView)
        return YES;
    
    NSURL *requestURL =[request URL];
    
    if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
        (
         ([[requestURL scheme] hasPrefix:@"close"])
         || [[requestURL host] isEqualToString:@"close.io"]
         || [[requestURL host] isEqualToString:@"cancel.io"]
         )
        )
    {
        [self closeWebView];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
            self.delegate = nil;
            
            if ([delegate respondsToSelector:@selector(visualizerDidClickNothing:)]){
                [delegate visualizerDidClickNothing:self];
            }
        });
        
        return NO;
    }
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
                 (
                  [[requestURL host] isEqualToString:@"review.io"]
                 ))
    {
        [self closeWebView];
        
        NSArray* pathComponents = [[requestURL pathComponents] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return ![evaluatedObject isEqualToString:@"/"];
        }]];

        if ([pathComponents count] >= 1
            &&  ([@[@"open",@"cancel",@"remind"] indexOfObject:[pathComponents firstObject]] != NSNotFound)){
            
            NSString* actionType = [pathComponents firstObject];
            
            if ([actionType isEqualToString:@"open"]){
                
                UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    
                    NSString* appId = [pathComponents count] > 1 ? [pathComponents lastObject] : self.iTunesId;
                    if (appId){
                        NSURL* url = [self reviewURL:appId];
                        if (url && [[UIApplication sharedApplication] canOpenURL:url]){
                            [[UIApplication sharedApplication] openURL:url];
                        }
                    }
                    
                    [[UIApplication sharedApplication] endBackgroundTask:task];
                });

                dispatch_async(dispatch_get_main_queue(), ^{
                    id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
                    self.delegate = nil;
                    
                    if ([delegate respondsToSelector:@selector(visualizerDidClickOpenReview:)]){
                        [delegate visualizerDidClickOpenReview:self];
                    }
                });
            }
            else if ([actionType isEqualToString:@"cancel"]){
                dispatch_async(dispatch_get_main_queue(), ^{
                    id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
                    self.delegate = nil;
                    
                    if ([delegate respondsToSelector:@selector(visualizerDidClickCancelReview:)]){
                        [delegate visualizerDidClickCancelReview:self];
                    }
                });
            }
            else if ([actionType isEqualToString:@"remind"]){
                dispatch_async(dispatch_get_main_queue(), ^{
                    id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
                    self.delegate = nil;
                    
                    if ([delegate respondsToSelector:@selector(visualizerDidClickRemindLaterReview:)]){
                        [delegate visualizerDidClickRemindLaterReview:self];
                    }
                });
            }
        }
        else {
            UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
                self.delegate = nil;
                
                if ([delegate respondsToSelector:@selector(visualizerDidClickNothing:)]){
                    [delegate visualizerDidClickNothing:self];
                }
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
        [self closeWebView];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
            self.delegate = nil;
            
            if ([delegate respondsToSelector:@selector(visualizerDidClickRemoveAds:)]){
                [delegate visualizerDidClickRemoveAds:self];
            }
        });
        
        return NO;
    }
    else if (([[requestURL scheme] hasPrefix:@"http"]) && (navigationType == UIWebViewNavigationTypeLinkClicked))
    {
        BOOL ok = ![[UIApplication sharedApplication] openURL:requestURL];
        
        if (!ok)
        {
            [self closeWebView];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
                self.delegate = nil;
                
                if ([delegate respondsToSelector:@selector(visualizerDidClickNothing:)]){
                    [delegate visualizerDidClickNothing:self];
                }
            });
        }
        
        return ok;
    }
    
    return YES;
}

- (NSURL*)url{
    return _url;
}

- (void)forceHide
{
    [_delayTimer invalidate];
    _delayTimer = nil;
    
    if (_alertView)
    {
        [_alertView setDelegate:nil];
        
        if (_shown){
            [_alertView dismissWithClickedButtonIndex:_alertView.cancelButtonIndex animated:NO];
        }
        else {
            id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
            self.delegate = nil;
            
            if ([delegate respondsToSelector:@selector(visualizerDidClickNothing:)]){
                [delegate visualizerDidClickNothing:self];
            }
        }
        
        _alertView = nil;
    }
    else
    {
        [self closeWebView];
    }
}

- (BOOL)respondsToSelector:(SEL)aSelector{
    return [super respondsToSelector:aSelector];
}

- (void)closeWebView
{
    if (_closing || _closed){
        return;
    }
    
    _closing = YES;
    
    [self.popupWebView setDelegate:nil];
    [self.popupWebView stopLoading];
    
    if (!_shown){
        
        id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
        self.delegate = nil;
        
        if ([delegate respondsToSelector:@selector(visualizerDidClickNothing:)]){
            [delegate visualizerDidClickNothing:self];
        }
        return;
    }
    
    if (self.popupViewController.panel)
    {
        [self.popupViewController.panel hide:iSmartNewsModalPanelCloseForced];
    }
    else
    {
        [self cleanupWebView];
        
        _closing = NO;
        _closed = YES;
    }
}

- (void)cleanupWebView
{
    if (!_presented){
        return;
    }
    
    _presented = NO;
    
    const BOOL cleaning = self.popupWebView != nil;
    
    if (!self.popupWindow){
        return;
    }

    [self.popupViewController forceUnload];
    
    [self.popupViewController.webView removeFromSuperview];
    [self.popupViewController.panel removeFromSuperview];
    
    self.popupViewController.webView = nil;
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
    
    if (!cleaning){
        return;
    }
    
    [self.popupWebView setDelegate:nil];
    [self.popupWebView stopLoading];
    self.popupWebView = nil;
    
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        UIWindow* w = [[UIApplication sharedApplication] keyWindow];
        if ([w isKindOfClass:[iSmartNewsWindow class]]){
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            return;
        }
        
        UIViewController* c = [w rootViewController];
        while (c.presentedViewController)
            c = c.presentedViewController;
        
        UIViewController* vc = [UIViewController new];
        [vc.view setBackgroundColor:[UIColor clearColor]];
        [UIViewController attemptRotationToDeviceOrientation];
        
        if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")){
            Class cls = [w.rootViewController class];
            if (cls && [NSStringFromClass(cls) rangeOfString:@"UIAlert"].location != NSNotFound){
                if (
                    (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    || ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) && (MAX([UIScreen mainScreen].bounds.size.width,[UIScreen mainScreen].bounds.size.height) > 720.0) )// 6+
                    ){
                    // do nothing
                }
                else{
                    [w setFrame:[[UIScreen mainScreen] bounds]];
                }
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                return;
            }
        }
        else if ([[[UIDevice currentDevice] systemVersion] floatValue] < 6.5){
            [w setFrame:[[UIScreen mainScreen] bounds]];
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            return;
        }
        
        if (![c isViewLoaded] && c.view.window){
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            return;
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
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

- (void)didCloseModalPanel:(iSmartNewsModalPanel *)modalPanel type:(iSmartNewsModalPanelCloseType)type
{
    [self cleanupWebView];
    
    _closing = NO;
    _closed = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (type == iSmartNewsModalPanelCloseSimple){
            
            id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
            self.delegate = nil;
            
            if ([delegate respondsToSelector:@selector(visualizerDidClickCancel:)]){
                [delegate visualizerDidClickCancel:self];
            }
        }
        else if (type == iSmartNewsModalPanelCloseRemoveAds){
            
            id<iSmartNewsVisualizerDelegate> delegate = self.delegate;
            self.delegate = nil;
            
            if ([delegate respondsToSelector:@selector(visualizerDidClickRemoveAds:)]){
                [delegate visualizerDidClickRemoveAds:self];
            }
        }
    });
}

- (NSURL*)reviewURL:(NSString*)iTunesId
{
    if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.1")){
        return [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@",iTunesId]];
    }else if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")){
        return [NSURL URLWithString:[NSString stringWithFormat:@"http://itunes.apple.com/app/id%@",iTunesId]];
    }
    else{
        return [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@",iTunesId]];
    }
}

@end

#endif//#if SMARTNEWS_COMPILE
