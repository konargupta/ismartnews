//
//  iSmartNewsEmbeddedPanel.m
//  SmartNewsEmbeded
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsEmbeddedPanel.h"
#import "iSmartNewsInternal.h"

const NSTimeInterval defaultAutoHideInterval = 10.0f;
const NSTimeInterval minAutoHideInterval     = 10.0f;

@interface iSmartNewsEmbeddedPanel()<iSmartNewsDisplayListDelegate, iSmartNewsVisualizerStateNotificationReceiver>
@end

@implementation iSmartNewsEmbeddedPanel
{
    BOOL _isReady;
    BOOL _isActive;
    iSmartNewsDisplayList* _displayList;
    
    NSTimer* _rotationTimer;
    NSTimer* _reloadTimer;
    
    UIView* _contentView;
    
    NSMutableArray* _currentRotationEvents;
}

@synthesize delegate;

@synthesize isReady = _isReady;
@synthesize isActive = _isActive;

-(void)_initInternal
{
    _displayList = [[iSmartNewsDisplayList alloc] init];
    [_displayList setVisualizerAppearance:isnVisualizerAppearanceEmbedded];
    [_displayList setVisualizerEmbeddedPanel:self];
    
    [_displayList setVisualizerStateNotificationReceiver:self];
    
    [_displayList setDelegate:self];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self _initInternal];
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self _initInternal];
    }
    return self;
}

-(void)dealloc
{
    [self setActive:NO];
    [_displayList forceHide];
}

- (void) setActive:(BOOL)active
{
    if (_isActive != active)
    {
        _isActive = active;
        
        if (active)
        {
            [self startRotationIfNeed];
        }
        else
        {
            [self invalidateRotationTimer];
        }
    }
}

-(void)setIsReady:(BOOL)isReady
{
    if (_isReady != isReady)
    {
        _isReady = isReady;
        
        if ([[self delegate] respondsToSelector:@selector(panelDidChangeStatus:)])
        {
            [[self delegate] panelDidChangeStatus:self];
        }
    }
}

- (void) assignUUID:(NSString*) uuid
{
    _uuid = uuid;
}

//Internal
- (void) newItemsAvailable
{
    if (([_displayList currentNewsMessage] == nil) && ([_displayList remainNewsMessagesCount] == 0))
    {
        [self invalidateReloadTimer];
    }
    
    [self startRotationIfNeed];
}

- (void) startRotationWithEvents:(NSArray*) events
{
    _rotationEvents = [events copy];
    
    if ([_rotationEvents count] > 0)
    {
        [self startRotationIfNeed];
    }
}

- (void) startRotationIfNeed
{
    if ([self isActive] == NO)
        return;
    
    iSmartNewsLog(@"startRotationIfNeed");
    
    //Not switch to next message - only dispatch timer
    if ([_displayList remainNewsMessagesCount] > 0)
    {
        if ([_displayList currentNewsMessage] == nil)
        {
            iSmartNewsLog(@"startRotationIfNeed : show first message");
            [_displayList showNextMessage];
        }
        
        if ([_rotationTimer isValid] == NO)
        {
            [self dispatchRotationTimerAccordingShowingMessage];
        }
    }
    else
    {
        iSmartNewsLog(@"startRotationIfNeed : reload with dispatch timer");
        [self startLoadNewMessages];
    }
}

-(void) startLoadNewMessages
{
    iSmartNewsLog(@"startLoadNewMessages");
    
    if (![self reloadTimerIsActive])
    {
        //Swith event with every load
        if ([_currentRotationEvents count] == 0)
        {
            _currentRotationEvents = [_rotationEvents mutableCopy];
        }
        
        if ([_currentRotationEvents count] > 0)
        {
            _currentEvent = [_currentRotationEvents firstObject];
            [_currentRotationEvents removeObjectAtIndex:0];
        }
        else
        {
            _currentEvent = nil;
        }
        
        iSmartNewsLog(@"startLoadNewMessages : begin");
        //For reload if need
        [self dispatchReloadTimer];
        
        //Force hide after load
        [_displayList setForceSwitchFlag];
        //Load new news by event
        [[self internalDelegate] panelDidCompleteShown:self];
    }
    
    iSmartNewsLog(@"startLoadNewMessages : skip");
}

-(iSmartNewsDisplayList *)displayList
{
    return _displayList;
}

-(void)setService:(NSString *)service
{
    _service = service;
    [_displayList setService:_service];
}

-(void)setITunesId:(NSString *)iTunesId
{
    _iTunesId = iTunesId;
}

#pragma mark - Timers
#pragma mark - Rotation
-(void) rotationTimerEvent
{
    iSmartNewsLog(@"rotationTimerEvent");
    
    [self invalidateRotationTimer];
    
    [_displayList resetEndedFlag];
    
    if ([_displayList remainNewsMessagesCount] > 0)
    {
        [_displayList forceHide];
        [_displayList showNextMessage];
    }
    else
    {
        [self startLoadNewMessages];
    }
}

-(void) invalidateRotationTimer
{
    iSmartNewsLog(@"invalidateRotationTimer");
    [_rotationTimer invalidate];
    _rotationTimer = nil;
}

-(void) dispatchRotationEventWithPeriod:(NSTimeInterval) period
{
    iSmartNewsLog(@"dispatchRotationEventWithPeriod: %2.2f", (float)period);
    [_rotationTimer invalidate];
    _rotationTimer = nil;
    
    if (period < 0.01f)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self rotationTimerEvent];
        });
    }
    else
    {
        _rotationTimer = [NSTimer scheduledTimerWithTimeInterval:period target:self selector:@selector(rotationTimerEvent) userInfo:nil repeats:NO];
    }
}
                 
- (void) dispatchRotationTimerAccordingShowingMessage
{
    iSmartNewsLog(@"dispatchRotationTimerAccordingShowingMessage");

    NSDictionary* currentMessage = [_displayList currentNewsMessage];

    NSTimeInterval rotationPeriod = 0.0f;
    NSNumber* autoHideIntervalNumber = [currentMessage valueForKey:@"autoHideInterval"];

    if (autoHideIntervalNumber != nil)
    {
        rotationPeriod = [autoHideIntervalNumber doubleValue];
        rotationPeriod = MAX(rotationPeriod, minAutoHideInterval);
    }
    else
    {
        rotationPeriod = defaultAutoHideInterval;
    }

    [self dispatchRotationEventWithPeriod:rotationPeriod];
}

#pragma mark - Reload
-(void) dispatchReloadTimer
{
    iSmartNewsLog(@"dispatchReloadTimer");
    [self invalidateReloadTimer];
    _reloadTimer = [NSTimer scheduledTimerWithTimeInterval:defaultAutoHideInterval target:self selector:@selector(reloadTimerHandler) userInfo:nil repeats:NO];
}

-(void) invalidateReloadTimer
{
    iSmartNewsLog(@"invalidateReloadTimer");
    
    [_reloadTimer invalidate];
    _reloadTimer = nil;
}

-(BOOL) reloadTimerIsActive
{
    return [_reloadTimer isValid];
}

-(void) reloadTimerHandler
{
    iSmartNewsLog(@"reloadTimerHandler");
    
    [_reloadTimer invalidate];
    _reloadTimer = nil;
    
    [self startRotationIfNeed];
}

#pragma mark - Integration

-(void)visualizerFinishedShowingMessage:(iSmartNewsVisualizer *)visualizer
{
    [self invalidateRotationTimer];
}

-(void)visualizerWillShowMessage:(iSmartNewsVisualizer *)visualizer
{
    iSmartNewsLog(@"visualizerWillShowMessage");
    [self invalidateReloadTimer];
    [self dispatchRotationTimerAccordingShowingMessage];
}

- (void) placeContent:(UIView *)content
{
    [_contentView removeFromSuperview];
    _contentView = content;
    
    if (content != nil)
    {
        content.frame = [self bounds];
        [self addSubview:content];
        
        [self disableScrollForView:content level:4];
        
        [self setIsReady:YES];
    }
    else
    {
        [self setIsReady:NO];
    }
}

-(void)disableScrollForView:(UIView*) view level:(NSUInteger) level
{
    if ([view isKindOfClass:[UIScrollView class]])
    {
        UIScrollView* scrollView = (UIScrollView*)view;
        scrollView.scrollEnabled = NO;
        return;
    }
    else
    {
        if (--level == 0)
            return;

        for (UIView* subview in [view subviews])
        {
            [self disableScrollForView:subview level:level];
        }
    }
}

#pragma mark - Display List delegate
-(void) displayList:(iSmartNewsDisplayList*) displayList performAction:(iSmartNewsDisplayAction) action item:(NSObject*) item
{
    NSLog(@"performAction %d item %@", (int)action, item);
}

-(void) displayListWasEnded:(iSmartNewsDisplayList *)displayList
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        iSmartNewsLog(@"displayListWasEnded : new cycle");
        [self startLoadNewMessages];
    });
}

-(void)displayListWasAssignedNewMessages:(iSmartNewsDisplayList *)displayList
{
    iSmartNewsLog(@"displayListWasAssignedNewMessages");
    [self invalidateReloadTimer];
}

//Shown logic
-(iSmartNewsSaveLastShowResult) displayList:(iSmartNewsDisplayList*) displayList markItemIsShown:(NSDictionary*) item info:(NSDictionary*) info
{
    NSLog(@"MarkShown item %@  infi %@", item, info);
    return iSmartNewsLastShowItemNotFound;
}

//Extended environment info
-(BOOL)     displayListCanShowAlertView:(iSmartNewsDisplayList*)  displayList
{
    return YES;
}

-(UInt64)   displayListGetCounterValue:(iSmartNewsDisplayList*)   displayList
{
    return 0;
}

@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
