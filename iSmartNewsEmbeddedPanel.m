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

const NSTimeInterval minAutoHideInterval       = 1.0f;
const NSTimeInterval defaultAutoReloadInterval = 10.0f;

typedef enum : NSInteger
{
    isnEmbededPanelInitial   = 0,
    isnEmbededPanelInLoading = 1,
    isnEmbededPanelWasLoaded = 2,
    isnEmbededPanelEmpty     = 3,
    
} iSmartNewsEmbeddedPanelState;

@interface iSmartNewsEmbeddedPanel()<iSmartNewsDisplayListDelegate, iSmartNewsVisualizerStateNotificationReceiver>
@end

@implementation iSmartNewsEmbeddedPanel
{
    BOOL _isReady;
    BOOL _isActive;
    
    iSmartNewsEmbeddedPanelState _state;
    iSmartNewsDisplayList* _displayList;
    
    NSTimer* _rotationTimer;
    NSTimer* _reloadTimer;
    
    UIView* _contentView;
    
    NSMutableArray* _currentRotationEvents;
    NSUInteger      _listedItemsCountForCurrentCycle; //Used for reload: if current cycle are empty - stop, else try loading again
}

@synthesize delegate;

@synthesize isReady = _isReady;
@synthesize isActive = _isActive;

-(void)_initInternal
{
    _state = isnEmbededPanelInitial;
    
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
    [_displayList hideForceAndClear];
}

#pragma mark - properties
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

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (_isActive && _isReady)
    {
        CGRect contentViewFrame = [_contentView frame];
        
        if (CGSizeEqualToSize(frame.size, contentViewFrame.size) == NO)
        {
            contentViewFrame.size   = frame.size;
            contentViewFrame.origin = CGPointZero;
            
            [_contentView setFrame:contentViewFrame];
            [_contentView setNeedsLayout];
        }
    }
}

#pragma mark - Control
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

#pragma mark - Internal Logic
- (void) newItemsAvailable
{
    iSmartNewsLog(@"embeddedPanel : newItemsAvailable");
    
    if (([_displayList currentNewsMessage] == nil) && ([_displayList remainNewsMessagesCount] == 0))
    {
        iSmartNewsLog(@"embeddedPanel : newItemsAvailable : force reset current cycle");
        [self invalidateReloadTimer];
        [_currentRotationEvents removeAllObjects];
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
    
    iSmartNewsLog(@"embeddedPanel : startRotationIfNeed");
    
    //Not switch to next message - only dispatch timer
    if ([_displayList remainNewsMessagesCount] > 0)
    {
        if ([_displayList currentNewsMessage] == nil)
        {
            iSmartNewsLog(@"embeddedPanel : startRotationIfNeed : show first message");
            [_displayList showNextMessage];
        }
    }
    else if ([_displayList currentNewsMessage] == nil)
    {
        iSmartNewsLog(@"embeddedPanel : startRotationIfNeed : displayList is empty - load new messages");
        [self startLoadNewMessages];
    }
    else
    {
        iSmartNewsLog(@"embeddedPanel : startRotationIfNeed : news item is shown");
    }
}

-(BOOL) isCurrentCycleNewsListAreEmpty
{
    return (_state != isnEmbededPanelWasLoaded) && ([_displayList remainNewsMessagesCount] == 0) && ([_displayList currentNewsMessage] == nil) && ([_currentRotationEvents count] > 0);
}

-(BOOL) isCurrentCycleNewsHasEvents
{
    return ([_currentRotationEvents count] > 0);
}

-(void) startLoadNewMessages
{
    iSmartNewsLog(@"embeddedPanel : startLoadNewMessages");
    
    BOOL canLoad = YES;
    
    canLoad = canLoad && ([self reloadTimerIsActive] == NO);
    canLoad = canLoad && (_state != isnEmbededPanelInLoading);
    
    if (canLoad)
    {
        //New cycle
        if ([_currentRotationEvents count] == 0)
        {
            iSmartNewsLog(@"embeddedPanel : startLoadNewMessages : make new cycle");
            _currentRotationEvents = [_rotationEvents mutableCopy];
            _listedItemsCountForCurrentCycle = 0;
        }
        
        //Swith event with every load
        if ([_currentRotationEvents count] > 0)
        {
            _currentEvent = [_currentRotationEvents firstObject];
            [_currentRotationEvents removeObjectAtIndex:0];
            
            iSmartNewsLog(@"embeddedPanel : startLoadNewMessages : next message in cycle = \"%@\"", _currentEvent);
        }
        else
        {
             iSmartNewsLog(@"embeddedPanel : startLoadNewMessages : cycle was empty ...");
            _currentEvent = nil;
        }
        
        iSmartNewsLog(@"embeddedPanel : startLoadNewMessages : start reload timer as watchdog");
        //For reload if need
        [self redispatchReloadTimer];
        
        _state = isnEmbededPanelInLoading;
        //Really loading new news by current event
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startLoadNewMessages) object:nil];
        [self performSelector:@selector(_startLoadNewMessages) withObject:nil afterDelay:0.0f];
    }
    else
    {
        iSmartNewsLog(@"embeddedPanel : startLoadNewMessages : skipped by active reload timer");
    }
}

-(void) _startLoadNewMessages
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];
    
    iSmartNewsLog(@"embeddedPanel : _startLoadNewMessages");
    [[self internalDelegate] panelDidCompleteShown:self];
}

#pragma mark - Timers
#pragma mark - Rotation
-(void) rotationTimerEvent
{
    iSmartNewsLog(@"embeddedPanel : rotationTimerEvent");
    
    [self invalidateRotationTimer];
    
    [_displayList resetEndedFlag];
    
    if ([_displayList remainNewsMessagesCount] > 0)
    {
        //[_displayList forceHide];
        [_displayList showNextMessage];
    }
    else
    {
        [self startLoadNewMessages];
    }
}

-(void) invalidateRotationTimer
{
    iSmartNewsLog(@"embeddedPanel : invalidateRotationTimer");
    [_rotationTimer invalidate];
    _rotationTimer = nil;
}

-(void) dispatchRotationEventWithPeriod:(NSTimeInterval) period
{
    iSmartNewsLog(@"embeddedPanel : dispatchRotationEventWithPeriod: %2.2f", (float)period);
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
    iSmartNewsLog(@"embeddedPanel : dispatchRotationTimerAccordingShowingMessage");

    NSDictionary* currentMessage = [_displayList currentNewsMessage];

    NSTimeInterval rotationPeriod = 0.0f;
    NSNumber* autoHideIntervalNumber = [currentMessage valueForKey:@"autoHideInterval"];

    if (autoHideIntervalNumber != nil)
    {
        rotationPeriod = [autoHideIntervalNumber doubleValue];
        rotationPeriod = MAX(rotationPeriod, minAutoHideInterval);
        
        [self dispatchRotationEventWithPeriod:rotationPeriod];
    }
}

#pragma mark - Reload
-(void) redispatchReloadTimer
{
    iSmartNewsLog(@"embeddedPanel : redispatchReloadTimer");
    [self invalidateReloadTimer];
    _reloadTimer = [NSTimer scheduledTimerWithTimeInterval:defaultAutoReloadInterval target:self selector:@selector(reloadTimerHandler) userInfo:nil repeats:NO];
}

-(void) invalidateReloadTimer
{
    iSmartNewsLog(@"embeddedPanel : invalidateReloadTimer");
    
    [_reloadTimer invalidate];
    _reloadTimer = nil;
}

-(BOOL) reloadTimerIsActive
{
    return [_reloadTimer isValid];
}

-(void) reloadTimerHandler
{
    iSmartNewsLog(@"embeddedPanel : reloadTimerHandler");
    
    [_reloadTimer invalidate];
    _reloadTimer = nil;
    
    [self startRotationIfNeed];
}

#pragma mark - Integration

-(void)visualizerFinishedShowingMessage:(iSmartNewsVisualizer *)visualizer
{
    iSmartNewsLog(@"embeddedPanel : visualizerFinishedShowingMessage : %@", [visualizer metaUUID]);
    [self invalidateRotationTimer];
}

-(void)visualizerWillShowMessage:(iSmartNewsVisualizer *)visualizer
{
    iSmartNewsLog(@"embeddedPanel : visualizerWillShowMessage : %@", [visualizer metaUUID]);
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
        
        [content setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
        
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
    NSLog(@"embeddedPanel : performAction %d item %@", (int)action, item);
}

#pragma mark Loading logic

-(void)displayListWasAssignedNewMessages:(iSmartNewsDisplayList *)displayList
{
    if ([displayList isEqual:_displayList] == NO)
        return;
    
    iSmartNewsLog(@"embeddedPanel : displayListWasAssignedNewMessages");
    [self invalidateReloadTimer];

    _state = isnEmbededPanelWasLoaded;
    _listedItemsCountForCurrentCycle = _listedItemsCountForCurrentCycle + [_displayList remainNewsMessagesCount];
    if ([_displayList currentNewsMessage] != nil)
    {
        _listedItemsCountForCurrentCycle = _listedItemsCountForCurrentCycle + 1;
    }
    
    assert(_listedItemsCountForCurrentCycle > 0);
    
    iSmartNewsLog(@"embeddedPanel : displayListWasAssignedNewMessages : show next message");
    [_displayList setAllowMultipleAsyncVisualizers];
    [_displayList showNextMessage];
}

-(void)displayListNotNewMessagesForAssignment:(iSmartNewsDisplayList*)displayList
{
    if ([displayList isEqual:_displayList] == NO)
        return;
    
    iSmartNewsLog(@"embeddedPanel : displayListNotNewMessagesForAssignment");
    [self invalidateReloadTimer];
    
    _state = isnEmbededPanelEmpty;
    
    if ([self isCurrentCycleNewsHasEvents])
    {
        iSmartNewsLog(@"embeddedPanel : displayListNotNewMessagesForAssignment : try load for next event");
        [self startLoadNewMessages];
    }
    else if (_listedItemsCountForCurrentCycle > 0)
    {
        iSmartNewsLog(@"embeddedPanel : displayListNotNewMessagesForAssignment : start new cycle - because previous was successful");
        [self startLoadNewMessages];
    }
    else
    {
        
        iSmartNewsLog(@"embeddedPanel : displayListNotNewMessagesForAssignment : stop cycle and redispatch reload timer");
        [self redispatchReloadTimer];
    }
}

-(void)displayListFailedToShowMessage:(iSmartNewsDisplayList *)displayList
{
    iSmartNewsLog(@"embeddedPanel : displayListFailedToShowMessage");
}

-(void)displayListFailedToShowNextMessage:(iSmartNewsDisplayList *)displayList
{
    iSmartNewsLog(@"embeddedPanel : displayListFailedToShowNextMessage");
}

-(void) displayListWasEnded:(iSmartNewsDisplayList *)displayList
{
    iSmartNewsLog(@"embeddedPanel : displayListWasEnded : dispatch new load");
        
    if ([_displayList remainNewsMessagesCount] == 0)
    {
        iSmartNewsLog(@"embeddedPanel : displayListWasEnded : continue or make new cycle");
        [self startLoadNewMessages];
    }
    else
    {
         iSmartNewsLog(@"embeddedPanel : displayListWasEnded : skip reload");
    }
}

-(BOOL)displayListShouldToReloadCurrentMessage:(iSmartNewsDisplayList *)displayList
{
    iSmartNewsLog(@"embeddedPanel : displayListShouldToReloadCurrentMessage : %@", [[displayList visualizer] metaUUID]);
    [self invalidateReloadTimer];
    [self dispatchRotationTimerAccordingShowingMessage];
    
    return NO;
}

#pragma mark Shown logic
-(iSmartNewsSaveLastShowResult) displayList:(iSmartNewsDisplayList*) displayList markItemIsShown:(NSDictionary*) item info:(NSDictionary*) info
{
    iSmartNewsLog(@"embeddedPanel : markShown item %@ info %@", item, info);
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
