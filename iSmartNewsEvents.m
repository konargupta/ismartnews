//
//  iSmartNewsEvents.m
//  iSmartNewsDemo
//
//

#if SMARTNEWS_COMPILE

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsEvents.h"
#import "iSmartNewsCoreData.h"
#import "iSmartNewsUtils.h"
#import <objc/message.h>

#ifndef iSmartNewsLog
#if DEBUG
# define iSmartNewsLog(...)         NSLog(@"iSmartNews: %@",[NSString stringWithFormat:__VA_ARGS__])
# define iSmartNewsMainThread       assert([NSThread isMainThread] && "Should be called from main thread only!")
#else//!DEBUG
# define NSLog(...)                 ((void)0)
# ifdef assert
#  undef assert
# endif
# define assert(...)                ((void)0)
# define iSmartNewsMainThread       ((void)0)
# define iSmartNewsLog(...)         ((void)0)
#endif
#endif

static BOOL isPatternValid(NSString* pattern){
    NSArray* p = [pattern componentsSeparatedByString:@"|"];
    __block BOOL isValid = YES;
    NSRegularExpression* re = [NSRegularExpression regularExpressionWithPattern:@"^(ON|OFF)=\\d+$" options:NSRegularExpressionCaseInsensitive error:NULL];
    [p enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([[re matchesInString:obj options:0 range:NSMakeRange(0, [obj length])] count] != 1){
            isValid = NO;
            *stop = YES;
        }
    }];
    return isValid;
}

static void _extractEvent(NSDictionary* event, NSMutableArray* events){
    
    if ([event isKindOfClass:[NSDictionary class]]){
        event = [event iSmartNews_dictionaryWithLowercaseKeys];
    }
    
    NSString* name = getMessageKey(event, @"name");
    NSString* pattern = getMessageKey(event, @"pattern");
    if ([name isKindOfClass:[NSString class]]
        && [pattern isKindOfClass:[NSString class]]){
        name = [[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString];
        if (![name isEqualToString:@""])
        {
            if (!isPatternValid(pattern)){
                pattern = @"ON=1";
            }
            
            [events addObject:@{
                                @"name": name,
                                @"pattern": pattern
                                }];
        }
    }
}

NSArray* preprocessEvents(NSString* serviceName, NSArray* input)
{
#if DEBUG
    {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        assert(isPatternValid(@"oN=1"));
        assert(isPatternValid(@"off=1"));
        assert(isPatternValid(@"off=1|on=4"));
        assert(isPatternValid(@"off=1|ON=4"));
        
        assert(!isPatternValid(@"of=1|on=4"));
        assert(!isPatternValid(@"off=1| on=4"));
        assert(!isPatternValid(@"off=1|on=-4"));
        assert(!isPatternValid(@"off=1|on="));
        assert(!isPatternValid(@"off=1|=45"));
        assert(!isPatternValid(@"off=1||off=45"));
    });
    }
#endif
    
    NSManagedObjectContext* context = managedObjectContext(serviceName);
    
    iSmartNewsLog(@"SMARTNEWS META: ========================EVENTS BEFORE:%@\n ========================",(^id{
        NSError* error;
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"SmartNewsEvent" inManagedObjectContext:context];
        [fetchRequest setEntity:entity];
        [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        NSArray* a = [context executeFetchRequest:fetchRequest error:&error];
        [a enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [(SmartNewsEvent*)obj name];
            [(SmartNewsEvent*)obj newsItem];
            [(SmartNewsEvent*)obj initialPattern];
            [(SmartNewsEvent*)obj currentPattern];
        }];
        return a;
    })());

    
    NSMutableArray* events = [NSMutableArray new];
    NSMutableArray* attachedEvents = [NSMutableArray new];
    
    NSArray* news = [input filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary* bind){
        
        if ([obj objectForKey:@"event"]){
            NSDictionary* event = [obj objectForKey:@"event"];
            _extractEvent(event, events);
            return NO;
        }
        else if ([obj objectForKey:@"meta"]) {
            
            NSDictionary* meta = [obj objectForKey:@"meta"];
            
            if ([meta isKindOfClass:[NSDictionary class]]){
                meta = [meta iSmartNews_dictionaryWithLowercaseKeys];
            }
            
            if ([meta isKindOfClass:[NSDictionary class]]){
                NSString* uuid = [meta objectForKey:@"uuid"];
                if ([uuid isKindOfClass:[NSString class]]){
                    NSDictionary* eventsInfo = getMessageKey(meta,@"events");
                    if ([eventsInfo isKindOfClass:[NSDictionary class]] && ([eventsInfo count] > 0)){
                        [eventsInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                            NSString* eventName = key;
                            NSString* pattern = obj;
                            if ([eventName isKindOfClass:[NSString class]] && [pattern isKindOfClass:[NSString class]]){
                                pattern = [pattern stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                
                                if (!isPatternValid(pattern)){
                                    pattern = @"ON=1";
                                }
                                
                                [attachedEvents addObject:@{
                                                    @"name": eventName,
                                                    @"pattern": pattern,
                                                    @"uuid": uuid
                                                    }];
                            }
                        }];
                    }
                    else {
                        if ([uuid isEqualToString:@"what_is_new"]){
                            [attachedEvents addObject:@{
                                                        @"name": @"app:didfinishlaunchingafterupgrade",
                                                        @"pattern": @"ON=1",
                                                        @"uuid": uuid
                                                        }];
                        }
                    }
                }
            }
        }
        
        return YES;
    }]];
    
    // Add default event
    if ([events count] == 0){
        [events addObject:@{
                            @"name": iSmartEventsCenterAppActivateEvent,
                            @"pattern": @"on=1"
                            }];
        [events addObject:@{
                            @"name": iSmartEventsCenterAppDidFinishLaunchingEvent,
                            @"pattern": @"on=1"
                            }];
        
        [events addObject:@{
                            @"name": iSmartEventsCenterAppDidFinishLaunchingAfterUpgradeEvent,
                            @"pattern": @"on=1"
                            }];
    }
    
    [events sortUsingComparator:^NSComparisonResult(id o1, id o2){
        return [[o1 objectForKey:@"name"] compare:[o2 objectForKey:@"name"]];
    }];
    
    [attachedEvents sortUsingComparator:^NSComparisonResult(id o1, id o2){
        return [[o1 objectForKey:@"name"] compare:[o2 objectForKey:@"name"]];
    }];
    
    { // NOT ATTACHED EVENTS
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"SmartNewsEvent" inManagedObjectContext:context];
        [fetchRequest setEntity:entity];
        [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"newsItem == nil"]];
        
        NSError* error = nil;
        NSMutableArray* existing = [[context executeFetchRequest:fetchRequest error:&error] mutableCopy];
        if (existing){
            
            NSUInteger i = 0;
            NSUInteger j = 0;
            
            NSMutableArray* toDelete = [NSMutableArray new];
            
            while (i < [events count] && j < [existing count])
            {
                NSDictionary* event = [events objectAtIndex:i];
                SmartNewsEvent* eEvent = [existing objectAtIndex:j];
                
                NSString* pattern = [[event objectForKey:@"pattern"] lowercaseString];
                NSString* nName = [[event objectForKey:@"name"] lowercaseString];
                NSString* eName = [eEvent name];
                
                if ([nName compare:eName] == NSOrderedAscending)
                {
                    SmartNewsEvent* eventObj = [NSEntityDescription insertNewObjectForEntityForName:@"SmartNewsEvent" inManagedObjectContext:context];
                    [eventObj setName:nName];
                    [eventObj setInitialPattern:pattern];
                    [eventObj setCurrentPattern:pattern];
                    ++i;
                }
                else if ([nName compare:eName] == NSOrderedDescending)
                {
                    [toDelete addObject:eEvent];
                    ++j;
                }
                else
                {
                    if (![pattern isEqualToString:[eEvent initialPattern]])
                    {
                        [eEvent setInitialPattern:pattern];
                        [eEvent setCurrentPattern:pattern];
                    }
                    
                    ++i;
                    ++j;
                    continue;
                }
            }
            
            for (;j < [existing count];++j)
            {
                [context deleteObject:[existing objectAtIndex:j]];
            }
            
            for (;i < [events count];++i)
            {
                NSDictionary* event = [events objectAtIndex:i];
                NSString* nName = [[event objectForKey:@"name"] lowercaseString];
                NSString* pattern = [[event objectForKey:@"pattern"] lowercaseString];
                SmartNewsEvent* eventObj = [NSEntityDescription insertNewObjectForEntityForName:@"SmartNewsEvent" inManagedObjectContext:context];
                [eventObj setName:nName];
                [eventObj setInitialPattern:pattern];
                [eventObj setCurrentPattern:pattern];
            }
            
            [toDelete enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [context deleteObject:obj];
            }];
        }
    }
    
    { // ATTACHED EVENTS
        
        NSError* error = nil;
        
        NSFetchRequest *allAttachedEventsFetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"SmartNewsEvent" inManagedObjectContext:context];
        [allAttachedEventsFetchRequest setEntity:entity];
        [allAttachedEventsFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        [allAttachedEventsFetchRequest setPredicate:[NSPredicate predicateWithFormat:@"newsItem != nil"]];
        NSMutableArray* allExistingAttachedEvents = [[context executeFetchRequest:allAttachedEventsFetchRequest error:&error] mutableCopy];
        
        while ([attachedEvents count] > 0)
        {
            NSString* currentUUID = nil;
            NSMutableArray* current = [NSMutableArray new];

            for (NSUInteger i = 0; i < [attachedEvents count];){
                if (!currentUUID){
                    currentUUID = [[attachedEvents objectAtIndex:i] objectForKey:@"uuid"];
                    [current addObject:[attachedEvents objectAtIndex:i]];
                    [attachedEvents removeObjectAtIndex:i];
                }
                else {
                    if ( [currentUUID isEqualToString:[[attachedEvents objectAtIndex:i] objectForKey:@"uuid"]] ){
                        [current addObject:[attachedEvents objectAtIndex:i]];
                        [attachedEvents removeObjectAtIndex:i];
                    }
                    else {
                        ++i;
                    }
                }
            }
            
            NSFetchRequest *newItemFetchRequest = [[NSFetchRequest alloc] init];
            NSEntityDescription *newsItemEntity = [NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context];
            [newItemFetchRequest setEntity:newsItemEntity];
            [newItemFetchRequest setPredicate:[NSPredicate predicateWithFormat:@"uuid == %@", currentUUID]];
            NSArray* foundNewsItems = [context executeFetchRequest:newItemFetchRequest error:&error];
            if ([foundNewsItems count] != 1){
                continue;
            }
            
            SmartNewsItem* newsItem = [foundNewsItems firstObject];
            
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            NSEntityDescription *entity = [NSEntityDescription entityForName:@"SmartNewsEvent" inManagedObjectContext:context];
            [fetchRequest setEntity:entity];
            [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"newsItem == %@", newsItem]];
            
            NSMutableArray* existing = [[context executeFetchRequest:fetchRequest error:&error] mutableCopy];
            if (existing){
                
                NSUInteger i = 0;
                NSUInteger j = 0;
                
                NSMutableArray* toDelete = [NSMutableArray new];
                
                while (i < [current count] && j < [existing count])
                {
                    NSDictionary* event = [current objectAtIndex:i];
                    SmartNewsEvent* eEvent = [existing objectAtIndex:j];
                    
                    NSString* pattern = [[event objectForKey:@"pattern"] lowercaseString];
                    NSString* nName = [[event objectForKey:@"name"] lowercaseString];
                    NSString* eName = [eEvent name];
                    
                    if ([nName compare:eName] == NSOrderedAscending)
                    {
                        SmartNewsEvent* eventObj = [NSEntityDescription insertNewObjectForEntityForName:@"SmartNewsEvent" inManagedObjectContext:context];
                        [eventObj setName:nName];
                        [eventObj setNewsItem:newsItem];
                        [eventObj setInitialPattern:pattern];
                        [eventObj setCurrentPattern:pattern];
                        ++i;
                    }
                    else if ([nName compare:eName] == NSOrderedDescending)
                    {
                        [toDelete addObject:eEvent];
                        ++j;
                    }
                    else
                    {
                        [allExistingAttachedEvents removeObject:eEvent];
                        
                        if (![pattern isEqualToString:[eEvent initialPattern]])
                        {
                            [eEvent setInitialPattern:pattern];
                            [eEvent setCurrentPattern:pattern];
                        }
                        
                        ++i;
                        ++j;
                        continue;
                    }
                }
                
                for (;j < [existing count];++j)
                {
                    [context deleteObject:[existing objectAtIndex:j]];
                }
                
                for (;i < [current count];++i)
                {
                    NSDictionary* event = [current objectAtIndex:i];
                    NSString* nName = [[event objectForKey:@"name"] lowercaseString];
                    NSString* pattern = [[event objectForKey:@"pattern"] lowercaseString];
                    SmartNewsEvent* eventObj = [NSEntityDescription insertNewObjectForEntityForName:@"SmartNewsEvent" inManagedObjectContext:context];
                    [eventObj setName:nName];
                    [eventObj setNewsItem:newsItem];
                    [eventObj setInitialPattern:pattern];
                    [eventObj setCurrentPattern:pattern];
                }
                
                [toDelete enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [allExistingAttachedEvents removeObject:obj];
                    [context deleteObject:obj];
                }];
            }
        }
        
        [allExistingAttachedEvents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [context deleteObject:obj];
        }];
    }
    
    saveContext(serviceName);
    
    iSmartNewsLog(@"SMARTNEWS META: ========================EVENTS AFTER:%@\n ========================",(^id{
        NSError* error;
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"SmartNewsEvent" inManagedObjectContext:context];
        [fetchRequest setEntity:entity];
        [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        NSArray* a = [context executeFetchRequest:fetchRequest error:&error];
        [a enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [(SmartNewsEvent*)obj name];
            [(SmartNewsEvent*)obj newsItem];
            [(SmartNewsEvent*)obj initialPattern];
            [(SmartNewsEvent*)obj currentPattern];
        }];
        return a;
    })());
                     
    return news;
}

#endif//#if SMARTNEWS_COMPILE
