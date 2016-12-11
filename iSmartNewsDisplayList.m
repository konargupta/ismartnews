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

@interface iSmartNewsDisplayList ()<iSmartNewsVisualizerDelegate>

@end

@implementation iSmartNewsDisplayList
{
    iSmartNewsVisualizer* _visualizer;
    
    /*! @internal */
    NSMutableArray*         loadedNews_;
    NSMutableSet*           loadedNewsEvents_;
    
    NSString* currentQueue_;
    NSMutableDictionary* queuesTimeouts_;
    
    NSTimer* queueTimer_;
    NSTimer* retryTimer_;
    
    BOOL isFirst_;
    
    /*! @internal */
    /*! @since Version 1.3 */
    NSUInteger              gate_;
    
    BOOL _listWasEnded;
    BOOL _forceSwitchFlag;
}

@synthesize currentNewsMessage = _currentNewsMessage;

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        loadedNews_     = [NSMutableArray new];
        queuesTimeouts_ = [NSMutableDictionary new];
        gate_ = UINT_MAX;
    }
    return self;
}

- (void)assignNews:(NSArray*) news enveronment:(NSDictionary*) enveronment
{
    if (_forceSwitchFlag)
    {
        iSmartNewsLog(@"forceHide afrer assign new news");
        [self forceHide];
        _forceSwitchFlag = NO;
    }
    
    [queueTimer_ invalidate];
    queueTimer_ = nil;
    
    [retryTimer_ invalidate];
    retryTimer_ = nil;
    
    currentQueue_ = nil;
    [queuesTimeouts_ removeAllObjects];
    
    gate_ = UINT_MAX;
    
    NSDictionary* queueTimeouts = [enveronment objectForKey:@"queueTimeouts"];
    if ([queueTimeouts count] > 0)
    {
        [queuesTimeouts_ addEntriesFromDictionary:queueTimeouts];
    }
    
    NSNumber* gate = [enveronment objectForKey:@"gate"];
    if (gate != nil)
    {
        gate_ = [gate unsignedIntegerValue];
        [queuesTimeouts_ addEntriesFromDictionary:queueTimeouts];
    }
    
    isFirst_ = YES;
    
    loadedNews_ = [news mutableCopy];
    
    _listWasEnded = NO;
    
    NSObject<iSmartNewsDisplayListDelegate>* delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(displayListWasAssignedNewMessages:)])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [delegate displayListWasAssignedNewMessages:self];
        });
    }
}

-(iSmartNewsVisualizer *)visualizer
{
    return _visualizer;
}

#pragma mark -

- (void)listWasEnded
{
    if (_listWasEnded)
        return;
    
    _listWasEnded = YES;
    
    NSObject<iSmartNewsDisplayListDelegate>* delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(displayListWasEnded:)])
    {
        [delegate displayListWasEnded:self];
    }
}

-(void)resetEndedFlag
{
    _listWasEnded = NO;
}

-(void)setForceSwitchFlag
{
    _forceSwitchFlag = YES;
}

- (void)forceHide
{
    [_visualizer forceHide];
    [self resetVisualizerVar];
    
    [retryTimer_ invalidate];
    retryTimer_ = nil;
    
    [queueTimer_ invalidate];
    queueTimer_ = nil;
    
    currentQueue_ = nil;
    
    [queuesTimeouts_   removeAllObjects];
    [loadedNews_       removeAllObjects];
    [loadedNewsEvents_ removeAllObjects];
    
    [self listWasEnded];
}

- (void)resetVisualizerVar
{
    _visualizer.delegate = nil;
    
    // WE delay destruction of visualizer to prevent will/hide notification to be sent for each news item.
    // If delay is used then notifications will be sent only once per block.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [_visualizer description];//some fake call
    });
    
    _visualizer = nil;
    _currentNewsMessage = nil;
}

- (void)showNextMessage
{
    if (_visualizer){
        return;
    }
    
    [retryTimer_ invalidate];
    retryTimer_ = nil;
    
    [queueTimer_ invalidate];
    queueTimer_ = nil;
    
    // counter logic, new since version 1.2
    const UInt64 counter = [[self delegate] displayListGetCounterValue:self];
    
    NSDate* currentDate = [NSDate ism_date];
    for (;
         [loadedNews_ count];
         [loadedNews_ removeObjectAtIndex:0]
         )
    {
        NSDictionary* description = [loadedNews_ objectAtIndex:0];
        
        iSmartNewsLog(@"checking message: %@",description);
        
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
        
        for (NSString* key in @[iSmartNewsMessageTitleKey, iSmartNewsMessageTextKey, iSmartNewsMessageCancelKey, iSmartNewsMessageActionKey, iSmartNewsMessageReviewKey, iSmartNewsMessageUrlKey, iSmartNewsMessageReviewTypeKey])
        {
            NSString* value = [description objectForKey:key];
            if (value != nil)
            {
                [alertViewDescription setObject:value forKey:key];
            }
        }
        
        NSString* message   = [description objectForKey:iSmartNewsMessageTextKey];
        
        NSString* queue = [description objectForKey:iSmartNewsMessageQueueKey];
        if (queue)
        {
            //Make current queue
            if (!currentQueue_ || ![queue isEqualToString:currentQueue_])
            {
                currentQueue_ = [queue copy];
                
                NSUInteger nQueued = 0;
                
                //Found all news with same queue
                for (NSDictionary* m in loadedNews_)
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
                
                [loadedNews_ removeObjectsInRange:NSMakeRange(0, [n unsignedIntValue])];
                [loadedNews_ removeObjectsInRange:NSMakeRange(1, nQueued - [n unsignedIntValue] - 1)];
                
                n = @([n unsignedIntValue] + 1);
                [q_indexes setObject:n forKey:queue];
                
                [queueInfo saveQueuesInfo];
                
                iSmartNewsLog(@"NEXT INDEX %@",n);
                
                NSNumber* timeout = [queuesTimeouts_ objectForKey:queue];
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
        
        if ([[self delegate] displayListCanShowAlertView:self] != YES)
        {
            retryTimer_ = [NSTimer scheduledTimerWithTimeInterval:1
                                                           target:self
                                                         selector:@selector(showNextMessage)
                                                         userInfo:nil repeats:NO];
            return;
        }
        
        isFirst_ = NO;
        
        NSString * messageType = [description objectForKey:iSmartNewsMessageTypeKey];
        
        const BOOL showRemoveAdsButton = [description objectForKey:@"removeAdsAction"] != nil;
        NSString* uuid = [description objectForKey:@"uuid"];
        
        iSmartNewsVisualizerShownBlock shownBlock;
        
        if ([uuid length] > 0)
        {
            SmartNewsItem* metaItem = sn_findMetaItem(self.service, uuid);
            if (metaItem){
                
                if ([[metaItem valueForKey:@"sequenceSrc"] length] > 0)
                {
                    NSArray* s = [[metaItem valueForKey:@"sequence"] componentsSeparatedByString:@"|"];
                    if ([s count] > 1){
                        NSString* ns = [[s subarrayWithRange:NSMakeRange(1, [s count] - 1)] componentsJoinedByString:@"|"];
                        [metaItem setValue:ns forKey:@"sequence"];
                        
                        iSmartNewsLog(@"sequence updated to %@", [metaItem valueForKey:@"sequence"]);
                    }
                    else{
                        [metaItem setValue:[metaItem valueForKey:@"sequenceSrc"] forKey:@"sequence"];
                        [metaItem setValue:[metaItem valueForKey:@"urlsSrc"] forKey:@"urls"];
                        
                        iSmartNewsLog(@"sequence reset to %@", [metaItem valueForKey:@"sequence"]);
                        
                        if ([[metaItem randomize] boolValue]){
                            [metaItem randomizeUrlsAndSequence];
                            
                            iSmartNewsLog(@"sequence/urls randomized to %@/%@ ", [metaItem valueForKey:@"sequence"], [metaItem valueForKey:@"urls"]);
                        }
                    }
                }
                else
                {
                    NSArray* urls = [[metaItem valueForKey:@"urls"] componentsSeparatedByString:@"!!!"];
                    NSUInteger nextUrlIndex = (NSUInteger)[[metaItem valueForKey:@"urlIndex"] intValue] + 1;
                    if (nextUrlIndex >= [urls count]){
                        nextUrlIndex = 0;
                        
                        if ([[metaItem randomize] boolValue]){
                            [metaItem randomizeUrlsAndSequence];
                            
                            iSmartNewsLog(@"sequence/urls randomized to %@/%@ ", [metaItem valueForKey:@"sequence"], [metaItem valueForKey:@"urls"]);
                        }
                    }
                    [metaItem setValue:@(nextUrlIndex) forKey:@"urlIndex"];
                }
                
                saveContext(self.service);
                
                NSDate* shownDate = [NSDate ism_date];
                NSString* serviceName = self.service;
                
                shownBlock = ^{
                    NSString* rangeUuid = [description objectForKey:@"rangeUuid"];
                    
                    if ([rangeUuid length] > 0){
                        NSManagedObject* metaRangeItem = sn_findMetaRangeItem(serviceName, metaItem,rangeUuid);
                        if (metaRangeItem){
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
            }
        }
        
        if ([messageType isEqualToString:iSmartNewsContentTypeWeb])
        {
            iSmartNewsVisualizerAppearance appearance = _visualizerAppearance;
            
            _visualizer = [[iSmartNewsVisualizer alloc] initWebViewVisualizerWithURL:[NSURL URLWithString:message] appearance:appearance showRemoveAdsButton:showRemoveAdsButton];
            _visualizer.embeddedPanel = _visualizerEmbeddedPanel;
        }
        else
        {
            assert(_visualizerAppearance == isnVisualizerAppearancePopup);
            
            _visualizer = [[iSmartNewsVisualizer alloc] initAlertViewVisualizerWithDescription:alertViewDescription];
        }
        
        if (!_visualizer){
            continue;
        }
        if (self.visualizerStateNotificationReceiver != nil)
        {
            _visualizer.stateNotificationReceiver = self.visualizerStateNotificationReceiver;
        }
        
        _currentNewsMessage = description;
        
        _visualizer.shownBlock = shownBlock;
        _visualizer.allowAllIphoneOrientations = [[description objectForKey:@"allowAllIphoneOrientations"] isKindOfClass:[NSNumber class]] && [[description objectForKey:@"allowAllIphoneOrientations"] boolValue];
        
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
        
        if (mask != 0){
            _visualizer.orientationMask = mask;
        }
        
        NSRange showDelayRange = NSMakeRange(0, 0);
        
        if ([description objectForKey:@"minDelay"] && [description objectForKey:@"maxDelay"])
        {
            showDelayRange = NSMakeRange( [[description objectForKey:@"minDelay"] unsignedIntegerValue],
                                          [[description objectForKey:@"maxDelay"] unsignedIntegerValue] - [[description objectForKey:@"minDelay"] unsignedIntegerValue]);
        }
        
        _visualizer.metaUUID = uuid;
        _visualizer.onShow = [description objectForKey:@"onShow"];
        _visualizer.delegate = self;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_visualizer showWithDelayRange:showDelayRange];
        });
        
        return;
    }
    

    if (/*!connection_ &&*/ ([loadedNews_ count] == 0)){
        [self listWasEnded];
    }
}

#pragma mark -

- (void)nothingWasPressed
{
    if (![loadedNews_ count])
        return;
    
    [loadedNews_ removeObjectAtIndex:0];
    
    //--
    // new since version 1.3
    if (--gate_ == 0)
    {
        [loadedNews_ removeAllObjects];
        [self listWasEnded];
        return;
    }
    //--
    
    [self showNextMessage];
}

- (void)cancelWasPressed
{
    if (![loadedNews_ count])
        return;
    
    NSDictionary* message = [loadedNews_ objectAtIndex:0];
    
    iSmartNewsLog(@"CANCEL button clicked");
    
    if (![[message objectForKey:iSmartNewsMessageAlwaysKey] boolValue]
        && ![[message objectForKey:iSmartNewsMessageRepeatKey] boolValue])
    {
        //[self setCacheValue:message];
        [[self delegate] displayList:self markItemIsShown:message info:@{@"isMessage" : @(YES)}];
    }
    
    [loadedNews_ removeObjectAtIndex:0];
    
    //--
    // new since version 1.3
    if (--gate_ == 0)
    {
        [loadedNews_ removeAllObjects];
        [self listWasEnded];
        return;
    }
    //--
    
    [self showNextMessage];
}

- (void)actionWasPressed
{
    if (![loadedNews_ count])
        return;
    
    NSDictionary* message = [loadedNews_ objectAtIndex:0];
    
    iSmartNewsLog(@"OK button clicked");
    
    if (![[message objectForKey:iSmartNewsMessageAlwaysKey] boolValue])
    {
        //[self setCacheValue:message];
        [[self delegate] displayList:self markItemIsShown:message info:@{@"isMessage" : @(YES)}];
    }
    
    NSString* urlString = [message objectForKey:iSmartNewsMessageUrlKey];
    if (urlString)
    {
        iSmartNewsLog(@"Opening URL: %@",urlString);
        NSURL* url = [NSURL URLWithString:urlString];
        if (url){
            if ([[UIApplication sharedApplication] canOpenURL:url]){
                [[UIApplication sharedApplication] openURL:url];
            }
        }
    }
    
    [loadedNews_ removeObjectAtIndex:0];
    
    //--
    // new since version 1.3
    if (--gate_ == 0)
    {
        [loadedNews_ removeAllObjects];
        [self listWasEnded];
        return;
    }
    //--
    
    [self showNextMessage];
}


#pragma mark -
#pragma mark iSmartVisualizerDelegate

- (void)visualizerDidFail:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    [self resetVisualizerVar];
    
    [self nothingWasPressed];
}

- (void)visualizerDidClickNothing:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"cancel"}];
    }
    
    [self resetVisualizerVar];
    
    [self nothingWasPressed];
}

- (void)visualizerDidClickCancel:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"cancel"}];
    }
    
    [self resetVisualizerVar];
    
    [self cancelWasPressed];
}

- (void)visualizerDidClickOk:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"ok"}];
    }
    
    [self resetVisualizerVar];
    
    [self actionWasPressed];
}


- (void)visualizerDidClickLink:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
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
    
    [self resetVisualizerVar];
    
    [self nothingWasPressed]; //Link == external handler on server
}

- (void)visualizerDidClickCallback:(iSmartNewsVisualizer*)visualizer userInfo:(NSDictionary*)userInfo
{
    if (![loadedNews_ count])
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
        
        [self resetVisualizerVar];
        
        [self nothingWasPressed];
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
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:iSmartNewsDidOpenCallbackNotification object:self userInfo:notificationUserInfo]
                                               postingStyle:NSPostWhenIdle
                                               coalesceMask:NSNotificationNoCoalescing
                                                   forModes:nil];
    
    iSmartNewsLog(@"send callback with userInfo: %@", notificationUserInfo);
}

- (void)visualizerDidClickRemoveAds:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"removeads"}];
    }
    
    [self resetVisualizerVar];
    
    NSDictionary* description = [loadedNews_ objectAtIndex:0];
    
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
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"review"}];
    }
    
    [self resetVisualizerVar];
    
    [self nothingWasPressed];
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:iSmartNewsUserDidOpenReviewNotification object:self]
                                               postingStyle:NSPostWhenIdle
                                               coalesceMask:NSNotificationCoalescingOnName
                                                   forModes:nil];
}

- (void)visualizerDidClickCancelReview:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"cancel"}];
    }
    
    [self resetVisualizerVar];
    
    [self nothingWasPressed];
}

- (void)visualizerDidClickRemindLaterReview:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    if ([visualizer.metaUUID length] > 0)
    {
        [[self delegate] displayList:self markItemIsShown:@{@"uuid" : visualizer.metaUUID} info:@{@"condition" : @"remind"}];
    }
    
    [self resetVisualizerVar];
    
    [self nothingWasPressed];
}
@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
