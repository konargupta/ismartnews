//
//  iSmartEventsCenter.m
//  iSmartEventsCenterDemo
//
//

#import "iSmartEventsCenter.h"
#import <UIKit/UIKit.h>

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#if !DEBUG || 1
# define NSLog(...)     ((void)0)
#endif

NSString* const iSmartEventsCenterAppDidFinishLaunchingEvent = @"app:didfinishlaunching";
NSString* const iSmartEventsCenterAppDidFinishLaunchingAfterUpgradeEvent = @"app:didfinishlaunchingafterupgrade";
NSString* const iSmartEventsCenterAppActivateEvent = @"app:activate";
NSString* const iSmartEventsCenterBeforeAnyEvent = @"app:beforeany";
NSString* const iSmartEventsCenterAfterAnyEvent = @"app:afterany";

@implementation iSmartEventsCenter {
    BOOL _blockedForSession;
    NSMutableSet* _blockedEvents;
    NSMutableSet* _blockedServices;
    NSMutableDictionary* _callbacks;
    NSString* _currentEvent;
    UIBackgroundTaskIdentifier _bgTask;
    NSMutableArray* _pendingEvents;
}

+ (instancetype)sharedCenter
{
    static iSmartEventsCenter* inst;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [self new];
    });
    return inst;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _callbacks = [NSMutableDictionary new];
        _blockedEvents = [NSMutableSet new];
        _blockedServices = [NSMutableSet new];
        _bgTask = UIBackgroundTaskInvalid;
        _pendingEvents = [NSMutableArray new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(UIApplicationDidBecomeActiveNotification)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(UIApplicationDidEnterBackgroundNotification)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)registerService:(NSString*)name callback:(iSmartEventsCenterCallback)callback forEvents:(NSArray*)events withPriority:(float)priority
{
    if (![events count])
    {
        events = @[@"any"];
    }
    
    NSMutableArray* low = [NSMutableArray new];
    [events enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [low addObject:[obj lowercaseString]];
    }];
    
    events = [low copy];
    
    for (NSString* event in events)
    {
        NSMutableArray* a = [_callbacks objectForKey:event];
        if (!a){
            a = [NSMutableArray new];
            [_callbacks setObject:a forKey:event];
        }
        [a addObject:@{@"nm":[name copy], @"cb":[callback copy],@"p":@(priority)}];
        [a sortUsingComparator:^NSComparisonResult(id o1, id o2){
            NSNumber* p1 = [o1 objectForKey:@"p"];
            NSNumber* p2 = [o2 objectForKey:@"p"];
            return -[p1 compare:p2];
        }];
    }
}

- (void)registerService:(NSString*)name callback:(iSmartEventsCenterCallback)callback forEvents:(NSArray*)events
{
    [self registerService:name callback:callback forEvents:events withPriority:0.f];
}

- (void)completeEvent:(NSString*)event
               before:(NSMutableArray*)before
                other:(NSMutableArray*)other
               after:(NSMutableArray*)after
               status:(iSmartEventsCenterCallbackStatus)status
{
    if (status == iSmartEventsCenterCallbackBreakForThisEvent){
        _currentEvent = nil;
        [self removeBackgroundTask];        
        return;
    }
    else if (status == iSmartEventsCenterCallbackBreakForTheSameEvents){
        [_blockedEvents addObject:event];
        _currentEvent = nil;
        [self removeBackgroundTask];
        return;
    }
    else if (status == iSmartEventsCenterCallbackBreakForAllEvents){
        _blockedForSession = YES;
        _currentEvent = nil;
        [self removeBackgroundTask];
        return;
    }
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive){
        _currentEvent = nil;
        [self removeBackgroundTask];
        return;
    }
    
    dispatch_block_t next = [^{
        
        [self runEvent:event before:before other:other after:after];
    } copy];
    
    //Async only if really need
    if (([before count] > 0) || ([other count] > 0) || ([after count] > 0))
    {
        dispatch_async(dispatch_get_main_queue(), next);
    }
    else
    {
        next();
    }
}

- (void)runEvent:(NSString*)event before:(NSMutableArray*)before other:(NSMutableArray*)other after:(NSMutableArray*)after
{
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive){
        _currentEvent = nil;
        [self removeBackgroundTask];
        return;
    }
    
    NSDictionary* info;
    
    do{
        if ([before count] > 0){
            info = [before firstObject];
            [before removeObjectAtIndex:0];
            _currentEvent = iSmartEventsCenterBeforeAnyEvent;
            [self setupBackgroundTask];
            
            if (![_blockedServices containsObject:[info objectForKey:@"nm"]]){
                NSLog(@"service found: %@",info);
                break;
            }
            NSLog(@"service is blocked: %@",info);
        }
        else if ([other count] > 0) {
            info = [other firstObject];
            [other removeObjectAtIndex:0];
            _currentEvent = event;
            [self setupBackgroundTask];
            
            if (![_blockedServices containsObject:[info objectForKey:@"nm"]]){
                NSLog(@"service found: %@",info);
                break;
            }
            NSLog(@"service is blocked: %@",info);
        }
        else if ([after count] > 0) {
            info = [after firstObject];
            [after removeObjectAtIndex:0];
            _currentEvent = iSmartEventsCenterAfterAnyEvent;
            [self setupBackgroundTask];
            
            if (![_blockedServices containsObject:[info objectForKey:@"nm"]]){
                NSLog(@"service found: %@",info);
                break;
            }
            NSLog(@"service is blocked: %@",info);
        }
        else {
            _currentEvent = nil;
            [self removeBackgroundTask];
            [self performSelector:@selector(tryToPostPendingEvents) withObject:nil afterDelay:0.0f];
            return;
        }
        
    } while (YES);
    
    iSmartEventsCenterCallback cb = [info objectForKey:@"cb"];
    NSLog(@"Calling callback for event %@", _currentEvent);
    cb(_currentEvent, ^(iSmartEventsCenterCallbackStatus status, NSArray* sessionBlockedServices){
        if (sessionBlockedServices){
            for (NSString* service in sessionBlockedServices){
                if (![self->_blockedServices containsObject:service]){
                    [self->_blockedServices addObject:service];
                }
            }
        }
        NSLog(@"Completion called callback for event %@", _currentEvent);        
        [self completeEvent:event before:before other:other after:after status:status];
    });
}

- (void) postponeEvent:(NSString*) event
{
    if ([_pendingEvents containsObject:event] == NO)
    {
        [_pendingEvents addObject:event];
    }
    [self performSelector:@selector(tryToPostPendingEvents) withObject:nil afterDelay:0.35f];
}

- (void) tryToPostPendingEvents
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];

    NSString* event = nil;
    if ([_pendingEvents count])
    {
        event = [_pendingEvents firstObject];
        [_pendingEvents removeObjectAtIndex:0];
    }
    
    if (event)
    {
        [self postEvent:event tryToDeferDeliveryInsteadOfSkipping:YES];
    }
}

- (void)postEvent:(NSString *)event
{
    [self postEvent:event tryToDeferDeliveryInsteadOfSkipping:NO];
}

- (void)postEvent:(NSString *)event tryToDeferDeliveryInsteadOfSkipping:(BOOL) tryToDefer
{
    event = [event lowercaseString];

    if (_currentEvent)
    {
        //Anti duplicate
        if (tryToDefer && ([_currentEvent isEqualToString:event] == NO))
        {
            [self postponeEvent:event];
            NSLog(@"postEvent postponed (%@)", event);
        }
        else
        {
            NSLog(@"postEvent skipped:act (%@)", event);
        }
        return;
    }
    
    //The app is transitioning to or from the background.
    //If the application goes into background, event may be skipped according other rules (for example at [ runEvent] method)
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive)
    {
        if (tryToDefer && ([event isEqualToString:iSmartEventsCenterAppActivateEvent] == NO))
        {
            [self postponeEvent:event];
            NSLog(@"postEvent delayed (%@)", event);
            return;
        }
        
        //Do not delaying and working as usual
    }
    
    if (_blockedForSession){
        NSLog(@"postEvent skipped:bs (%@)", event);
        return;
    }
    
    if ([_blockedEvents containsObject:event]){
        NSLog(@"postEvent skipped:be (%@)", event);
        return;
    }
    
    NSMutableArray* other = [[_callbacks objectForKey:event] mutableCopy];
    if (![event isEqualToString:@"any"])
    {
        NSArray* anyEvents = [_callbacks objectForKey:@"any"];
        if (anyEvents)
        {
            if (!other)
            {
                other = [NSMutableArray new];
            }
            
            [other addObjectsFromArray:anyEvents];
            [other sortUsingComparator:^NSComparisonResult(id o1, id o2){
                NSNumber* p1 = [o1 objectForKey:@"p"];
                NSNumber* p2 = [o2 objectForKey:@"p"];
                return -[p1 compare:p2];
            }];
        }
    }
    
    [self runEvent:event
            before:[[_callbacks objectForKey:iSmartEventsCenterBeforeAnyEvent] mutableCopy]
             other:other
             after:[[_callbacks objectForKey:iSmartEventsCenterAfterAnyEvent] mutableCopy]
     ];
}

- (void)UIApplicationDidBecomeActiveNotification
{
    [self removeBackgroundTask];
    
    [self postEvent:iSmartEventsCenterAppActivateEvent tryToDeferDeliveryInsteadOfSkipping:YES];
}

- (void)setupBackgroundTask
{
    if (_bgTask != UIBackgroundTaskInvalid){
        return;
    }
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive){
        return;
    }
    
    _bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self removeBackgroundTask];
    }];
    NSLog(@"BG TASK CREATED");    
}

- (void)removeBackgroundTask
{
    if (_bgTask == UIBackgroundTaskInvalid){
        return;
    }
    
    [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
    _bgTask = UIBackgroundTaskInvalid;
    NSLog(@"BG TASK RELEASED");
}

- (void)UIApplicationDidEnterBackgroundNotification
{
    _blockedForSession = NO;
    
    [_blockedEvents removeAllObjects];
    [_blockedServices removeAllObjects];
    
    if (_currentEvent){
        [self setupBackgroundTask];
    }
}

@end
