//
//  iSmartNewsDisplayQueue.m
//  SmartNewsEmbeded
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif


#import "iSmartNewsDisplayList.h"
#import "iSmartNewsVisualizer.h"

NSString* const envQueuesTimeoutsKey = @"queuesTimeouts";
NSString* const envGateKey           = @"gate";

@interface iSmartNewsDisplayList ()<iSmartNewsVisualizerDelegate, iSmartNewsVisualizerStateNotificationReceiver>

@end

@implementation iSmartNewsDisplayList
{
    iSmartNewsVisualizer* _visualizer;
    NSDictionary*         _currentNewsMessage;
    
    iSmartNewsVisualizer* _nextVisualizer;
    NSDictionary*         _nextNewsMessage;
    
    /*! @internal */
    NSMutableArray*       _loadedNews;
    
    NSMutableDictionary* _queuesTimeouts;
    NSString* currentQueue_;
    
    NSTimer* queueTimer_;
    NSTimer* retryTimer_;
    
    BOOL isFirst_;
    
    /*! @internal */
    /*! @since Version 1.3 */
    NSUInteger              gate_;
    
    BOOL _listWasEnded;
    BOOL _allowMultipleAsyncVisualizers;
    
    NSString*  _lastFailedUUID;
    NSUInteger _lastFailedCount;
}

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        _loadedNews     = [NSMutableArray new];
        _queuesTimeouts = [NSMutableDictionary new];
        gate_ = UINT_MAX;
    }
    return self;
}

- (void)assignNews:(NSArray*) news enveronment:(NSDictionary*) enveronment
{
    if (_allowMultipleAsyncVisualizers)
    {
        assert(_nextVisualizer == nil);
    }
    else
    {
        assert((_visualizer == nil) && (_nextVisualizer == nil));
        [self resetVisualizerTimers];
    }
    
    gate_         = UINT_MAX;
    currentQueue_ = nil;

    //Update queuesTimeouts
    NSDictionary* queueTimeouts = [enveronment objectForKey:envQueuesTimeoutsKey];
    if ([queueTimeouts count] > 0)
    {
        [_queuesTimeouts addEntriesFromDictionary:queueTimeouts];
    }
    
    //Assign gate
    NSNumber* gate = [enveronment objectForKey:envGateKey];
    if (gate != nil)
    {
        gate_ = [gate unsignedIntegerValue];
    }
    
    if ([news count] > 0)
    {
        iSmartNewsLog(@"iSmartNewsDisplayList : assignNews: notify about WasAssignedNewMessages");
        
        isFirst_      = ([_loadedNews count] == 0);
        _listWasEnded = NO;
        
        @synchronized (self)
        {
            [_loadedNews addObjectsFromArray:news];
        }
        
        NSObject<iSmartNewsDisplayListDelegate>* delegate = [self delegate];
        if ([delegate respondsToSelector:@selector(displayListWasAssignedNewMessages:)])
        {
            [delegate displayListWasAssignedNewMessages:self];
        }
    }
    else
    {
        iSmartNewsLog(@"iSmartNewsDisplayList : assignNews: notify about NotNewMessagesForAssignmen");
        
        if (_allowMultipleAsyncVisualizers == NO)
        {
            isFirst_      = ([_loadedNews count] == 0);;
            _listWasEnded = ([_loadedNews count] == 0);;
        }
        
        NSObject<iSmartNewsDisplayListDelegate>* delegate = [self delegate];
        if ([delegate respondsToSelector:@selector(displayListNotNewMessagesForAssignment:)])
        {
            [delegate displayListNotNewMessagesForAssignment:self];
        }
    }
}

-(iSmartNewsVisualizer *)visualizer
{
    return _visualizer;
}

-(NSUInteger)remainNewsMessagesCount
{
    return [_loadedNews count];
}

-(NSDictionary *)currentNewsMessage
{
    return _currentNewsMessage;
}

#pragma mark -

- (void)raiseEventListWasEnded
{
    if (_listWasEnded)
        return;
 
    iSmartNewsLog(@"iSmartNewsDisplayList : listWasEnded");
    _listWasEnded = YES;
    
    NSObject<iSmartNewsDisplayListDelegate>* delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(displayListWasEnded:)])
    {
        [delegate displayListWasEnded:self];
    }
}

-(void)resetEndedFlag
{
    iSmartNewsLog(@"iSmartNewsDisplayList : resetEndedFlag");
    _listWasEnded = NO;
}

- (void) resetVisualizerTimers
{
    iSmartNewsLog(@"diplayList : resetVisualizerHelpers");
    
    [retryTimer_ invalidate];
    retryTimer_ = nil;
    
    [queueTimer_ invalidate];
    queueTimer_ = nil;
    
    currentQueue_ = nil;
}

- (void)hideForceAndClear
{
    iSmartNewsLog(@"iSmartNewsDisplayList : hideForceAndClear");
    
    //Force hide current
    iSmartNewsVisualizer* currentVisualizer = _visualizer;
    iSmartNewsVisualizer* nextVisualizer    = _nextVisualizer;
    
    if (currentVisualizer != nil)
    {
        [self resetVisualizerVar:_visualizer keepCurrentMessage:NO];
        [currentVisualizer forceHide]; //After reset var
        [self resetVisualizerTimers];
    }
    
    if (nextVisualizer != nil)
    {
        [self resetVisualizerVar:nextVisualizer keepCurrentMessage:NO];
        [nextVisualizer forceHide];
        [self resetVisualizerTimers];
    }
    
    //Clear news and send "WasEnded"
    @synchronized (self)
    {
        [_queuesTimeouts   removeAllObjects];
        [_loadedNews       removeAllObjects];
    }

    [self raiseEventListWasEnded];
}

- (void)setAllowMultipleAsyncVisualizers
{
    _allowMultipleAsyncVisualizers = YES;
}

- (void)resetVisualizerVar:(iSmartNewsVisualizer*) visualizer keepCurrentMessage:(BOOL) keepCurrentMessage
{
    iSmartNewsLog(@"iSmartNewsDisplayList : resetVisualizerVar %p", _visualizer);
    
    if ((visualizer != _visualizer) && (visualizer != _nextVisualizer))
    {
        iSmartNewsLog(@"iSmartNewsDisplayList : resetVisualizerVar unknown");
        return;
    }
    
    visualizer.delegate = nil;
    
    // WE delay destruction of visualizer to prevent will/hide notification to be sent for each news item.
    // If delay is used then notifications will be sent only once per block.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [visualizer description];//some fake call
    });
    
    if (visualizer == _visualizer)
    {
        _visualizer = nil;
        
        if (keepCurrentMessage == NO)
        {
            _currentNewsMessage = nil;
        }
    }
    else if (visualizer == _nextVisualizer)
    {
        _nextVisualizer  = nil;
        _nextNewsMessage = nil;
    }
}

- (void)switchToNextVisualizer
{
    iSmartNewsLog(@"diplayList : switchToNextVisualizer %p <= %p", _visualizer, _nextVisualizer);
    
    if (_nextVisualizer != nil)
    {
        assert((_visualizer == nil) || _allowMultipleAsyncVisualizers);
        assert(_nextVisualizer != _visualizer);
        
        iSmartNewsVisualizer* currentVisualizer = _visualizer;
        if (currentVisualizer != nil)
        {
            [self visualizerDidClickNothingForSwitchToNextOnly:currentVisualizer]; //Emulate close - for remove news from loadedNews_
            [currentVisualizer forceHide]; //After reset var
        }
        
        _visualizer         = _nextVisualizer;
        _nextVisualizer     = nil;
        
        _currentNewsMessage = _nextNewsMessage;
        _nextNewsMessage    = nil;
    }
}

-(NSDictionary*) extractNextMessage
{
    NSDictionary* nextMessage = nil;
    
    iSmartNewsLog(@"diplayList : extractNextMessage");
    
    @synchronized (self)
    {
        if ([_loadedNews count] > 0)
        {
            nextMessage = [_loadedNews firstObject];
            [_loadedNews removeObjectAtIndex:0];
        }
    }
    
    return nextMessage;
}

- (void)showNextMessage
{
    iSmartNewsLog(@"diplayList : showNextMessage");
    
    if (_visualizer && (_allowMultipleAsyncVisualizers == NO))
    {
        iSmartNewsLog(@"diplayList : showNextMessage : showing - return");
        return;
    }
    
    iSmartNewsLog(@"diplayList : showNextMessage : reset timers");
    [self resetVisualizerTimers];
    
    if ((_allowMultipleAsyncVisualizers == NO) && [[self delegate] displayListCanShowAlertView:self] != YES)
    {
        retryTimer_ = [NSTimer scheduledTimerWithTimeInterval:1
                                                       target:self
                                                     selector:@selector(showNextMessage)
                                                     userInfo:nil repeats:NO];
        
        iSmartNewsLog(@"diplayList : showNextMessage : can't show - retry 1");
        return;
    }
    
    if (_allowMultipleAsyncVisualizers)
    {
        if (_nextVisualizer != nil)
        {
            iSmartNewsLog(@"diplayList : showNextMessage : remove not ready next");
            
            _nextNewsMessage = nil;
            
            _nextVisualizer.delegate                  = nil;
            _nextVisualizer.stateNotificationReceiver = nil;
            _nextVisualizer.shownBlock = nil;
            [_nextVisualizer forceHide];
            _nextVisualizer  = nil;
        }
    }
    
    // counter logic, new since version 1.2
    const UInt64 counter = [[self delegate] displayListGetCounterValue:self];
    
    NSDate* currentDate = [NSDate ism_date];
    while ([self remainNewsMessagesCount] > 0)
    {
        NSDictionary* description = [self extractNextMessage];
        
        if ([_lastFailedUUID isEqualToString:[description objectForKey:@"uuid"]] != YES)
        {
            _lastFailedUUID = nil;
            _lastFailedCount = 0;
        }
        
        iSmartNewsLog(@"checking message: %@",description);
        
        //continue - will remove current message from loadedNews_
        
        NSDate* from = [description objectForKey:iSmartNewsMessageStartDateKey];
        if (from && [currentDate timeIntervalSinceDate:from] < 0){
            iSmartNewsLog(@"start data not crossed, message will not be shown");
            continue;
        }
        
        NSDate* to = [description objectForKey:iSmartNewsMessageEndDateKey];
        if (to && [currentDate timeIntervalSinceDate:to] >= 0){
            iSmartNewsLog(@"end date crossed, message will not be shown");
            continue;
        }
        
        if (counter)
        {
            NSNumber* limitCounter = [description objectForKey:iSmartNewsMessageCounterKey];
            if (limitCounter && ([limitCounter unsignedLongLongValue] > 0) && (counter < [limitCounter unsignedLongLongValue]))
            {
                iSmartNewsLog(@"counter limit not crossed, message will not be shown");
                continue;
            }
        }
        
        NSMutableDictionary* alertViewDescription = [NSMutableDictionary new];
        
        for (NSString* key in @[iSmartNewsMessageTitleKey, iSmartNewsMessageTextKey, iSmartNewsMessageCancelKey, iSmartNewsMessageActionKey, iSmartNewsMessageReviewKey, iSmartNewsMessageUrlKey, iSmartNewsMessageRemindKey, iSmartNewsMessageReviewTypeKey, iSmartNewsMessageStyleKey])
        {
            NSString* value = [description objectForKey:key];
            if (value != nil)
            {
                [alertViewDescription setObject:value forKey:key];
            }
        }
        
        NSString* message   = [description objectForKey:iSmartNewsMessageTextKey];
        NSString* queue     = [description objectForKey:iSmartNewsMessageQueueKey];
        
        
        //Queue is legacy and supported only for FullScreen StepByStep Display Lists
        assert(queue == nil || (queue != nil && (_allowMultipleAsyncVisualizers == NO)));
        if (queue && (_allowMultipleAsyncVisualizers == NO))
        {
            //Make current queue
            if (!currentQueue_ || ![queue isEqualToString:currentQueue_])
            {
                currentQueue_ = [queue copy];
                
                NSUInteger nQueued = 0;
                
                //Found all news with same queue
                for (NSDictionary* m in _loadedNews)
                {
                    NSString* queue = [m objectForKey:iSmartNewsMessageQueueKey];
                    if ([queue isEqualToString:currentQueue_])
                        nQueued++;
                }
                
                //Make dict
                iSmartNewsQueuesInfo* queueInfo = [iSmartNewsQueuesInfo queuesInfoForService:[self service]];
                
                NSMutableDictionary* q_indexes = [[queueInfo data] objectForKey:@"indexes"];
                if (!q_indexes || ![q_indexes isKindOfClass:[NSMutableDictionary class]])
                {
                    q_indexes = [NSMutableDictionary new];
                    [[queueInfo data] setObject:q_indexes forKey:@"indexes"];
                }
                
                NSNumber* n = [q_indexes objectForKey:queue];
                if (n == nil)
                {
                    n = @(0);
                    [q_indexes setObject:n forKey:queue];
                }
                
                if ([n unsignedIntValue] >= nQueued)
                {
                    n = @(0);
                    [q_indexes setObject:n forKey:queue];
                }
                
                [_loadedNews removeObjectsInRange:NSMakeRange(0, [n unsignedIntValue])];
                [_loadedNews removeObjectsInRange:NSMakeRange(1, nQueued - [n unsignedIntValue] - 1)];
                
                n = @([n unsignedIntValue] + 1);
                [q_indexes setObject:n forKey:queue];
                
                [queueInfo saveQueuesInfo];
                
                iSmartNewsLog(@"NEXT INDEX %@",n);
                
                NSNumber* timeout = [_queuesTimeouts objectForKey:queue];
                if (timeout != nil)
                {
                    uint32_t t = [timeout unsignedIntValue];
                    const uint32_t base = t & 0xFFFF;
                    const uint32_t range = (t >> 16) & 0xFFFF;
                    NSTimeInterval generatedTimeout = (NSTimeInterval)base;
                    if (range != 0){
                        generatedTimeout += (NSTimeInterval)arc4random_uniform(range);
                    }
                    queueTimer_ = [NSTimer scheduledTimerWithTimeInterval:(isFirst_
                                                                           && ![description objectForKey:@"uuid"]
                                                                           && [description objectForKey:iSmartNewsMessageTypeKey]
                                                                           && [[description objectForKey:iSmartNewsMessageTypeKey] isEqualToString:iSmartNewsContentTypeWeb] ? 0.001 : generatedTimeout)
                                                                   target:self
                                                                 selector:@selector(showNextMessage)
                                                                 userInfo:nil repeats:NO];
                    return;
                }
            }
        }
        
        if ((_allowMultipleAsyncVisualizers == NO) && [[self delegate] displayListCanShowAlertView:self] != YES)
        {
            retryTimer_ = [NSTimer scheduledTimerWithTimeInterval:1
                                                           target:self
                                                         selector:@selector(showNextMessage)
                                                         userInfo:nil repeats:NO];
            
            iSmartNewsLog(@"diplayList : showNextMessage : can't show - retry 2");
            
#warning FixMe!
            //Fast fix - return current message in-to _loadedNews
            @synchronized (self)
            {
                [_loadedNews insertObject:description atIndex:0];
            }
            return;
        }
        else
        {
            [retryTimer_ invalidate];
            retryTimer_ = nil;
        }
        
        NSString * messageType = [description objectForKey:iSmartNewsMessageTypeKey];
        
        const BOOL showRemoveAdsButton = [description objectForKey:@"removeAdsAction"] != nil;
        NSString* uuid = [description objectForKey:@"uuid"];
        
        iSmartNewsVisualizerShownBlock shownBlock;
        
        if ([uuid length] > 0)
        {
            SmartNewsItem* metaItem = sn_findMetaItem(self.service, uuid);
            if (metaItem)
            {
                [metaItem gotoNextUrl];
            
                saveContext(self.service);
                
                NSDate* shownDate = [NSDate ism_date];
                NSString* serviceName = self.service;
                
                //***shownBlock*** begin
                shownBlock = ^{
                    NSString* rangeUuid = [description objectForKey:@"rangeUuid"];
                    
                    if ([rangeUuid length] > 0)
                    {
                        NSManagedObject* metaRangeItem = sn_findMetaRangeItem(serviceName, metaItem,rangeUuid);
                        if (metaRangeItem)
                        {
                            NSUInteger nextShown = [[metaRangeItem valueForKey:@"shown"] unsignedIntegerValue] + 1;
                            [metaRangeItem setValue:@(nextShown) forKey:@"shown"];
                            
                            NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
                            [formatter setDateStyle:NSDateFormatterFullStyle];
                            [formatter setTimeStyle:NSDateFormatterFullStyle];
                            [metaRangeItem setValue:[formatter stringFromDate:shownDate] forKey:@"probability"];
                            
                            saveContext(self.service);
                        }
                    }
                };
                //***shownBlock*** end
            }
        }
        
        if (_allowMultipleAsyncVisualizers && (_currentNewsMessage != nil) && (_visualizer != nil) && [_visualizer isPresented])
        {
            if ([_currentNewsMessage isEqual:description])
            {
                iSmartNewsLog(@"diplayList : showNextMessage : try to shown current message");
                
                if ([[self delegate] respondsToSelector:@selector(displayListShouldToReloadCurrentMessage:)])
                {
                    BOOL shouldToReload = [[self delegate] displayListShouldToReloadCurrentMessage:self];
                    
                    if (shouldToReload != YES)
                    {
                        iSmartNewsLog(@"diplayList : showNextMessage : reshown current message was skipped");
                        return;
                    }
                }
            }
        }
        
        if ([messageType isEqualToString:iSmartNewsContentTypeWeb])
        {
            iSmartNewsVisualizerAppearance appearance = _visualizerAppearance;
            
            _nextVisualizer = [[iSmartNewsVisualizer alloc] initWebViewVisualizerWithURL:[NSURL URLWithString:message] appearance:appearance showRemoveAdsButton:showRemoveAdsButton];
            _nextVisualizer.embeddedPanel = _visualizerEmbeddedPanel;
        }
        else if ([messageType isEqualToString:iSmartNewsContentTypeDirectAction])
        {
            _nextVisualizer = [[iSmartNewsVisualizer alloc] initDirectActionVisualizerWithURL:[NSURL URLWithString:message]];
        }
        else
        {
            assert(_visualizerAppearance == isnVisualizerAppearancePopup);

            _nextVisualizer = [[iSmartNewsVisualizer alloc] initAlertViewVisualizerWithDescription:alertViewDescription];
        }
        
        if (!_nextVisualizer)
        {
            continue; //Remove current message from loadedNews_
        }
        
        isFirst_ = NO;
        
        NSDictionary* style = [description objectForKey:iSmartNewsMessageStyleKey];
        
        if ([style isKindOfClass:[NSString class]])
        {
            style = [NSDictionary dictionaryFromFlatLine:(NSString*)style optionAliases:@"anim:animation_bg:backround_ind:indicator"];
        }
        
        if ([style count] > 0)
        {
            _nextVisualizer.appearanceStyle = style;
        }
        
        iSmartNewsLog(@"diplayList : showNextMessage : visualizer %p was maked", _nextVisualizer);
        
        if (self.visualizerStateNotificationReceiver != nil)
        {
            _nextVisualizer.stateNotificationReceiver = self;
        }
        
        _nextNewsMessage  = description;
        _nextVisualizer.shownBlock = shownBlock;
        
        _nextVisualizer.allowAllIphoneOrientations = [[description objectForKey:@"allowAllIphoneOrientations"] isKindOfClass:[NSNumber class]] && [[description objectForKey:@"allowAllIphoneOrientations"] boolValue];
        
        __block UIInterfaceOrientationMask mask = 0;
        [[[[description objectForKey:@"orientations"] lowercaseString] componentsSeparatedByString:@"|"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isEqualToString:@"up"]){
                mask |= UIInterfaceOrientationMaskPortrait;
            }
            else if ([obj isEqualToString:@"down"]){
                mask |= UIInterfaceOrientationMaskPortraitUpsideDown;
            }
            else if ([obj isEqualToString:@"left"]){
                mask |= UIInterfaceOrientationMaskLandscapeLeft;
            }
            else if ([obj isEqualToString:@"right"]){
                mask |= UIInterfaceOrientationMaskLandscapeRight;
            }
            else if ([obj isEqualToString:@"portrait"]){
                mask |= UIInterfaceOrientationMaskPortrait|UIInterfaceOrientationMaskPortraitUpsideDown;
            }
            else if ([obj isEqualToString:@"landscape"]){
                mask |= UIInterfaceOrientationMaskLandscape;
            }
            else if ([obj isEqualToString:@"all"]){
                mask |= UIInterfaceOrientationMaskAll;
            }
        }];
        
        if (mask != 0)
        {
            _nextVisualizer.orientationMask = mask;
        }
        
        NSRange showDelayRange = NSMakeRange(0, 0);
        
        if ([description objectForKey:@"minDelay"] && [description objectForKey:@"maxDelay"])
        {
            showDelayRange = NSMakeRange( [[description objectForKey:@"minDelay"] unsignedIntegerValue],
                                          [[description objectForKey:@"maxDelay"] unsignedIntegerValue] - [[description objectForKey:@"minDelay"] unsignedIntegerValue]);
        }
        
        _nextVisualizer.metaUUID = uuid;
        _nextVisualizer.onShow = [description objectForKey:@"onShow"];
        _nextVisualizer.delegate = self;
        
        iSmartNewsVisualizer* makedVisualizer = _nextVisualizer;
        
        if ((_currentNewsMessage == nil) && (_visualizer == nil))
        {
            iSmartNewsLog(@"diplayList : showNextMessage : switchToNext %p immediately", _nextVisualizer);
            [self switchToNextVisualizer];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([_visualizer isEqual:makedVisualizer] || [_nextVisualizer isEqual:makedVisualizer])
            {
                [makedVisualizer showWithDelayRange:showDelayRange];
            }
        });
        
        return;
    }
    

    if ((_currentNewsMessage == nil) && (_nextNewsMessage == nil) && ([self remainNewsMessagesCount] == 0))
    {
        [self raiseEventListWasEnded];
    }
}

#pragma mark - Actions

- (void)nothingWasPressed
{
    if (_currentNewsMessage == nil)
        return;
    
    _currentNewsMessage = nil;
    
    //--
    // new since version 1.3
    if (--gate_ == 0)
    {
        [self hideForceAndClear];
        return;
    }
    //--
    
    [self showNextMessage];
}

- (void)nothingWasPressedForSwitchOnly
{
    if (_currentNewsMessage == nil)
        return;
    
    _currentNewsMessage = nil;
    
    //--
    // new since version 1.3
    if (--gate_ == 0)
    {
        [self hideForceAndClear];
        return;
    }
    //--
    
    //Skip show next
    //[self showNextMessage];
}

- (void)cancelWasPressed
{
    if (_currentNewsMessage == nil)
        return;
    
    NSDictionary* message = _currentNewsMessage;
    
    iSmartNewsLog(@"CANCEL button clicked");
    
    if (![[message objectForKey:iSmartNewsMessageAlwaysKey] boolValue]
        && ![[message objectForKey:iSmartNewsMessageRepeatKey] boolValue])
    {
        //[self setCacheValue:message];
        [[self delegate] displayList:self markItemIsShown:message info:@{@"isMessage" : @(YES)}];
    }
    
    _currentNewsMessage = nil;
    
    //--
    // new since version 1.3
    if (--gate_ == 0)
    {
        [self hideForceAndClear];
        return;
    }
    //--
    
    [self showNextMessage];
}

- (void)actionWasPressed
{
    if (_currentNewsMessage == nil)
        return;
    
    NSDictionary* message = _currentNewsMessage;
    
    iSmartNewsLog(@"OK button clicked");
    
    if (![[message objectForKey:iSmartNewsMessageAlwaysKey] boolValue])
    {
        //[self setCacheValue:message];
        [[self delegate] displayList:self markItemIsShown:message info:@{@"isMessage" : @(YES)}];
    }
    
    NSString* urlString = [message objectForKey:iSmartNewsMessageUrlKey];
    if (urlString)
    {
        NSURL* url = [NSURL URLWithString:urlString];
        
        if (url)
        {
            NSString* callBackType = [self isCallBackURL:url];
            if ([callBackType length] > 0)
            {
                NSString* uuid = [message objectForKey:@"uuid"];
                NSDictionary* userInfo = [self makeUserInfoForCallBackURL:url callType:nil uuid:uuid];
                
                [self _sendCallBackWithUserInfo:userInfo];
            }
            else
            {
                iSmartNewsLog(@"Opening URL: %@",urlString);
                
                if ([[UIApplication sharedApplication] canOpenURL:url])
                {
                    [[UIApplication sharedApplication] openURL:url];
                }
            }
        }
    }
    
    _currentNewsMessage = nil;
    
    //--
    // new since version 1.3
    if (--gate_ == 0)
    {
        [self hideForceAndClear];
        return;
    }
    //--
    
    [self showNextMessage];
}

#pragma mark - FixMe!
-(NSString*) isCallBackURL:(NSURL*) url
{
    NSString* callType = nil;
    
    NSString* scheme = [[url scheme] lowercaseString];
    NSString* host   = [[url host] lowercaseString];
    
    if ([scheme hasPrefix:@"callback"] || [host isEqualToString:@"callback.io"])
    {
        callType = @"callback";
    }
    else if ([scheme hasPrefix:@"callquietly"] || [host isEqualToString:@"callquietly.io"])
    {
        callType = @"callquietly";
    }
    
    return callType;
}

- (NSDictionary*) makeUserInfoForCallBackURL:(NSURL*) url callType:(NSString*) callType uuid:(NSString*) uuid
{
    NSString* requestURLString = nil;
    @try
    {
        requestURLString = [url absoluteString];
        
    }
    @catch(NSException* e)
    {
        requestURLString = nil;
    }
    
    NSDictionary* userInfo = @{
                               @"url"  :   (requestURLString?requestURLString:@"null"),
                               @"uuid" :   (uuid?uuid:@"null"),
                               @"type" :   (callType?callType:@"unknown"),
                               };
    return userInfo;
}

#pragma mark -
#pragma mark iSmartNewsVisualizerStateNotificationReceiver - proxy

- (void)visualizerWillShowMessage:(iSmartNewsVisualizer*)visualizer
{
    if ([visualizer isEqual:_nextVisualizer])
    {
        assert(_allowMultipleAsyncVisualizers);
        [self switchToNextVisualizer];
    }
    else
    {
        assert([visualizer isEqual:_visualizer] && (_nextVisualizer == nil));
    }
    
    if (self.visualizerStateNotificationReceiver)
    {
        [self.visualizerStateNotificationReceiver visualizerWillShowMessage:visualizer];
    }
}

- (void)visualizerFinishedShowingMessage:(iSmartNewsVisualizer*)visualizer
{
    if (self.visualizerStateNotificationReceiver)
    {
        [self.visualizerStateNotificationReceiver visualizerFinishedShowingMessage:visualizer];
    }
}

#pragma mark -
#pragma mark iSmartVisualizerDelegate

- (void)visualizerDidFail:(iSmartNewsVisualizer*)visualizer
{
    if ((_currentNewsMessage == nil) && (_nextNewsMessage == nil))
        return;
    
    if (visualizer == _nextVisualizer)
    {
        iSmartNewsLog(@"dispplayList : visualizerDidFail : next");
        _nextVisualizer = nil;
        
        if ([self.delegate respondsToSelector:@selector(displayListFailedToShowNextMessage:)])
        {
            [self.delegate displayListFailedToShowNextMessage:self];
        }
        
        _nextNewsMessage = nil;
        return;
    }
    else if (visualizer != _visualizer)
    {
        iSmartNewsLog(@"dispplayList : visualizerDidFail : unknown ...");
        return;
    }
    
    if ([_lastFailedUUID isEqualToString:visualizer.metaUUID])
    {
        _lastFailedCount++;
    }
    else
    {
        _lastFailedCount = 1;
        _lastFailedUUID = visualizer.metaUUID;
    }
    
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    iSmartNewsLog(@"dispplayList : visualizerDidFail");
    
    if ([self.delegate respondsToSelector:@selector(displayListFailedToShowMessage:)])
    {
        [self.delegate displayListFailedToShowMessage:self];
    }
    
    NSTimeInterval delay = 0.0f;
    if (_lastFailedCount > 3)
    {
        delay = 1.0f;
    }
    else if (_lastFailedCount > 6)
    {
        delay = 10.0f;
    }
    
    if (delay > 0.0f)
    {
        [self performSelector:@selector(nothingWasPressed) withObject:nil afterDelay:delay];
    }
    else
    {
        [self nothingWasPressed];
    }
}

- (void)visualizerDidClickNothing:(iSmartNewsVisualizer*)visualizer
{
    if (_currentNewsMessage == nil)
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"cancel"}];
    }
    
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    [self nothingWasPressed];
}

- (void)visualizerDidClickNothingForSwitchToNextOnly:(iSmartNewsVisualizer*)visualizer
{
    assert(_allowMultipleAsyncVisualizers);
    
    if (_currentNewsMessage == nil)
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"cancel"}];
    }
    
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    [self nothingWasPressedForSwitchOnly];
}

- (void)visualizerDidClickCancel:(iSmartNewsVisualizer*)visualizer
{
    if (_currentNewsMessage == nil)
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"cancel"}];
    }
    
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    [self cancelWasPressed];
}

- (void)visualizerDidClickOk:(iSmartNewsVisualizer*)visualizer
{
    if (_currentNewsMessage == nil)
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"ok"}];
    }
    
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    [self actionWasPressed];
}


- (void)visualizerDidClickLink:(iSmartNewsVisualizer*)visualizer
{
    if (_currentNewsMessage == nil)
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        iSmartNewsSaveLastShowResult result = [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"link"}];
        
        if (result == iSmartNewsLastShowConditionNotFound) //For backward compatibility
        {
            result = [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"cancel"}];
            iSmartNewsLog(@"visualizerDidClickLink -> try as cancel = %d", (int)result);
        }
    }
    
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    [self nothingWasPressed]; //Link == external handler on server
}

- (void)visualizerDidClickCallback:(iSmartNewsVisualizer*)visualizer userInfo:(NSDictionary*)userInfo
{
    if (_currentNewsMessage == nil)
        return;
    
    if (visualizer != _visualizer)
        return;
    
    NSString* callType = [userInfo objectForKey:@"type"];
    
    if ([callType isEqualToString:@"callback"])
    {
        if ([visualizer.metaUUID length] > 0)
        {
            [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"callback"}];
        }
        
        [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
        
        [self nothingWasPressed];
    }
    
    [self _sendCallBackWithUserInfo:userInfo];
}

- (void)_sendCallBackWithUserInfo:(NSDictionary*) userInfo
{
    //Remove "type" key from userInfo for implement SN-19 (send callback by "onShow")
    //Because for send onShow with domain "callback" we set fake type = "callquietly"
    if ([userInfo isKindOfClass:[NSDictionary class]])
    {
        NSMutableDictionary* mutableUserInfo = [userInfo mutableCopy];
        [mutableUserInfo removeObjectForKey:@"type"];
        
        userInfo = [mutableUserInfo copy];
    }
    
    NSDictionary* notificationUserInfo = nil;
    
    if (userInfo)
    {
        if ([userInfo isKindOfClass:[NSDictionary class]])
        {
            notificationUserInfo = userInfo;
        }
        else
        {
            notificationUserInfo = @{@"userInfo" : userInfo };
        }
    }
    
    BOOL shouldSendCallbackNotification = YES;
    
    if ([[self delegate] respondsToSelector:@selector(displayList:shouldSendCallbackNotificationWithUserInfo:)])
    {
        shouldSendCallbackNotification = [[self delegate] displayList:self shouldSendCallbackNotificationWithUserInfo:notificationUserInfo];
    }
    
    if (shouldSendCallbackNotification)
    {
        [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:iSmartNewsDidOpenCallbackNotification object:self userInfo:notificationUserInfo]
                                                   postingStyle:NSPostWhenIdle
                                                   coalesceMask:NSNotificationNoCoalescing
                                                       forModes:nil];
    }
    
    iSmartNewsLog(@"send callback with userInfo: %@", notificationUserInfo);
}

- (void)visualizerDidClickRemoveAds:(iSmartNewsVisualizer*)visualizer
{
    if (_currentNewsMessage == nil)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"removeads"}];
    }
    
#warning CheckMe!
    NSDictionary* description = _currentNewsMessage;
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    [self nothingWasPressed];
    
    NSString* removeAdsAction = [description objectForKey:@"removeAdsAction"];
    
    if ([[removeAdsAction lowercaseString] isEqualToString:@"app"])
    {
        [[self delegate] displayList:self performAction:iSmartNewsDisplayActionRemoveAdsApplication item:description];
    }
    else
    {
        [[self delegate] displayList:self performAction:iSmartNewsDisplayActionRemoveAdsBasic       item:description];
    }
}

- (void)visualizerDidClickOpenReview:(iSmartNewsVisualizer*)visualizer
{
    if (_currentNewsMessage == nil)
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"review"}];
    }
    
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    [self nothingWasPressed];
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:iSmartNewsUserDidOpenReviewNotification object:self]
                                               postingStyle:NSPostWhenIdle
                                               coalesceMask:NSNotificationCoalescingOnName
                                                   forModes:nil];
}

- (void)visualizerDidClickCancelReview:(iSmartNewsVisualizer*)visualizer
{
    if (_currentNewsMessage == nil)
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"cancel"}];
    }
    
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    [self nothingWasPressed];
}

- (void)visualizerDidClickRemindLaterReview:(iSmartNewsVisualizer*)visualizer
{
    if (_currentNewsMessage == nil)
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"remind"}];
    }
    
    [self resetVisualizerVar:visualizer keepCurrentMessage:YES];
    
    [self nothingWasPressed];
}
@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
