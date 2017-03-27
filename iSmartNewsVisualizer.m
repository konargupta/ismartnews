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

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self){
        [self sn_applyScale];
    }
    return self;
}

- (void)sn_applyScale
{
    if ([self respondsToSelector:@selector(scrollView)])
    {
        UIScrollView *scroll=[self scrollView];
        
        const float zoom1=self.bounds.size.width/scroll.contentSize.width;
        const float zoom2=self.bounds.size.height/scroll.contentSize.height;
        const float minZoom = MIN(zoom1,zoom2);
        if (minZoom > FLT_EPSILON){
            [scroll setZoomScale:minZoom animated:YES];
            NSString *jsCommand = [NSString stringWithFormat:@"document.body.style.zoom = %f;",minZoom];
            [self stringByEvaluatingJavaScriptFromString:jsCommand];
        }
    }
}

- (void)layoutSubviews{
    [super layoutSubviews];
    [self sn_applyScale];
}

-(void)dealloc
{
    iSmartNewsLog(@"SNWebView : %p dealloc", self);
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
    BOOL _presented;
    BOOL _activated;
    BOOL _shown;
    BOOL _loaded;
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
    
    //Additional
    NSTimer*  _showDelayTimer;
    NSString* _reviewType;
}

@synthesize isShown = _isShown;

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
            if (++gNewsVisualizerInstCounter == 1){
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

-(void)setIsShown:(BOOL)isShown
{
    if (_isShown != isShown)
    {
        _isShown = isShown;
        
        if (_isShown)
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

- (void)_show
{
    [_showDelayTimer invalidate];
    _showDelayTimer = nil;
    
    if (_shown){
        return;
    }
    
    _shown = YES;
    
    if (_alertView)
    {
        [self setIsShown:YES]; //Show immediately
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
        
        if (actionWasStarted == NO)//unknown action
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

#pragma warning repleace deprecated UIAlertView
#pragma clang diagnostic push                                           //UIAlertView
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark - UIAlertViewDelegate
- (void)alertViewCancel:(UIAlertView *)alertView
{
    if ( alertView != _alertView)
        return;
    
    _alertView.delegate = nil;
    
    [self setIsShown:NO];
    
    [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickCancel:)];
    [self _notifyAboutClose:@"cancel"];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView != _alertView)
        return;
    
    _alertView.delegate = nil;
    
    [self setIsShown:NO];
    
    if (buttonIndex == _cancelIndex)
    {
        [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickCancel:)];
        [self _notifyAboutClose:@"cancel"];
    }
    else
    {
        if (buttonIndex == _okIndex) {
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
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:iSmartNewsDidShowNewsItemNotification
                                                                                          object:[self owner]
                                                                                        userInfo:@{@"uuid":(self.metaUUID?self.metaUUID:@"null")}]
                                               postingStyle:NSPostWhenIdle];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (_loaded){
        return;
    }
    
    _loaded = YES;
    
    if (self.contentWebView != webView)
        return;
    
    if ([self.contentWebView isLoading])
        return;
    
    if (_presented)
        return;
    
    iSmartNewsLog(@"visualizer : webViewDidFinishLoad");
    
    _presented = YES;
    
    [self setIsShown:YES]; //Really show
    [self postOnShow];
    
    if (_appearance == isnVisualizerAppearancePopup)
    {
        iSmartNewsLog(@"visualizer : webViewDidFinishLoad : configure popup");
        [self hideKeyBoard];
    
        self.popupViewController = [iSmartNewsPopupViewController new];
        //self.popupViewController.webView = self.contentWebView;
        [self.popupViewController.panel placeContent:[self contentWebView]];
    
        [self applyPopupStyle];
    
        self.popupViewController.panel.delegate = (NSObject<iSmartNewsPanelDelegate>*)self;
    
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
        
        [self disableBadGestureRecognizer:[self contentWebView]];
    }
    else if (_appearance == isnVisualizerAppearanceEmbedded)
    {
        UIView* contentView = [self contentWebView];
        
        [self applyEmbeddedStyle];
        
        iSmartNewsLog(@"visualizer : webViewDidFinishLoad : place content to embedded %p", contentView);
        [self.embeddedPanel placeContent:contentView];
    }
    
    [self.contentWebView setScalesPageToFit:YES];
    [self.contentWebView setContentMode:UIViewContentModeScaleAspectFit];
    
    if ([self.contentWebView respondsToSelector:@selector(scrollView)])
    {
        UIScrollView *scroll = [self.contentWebView scrollView];
        
        const float zoom1 = self.contentWebView.bounds.size.width/scroll.contentSize.width;
        const float zoom2 = self.contentWebView.bounds.size.height/scroll.contentSize.height;
        const float minZoom = MIN(zoom1,zoom2);
        if (minZoom > FLT_EPSILON){
            [scroll setZoomScale:minZoom animated:YES];
            NSString *jsCommand = [NSString stringWithFormat:@"document.body.style.zoom = %f;",minZoom];
            [self.contentWebView stringByEvaluatingJavaScriptFromString:jsCommand];
        }
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
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (self.contentWebView != webView)
        return;
    
    iSmartNewsLog(@"visualizer : didFailLoadWithError");
    
    [self setIsShown:NO]; //Showing failed
    
    if (!_loaded)
    {
        [self.contentWebView setDelegate:nil];
        [self.contentWebView stopLoading];
        
        [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidFail:)];
        [self _notifyAboutClose:@"fail"];
    }
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
        [self closeWebView];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickRemoveAds:)];
            [self _notifyAboutClose:@"remove_ads"];
        });
        
        return NO;
    }
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
             (
              (  [[requestURL scheme] hasPrefix:@"callback"])
              || [[requestURL scheme] hasPrefix:@"callquietly"]
              || [[requestURL host] isEqualToString:@"callback.io"]
              || [[requestURL host] isEqualToString:@"callquietly.io"]
              )
             )
    {
        BOOL closeCurrenNews = NO;
        NSString* callType = nil;
        if ([[requestURL scheme] hasPrefix:@"callback"] || [[requestURL host] isEqualToString:@"callback.io"])
        {
            closeCurrenNews = YES;
            callType = @"callback";
        }
        else if ([[requestURL scheme] hasPrefix:@"callquietly"] || [[requestURL host] isEqualToString:@"callquietly.io"])
        {
            callType = @"callquietly";
        }
        else
        {
            callType = @"unknown";
        }
        
        if (closeCurrenNews)
        {
            [self closeWebView];
        }
        
        NSString* requestURLString = nil;
        @try{ requestURLString = [requestURL absoluteString]; } @catch(NSException* e) {requestURLString = nil; }
        
        NSDictionary* userInfo = @{
                                    @"url"  :   (requestURLString?requestURLString:@"null"),
                                    @"uuid" :   (self.metaUUID?self.metaUUID:@"null"),
                                    @"type" :   callType
                                  };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickCallback:userInfo:) userInfo:userInfo];
            
            if (closeCurrenNews)
            {
                [self _notifyAboutClose:@"callback"];
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
                [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickLink:)];
                [self _notifyAboutClose:@"link"];
            });
        }
        
        return ok;
    }
    
    return YES;
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
}

- (NSURL*)url{
    return _url;
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
        
        if (_shown){
            [_alertView dismissWithClickedButtonIndex:_alertView.cancelButtonIndex animated:NO];
        }
        else {
            [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickNothing:)];
            [self _notifyAboutClose:@"nothing"];
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
    
    [self setIsShown:NO];
    
    _closing = YES;
    
    [self.contentWebView setDelegate:nil];
    [self.contentWebView stopLoading];
    
    if (!_shown){
        [self callDelegateAndExtendLifeForOneMoreRunloopCycle:@selector(visualizerDidClickNothing:)];
        [self _notifyAboutClose:@"nothing"];
        return;
    }
    
    //Notify panel for start hide animation
    //Or manual hide
    if (self.popupViewController.panel)
    {
        [self.popupViewController.panel hide:iSmartNewsPanelCloseForced];
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
    
    const BOOL cleaning = (self.contentWebView != nil);
    
    if (_appearance == isnVisualizerAppearancePopup)
    {
        if (!self.popupWindow){
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
    }
    else
    {
        iSmartNewsLog(@"visualizer : cleanupWebView");
    }
    
    if (!cleaning){
        return;
    }
    
    [self.contentWebView setDelegate:nil];
    [self.contentWebView stopLoading];
    self.contentWebView = nil;
    
    
    if (_appearance == isnVisualizerAppearancePopup)
    {
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
}

- (void)panel:(UIView<iSmartNewsPanelProtocol>*)panel didCloseWithType:(iSmartNewsPanelCloseType)type
{
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
    if (_appearance == isnVisualizerAppearancePopup)
    {
        if ([self.popupViewController.panel isReady])
        {
            [self disableBadGestureRecognizer:[self contentWebView]];
        }
    }
}

#pragma mark - Utils

- (void)disableBadGestureRecognizer:(UIView*)view
{

}

@end


#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

