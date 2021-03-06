//
//  iSmartNewsMeta.m
//  iSmartNewsDemo
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsMeta.h"
#import "iSmartNewsInternal.h"

#pragma mark - Internal Utils

__attribute__((visibility("hidden"))) static NSDate * meta_toUtcTime(NSDate* date)
{
    NSTimeZone *tz = [NSTimeZone defaultTimeZone];
    NSInteger seconds = -[tz secondsFromGMTForDate:date];
    return [NSDate dateWithTimeInterval:seconds sinceDate:date];
}

__attribute__((visibility("hidden"))) static id meta_adoptUtcDates(id obj){
#if DEBUG
    {
        static BOOL volatile tested = NO;
        if (!tested){
            tested = YES;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                
                NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
                formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
                formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
                
                NSString *dateString = @"2016-12-19T16:39:57Z";
                NSDate *date = [formatter dateFromString:dateString];
                
                {
                    NSDictionary* original = @{ @"1": date };
                    NSDictionary* adopted = meta_adoptUtcDates(original);
                    assert(![[adopted objectForKey:@"1"] isEqualToDate:date]);
                }
            });
        }
    }
#endif
    
    if ([obj isKindOfClass:[NSDictionary class]]){
        NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:[obj count]];
        [obj enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [dict setObject:meta_adoptUtcDates(obj) forKey:key];
        }];
        return [dict copy];
    }
    else if ([obj isKindOfClass:[NSArray class]]){
        NSMutableArray* arr = [NSMutableArray arrayWithCapacity:[obj count]];
        [obj enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [arr addObject:meta_adoptUtcDates(obj)];
        }];
        return [arr copy];
    }
    else if ([obj isKindOfClass:[NSDate class]]){
        return meta_toUtcTime(obj);
    }
    else {
        return obj;
    }
}

#pragma mark - Clear

static NSMutableDictionary* g_sn_eventShownNews = nil;

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES void sn_evenShownNewsClearForService(NSString* service)
{
    if (!g_sn_eventShownNews){
        g_sn_eventShownNews = [NSMutableDictionary dictionaryWithCapacity:10];
    }
    else
    {
        [[g_sn_eventShownNews objectForKey:service] removeAllObjects];
    }
}

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES void sn_removeOldMeta(NSString* serviceName, NSSet* _activeUuuids){
    
    NSMutableSet* activeUuuids = [_activeUuuids mutableCopy];
    
    NSManagedObjectContext *context =  managedObjectContext(serviceName);
    if (!context){
        return;
    }
    
    NSSet* protected = sn_protectedItems();
    for (id k in protected){
        if ([k isKindOfClass:[NSString class]]){
            if (![activeUuuids containsObject:k]){
                [activeUuuids addObject:k];
            }
        }
    }
    
    NSFetchRequest* notActiveItemsRequest = [[NSFetchRequest alloc] init];
    [notActiveItemsRequest setEntity:[NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context]];
    [notActiveItemsRequest setPredicate:[NSPredicate predicateWithFormat:@"NOT (uuid IN %@)",activeUuuids]];
    
    NSArray* itemsForRemove = [context executeFetchRequest:notActiveItemsRequest error:NULL];
    
    // additionally filter by regular patterns
    itemsForRemove = [itemsForRemove filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {

        SmartNewsItem* item = evaluatedObject;
        for (id k in protected){
            if ([k isKindOfClass:[NSRegularExpression class]]){
                const NSUInteger numberOfMatches = [k numberOfMatchesInString:[item uuid]
                                                                      options:0
                                                                        range:NSMakeRange(0, [[item uuid] length])];
                
                if (numberOfMatches != 0){
                    return NO;
                }
            }
        }
        
        return YES;
    }]];
    
    NSFetchRequest* savedItemsRequest = [[NSFetchRequest alloc] init];
    [savedItemsRequest setEntity:[NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context]];
    [savedItemsRequest setPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", itemsForRemove]];
    
    [itemsForRemove enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL* stop){
        [context deleteObject:obj];
    }];
    
    NSArray* itemsSaved = [context executeFetchRequest:savedItemsRequest error:NULL];
    [itemsSaved enumerateObjectsUsingBlock:^(SmartNewsItem* obj, NSUInteger idx, BOOL* stop){
        
        if ([_activeUuuids containsObject:[obj uuid]])
            obj.notPresented = @(NO);
        else
            obj.notPresented = @(YES);
    }];
    
    saveContext(serviceName);
}

INTERNAL_ATTRIBUTES void sn_clearMeta(NSString* serviceName)
{
    [[iSmartNews newsForService:serviceName] resetAll];
}

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES void sn_metaReset(NSString* serviceName){
    
    NSManagedObjectContext* context = managedObjectContext(serviceName);
    if (!context)
        return;
    
    NSDate* now = [NSDate ism_date];
    NSCalendar* calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    
    NSDateComponents* monthComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:now];
    [monthComponents setYear:SMARTNEWS_PER_MONTH_YEAR];
    [monthComponents setMonth:SMARTNEWS_PER_CONST_MONTH];
    NSDate* monthDate = [calendar dateFromComponents:monthComponents];
    
    NSDateComponents* weekComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:now];
    
    const long a = (14 - [weekComponents month]) / 12;
    const long y = [weekComponents year] - a;
    const long m = [weekComponents month] + 12 * a - 2;
    long nowOfWeek = (7000 + ([weekComponents day] + y + y / 4 - y / 100 + y / 400 + (31 * m) / 12)) % 7;
    if (nowOfWeek == 0){
        nowOfWeek = 7;
    }
    
    [weekComponents setYear:SMARTNEWS_PER_WEEK_YEAR];
    [weekComponents setMonth:SMARTNEWS_PER_CONST_MONTH];
    [weekComponents setDay:nowOfWeek];
    NSDate* weekDate = [calendar dateFromComponents:weekComponents];
    
    NSFetchRequest *fetchRequestForRanges = [[NSFetchRequest alloc] init];
    [fetchRequestForRanges setEntity:[NSEntityDescription entityForName:@"SmartNewsTimeRange" inManagedObjectContext:context]];
    [fetchRequestForRanges setPredicate:[NSPredicate predicateWithFormat:@"NOT ( ((start <= %@) AND (end > %@)) OR ((start <= %@) AND (end > %@)) OR ((start <= %@) AND (end > %@)) )",now,now,monthDate,monthDate,weekDate,weekDate]];
    NSArray* foundMetaRanges = [context executeFetchRequest:fetchRequestForRanges error:NULL];
    
    for (NSManagedObject* range in foundMetaRanges){
        [range setValue:@(0) forKey:@"shown"];
        [range setValue:nil forKey:@"probability"];
        iSmartNewsLog(@"SMARTNEWS META CLEAR: %@",range);
    }
    
    saveContext(serviceName);
}

#pragma mark - Parse

INTERNAL_ATTRIBUTES NSDate* sn_preprocessDate(id date)
{
    static NSCalendar* calendar = nil;
    if (!calendar){
        calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        if (!calendar)
            return nil;
    }
    
    if ([date isKindOfClass:[NSDate class]])
        return date;
    
    if (![date isKindOfClass:[NSString class]])
        return nil;
    
    static NSRegularExpression* regex = nil;
    if (!regex){
        regex = [NSRegularExpression regularExpressionWithPattern:@"^(MO|TU|WE|TH|FR|SA|SU)\\((\\d\\d):(\\d\\d)\\)$" options:NSRegularExpressionCaseInsensitive error:NULL];
        if (!regex){
            return nil;
        }
    }
    
    NSArray* matches = [regex matchesInString:(NSString*)date options:0 range:NSMakeRange(0, [(NSString*)date length])];
    if ([matches count] == 0){
        
        static NSRegularExpression* regex = nil;
        if (!regex){
            regex = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+)\\((\\d\\d):(\\d\\d)\\)$" options:NSRegularExpressionCaseInsensitive error:NULL];
            if (!regex){
                return nil;
            }
        }
        
        NSArray* matches = [regex matchesInString:(NSString*)date options:0 range:NSMakeRange(0, [(NSString*)date length])];
        if ([matches count] == 0){
            return nil;
        }
        
        NSTextCheckingResult* match = [matches firstObject];
        NSString* day = [[(NSString*)date substringWithRange:[match rangeAtIndex:1]] uppercaseString];
        NSString* hours = [(NSString*)date substringWithRange:[match rangeAtIndex:2]];
        NSString* minutes = [(NSString*)date substringWithRange:[match rangeAtIndex:3]];
        
        if ([day integerValue] >= 32)
            return nil;
        
        if ([hours integerValue] >= 24)
            return nil;
        
        if ([minutes integerValue] >= 60)
            return nil;
        
        NSDateComponents* components = [[NSDateComponents alloc] init];
        components.year = SMARTNEWS_PER_MONTH_YEAR;
        components.month = SMARTNEWS_PER_CONST_MONTH;
        components.day = [day integerValue];
        components.hour = [hours integerValue];
        components.minute = [minutes integerValue];
        components.second = 0;
        components.calendar = calendar;
        
        return [calendar dateFromComponents:components];
    }
    
    NSTextCheckingResult* match = [matches firstObject];
    NSString* day = [[(NSString*)date substringWithRange:[match rangeAtIndex:1]] uppercaseString];
    NSString* hours = [(NSString*)date substringWithRange:[match rangeAtIndex:2]];
    NSString* minutes = [(NSString*)date substringWithRange:[match rangeAtIndex:3]];
    
    if ([hours integerValue] >= 24)
        return nil;
    
    if ([minutes integerValue] >= 60)
        return nil;
    
    NSDateComponents* components = [[NSDateComponents alloc] init];
    components.year = SMARTNEWS_PER_WEEK_YEAR;
    components.month = SMARTNEWS_PER_CONST_MONTH;
    
    if      ([day isEqualToString:@"MO"]) components.day = 1;
    else if ([day isEqualToString:@"TU"]) components.day = 2;
    else if ([day isEqualToString:@"WE"]) components.day = 3;
    else if ([day isEqualToString:@"TH"]) components.day = 4;
    else if ([day isEqualToString:@"FR"]) components.day = 5;
    else if ([day isEqualToString:@"SA"]) components.day = 6;
    else if ([day isEqualToString:@"SU"]) components.day = 7;
    else return nil;
    
    components.hour = [hours integerValue];
    components.minute = [minutes integerValue];
    components.second = 0;
    components.nanosecond = 0;
    components.calendar = calendar;
    
    return [calendar dateFromComponents:components];
};

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSString* sn_preprocessConditionValue(id condition)
{
    if ([condition isKindOfClass:[NSString class]])
    {
        NSArray* c = [[(NSString*)condition stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"|"];
        NSMutableArray* trimmed = [NSMutableArray arrayWithCapacity:[c count]];
        for (NSString* s in c)
        {
            [trimmed addObject:[s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
            
        return [trimmed componentsJoinedByString:@"|"];
    }
    else if ([condition isKindOfClass:[NSArray class]])
    {
        NSMutableArray* trimmed = [NSMutableArray arrayWithCapacity:[(NSArray*)condition count]];
        for (NSString* s in condition)
        {
            if (![s isKindOfClass:[NSString class]])
            {
                continue;
            }
            [trimmed addObject:[s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
            
        return [trimmed componentsJoinedByString:@"|"];
    }
    else
    {
        return @"";
    }
}

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSArray* sn_preprocessMeta(NSString* serviceName, NSArray* input, NSMutableSet* metaUuid)
{
    NSDate*  launchDate = [[iSmartNews newsForService:serviceName] launchDate];
    
    return [input filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary* bind){
        
        if (![obj objectForKey:@"meta"]){
            return YES;
        }
        
        NSManagedObjectContext *context =  managedObjectContext(serviceName);
        if (!context){
            return NO;
        }
        
        NSDictionary* meta = [obj objectForKey:@"meta"];
        if (![meta isKindOfClass:[NSDictionary class]]){
            return NO;
        }
        
        meta = [meta iSmartNews_dictionaryWithLowercaseKeys];
        
        if ([[meta objectForKey:@"uselocaltime"] isKindOfClass:[NSNumber class]]
            && [[meta objectForKey:@"uselocaltime"] boolValue]){
            meta = meta_adoptUtcDates(meta);
        }
        
        NSString* uuid = getMessageKey(meta,@"uuid");
        
        // generate some values for predefined news
        if ([uuid isKindOfClass:[NSString class]]){
            if ([uuid isEqualToString:@"review"]){
                if (![meta iSmartNews_objectForKey:@"oncePerVersion"]){
                    NSMutableDictionary* d = [meta mutableCopy];
                    [d setObject:@"cancel|review|ok" forKey:@"onceperversion"];
                    meta = [d copy];
                }
            }
            else if ([uuid isEqualToString:@"what_is_new"]){
                if (![meta iSmartNews_objectForKey:@"oncePerVersion"]){
                    NSMutableDictionary* d = [meta mutableCopy];
                    [d setObject:@"cancel|ok" forKey:@"onceperversion"];
                    meta = [d copy];
                }
                if (![meta iSmartNews_objectForKey:@"showOnlyIfUpgrade"]){
                    NSMutableDictionary* d = [meta mutableCopy];
                    [d setObject:@(YES) forKey:@"showonlyifupgrade"];
                    meta = [d copy];
                }
            }
            else if ([uuid isEqualToString:@"subscribe"] || [uuid hasPrefix:@"subscribe_"]){
                if (![meta iSmartNews_objectForKey:@"oncePerInstall"]){
                    NSMutableDictionary* d = [meta mutableCopy];
                    [d setObject:@"cancel|ok" forKey:@"onceperinstall"];
                    meta = [d copy];
                }
            }
        }
        
        NSNumber* ignore = getMessageKey(meta,@"ignore");
        if ([ignore isKindOfClass:[NSNumber class]]){
            if ([ignore boolValue]){
                return NO;
            }
        }
        
        NSNumber* firstshowinterval = (NSNumber*)getMessageKey(meta,@"FirstShowInterval");
        if ([firstshowinterval isKindOfClass:[NSNumber class]] && launchDate)
        {
            NSDate* currentDate = [NSDate ism_date];
            if ([currentDate iSmartNews_calendarIntervalSinceDate:launchDate] < [firstshowinterval unsignedIntegerValue]){
                iSmartNewsLog(@"FirstShowInterval not reached: %d",(int)([currentDate iSmartNews_calendarIntervalSinceDate:launchDate]));
                return NO;
            }
        }
        
        NSDate* start = getMessageKey(meta,@"start");
        NSDate* end = getMessageKey(meta,@"end");
        NSArray* dates = getMessageKey(meta,@"dates");
        NSString* queue = getMessageKey(meta, @"queue");
        NSNumber* randomize = getMessageKey(meta,@"randomize");
        NSString* fixUrl    = getMessageKey(meta, @"fixurl");
        NSString* orientations = getMessageKey(meta,@"orientations");
        if (![orientations isKindOfClass:[NSString class]]){
            orientations = @"up";
        }
        else {
            orientations = [[orientations lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        
        NSString* segment = getMessageKey(meta,@"segment");
        if (![segment isKindOfClass:[NSString class]]){
            segment = nil;
        }
        else {
            segment = [segment stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([segment length] == 0){
                segment = nil;
            }
            else {
                NSArray* const segmentsToCheck = [[segment lowercaseString] componentsSeparatedByString:@"|"];
                NSMutableArray* normalizedSegmentsToCheck = [NSMutableArray arrayWithCapacity:[segmentsToCheck count]];
                [segmentsToCheck enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    NSString* normalized = [obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if ([normalized length] > 0){
                        [normalizedSegmentsToCheck addObject:normalized];
                    }
                }];
                segment = [normalizedSegmentsToCheck componentsJoinedByString:@"|"];
                if ([segment length] == 0){
                    segment = nil;
                }
            }
        }

        NSNumber* priority = getMessageKey(meta,@"priority");
        if (![priority isKindOfClass:[NSNumber class]]){
            priority = nil;
        }
        
        NSNumber* autoHideInterval = getMessageKey(meta,@"autoHideInterval");
        if (![autoHideInterval isKindOfClass:[NSNumber class]])
        {
            autoHideInterval = nil;
        }
        
        NSNumber* minDelay = getMessageKey(meta,@"minDelay");
        NSNumber* maxDelay = getMessageKey(meta,@"maxDelay");
        
        if (([minDelay isKindOfClass:[NSNumber class]] && [maxDelay isKindOfClass:[NSNumber class]]) != YES)
        {
            minDelay = nil;
            maxDelay = nil;
        }

        if (minDelay != nil && maxDelay == nil)
        {
            minDelay = nil;
            maxDelay = nil;
        }
            
        if (maxDelay != nil && minDelay == nil)
        {
            minDelay = @(0);
        }
        
        if (maxDelay != nil && [maxDelay intValue] > 60)
        {
            maxDelay = @(60);
        }
        
        if (([minDelay intValue] > [maxDelay intValue]) || ([minDelay intValue] < 0))
        {
            minDelay = nil;
            maxDelay = nil;
        }
        
        NSString* minShowInterval = getMessageKey(meta,@"minShowInterval");
        if ([minShowInterval isKindOfClass:[NSNumber class]]){
            minShowInterval = [(NSNumber*)minShowInterval stringValue];
        }
        else if (![minShowInterval isKindOfClass:[NSString class]]){
            minShowInterval = nil;
        }
        
        NSString* oncePerVersionCondition;
        id oncePerVersion = getMessageKey(meta,@"oncePerVersion");
        {
            if ([oncePerVersion isKindOfClass:[NSNumber class]]){
                // do nothing
                oncePerVersionCondition = nil;
            }
            else if ([oncePerVersion isKindOfClass:[NSString class]]){
                oncePerVersionCondition = oncePerVersion;
                oncePerVersion = @(YES);
            }
            else {
                oncePerVersion = @(NO);
                oncePerVersionCondition = nil;
            }
        }
        
        NSString* oncePerInstallCondition;
        id oncePerInstall = getMessageKey(meta,@"oncePerInstall");
        {
            if ([oncePerInstall isKindOfClass:[NSNumber class]]){
                // do nothing
                oncePerInstallCondition = nil;
            }
            else if ([oncePerInstall isKindOfClass:[NSString class]]){
                oncePerInstallCondition = oncePerInstall;
                oncePerInstall = @(YES);
            }
            else {
                oncePerInstall = @(NO);
                oncePerInstallCondition = nil;
            }
        }
        
        NSMutableArray* s_removeAdsAction = [[getMessageKey(meta,@"removeAdsAction") componentsSeparatedByString:@"|"] mutableCopy];
        NSArray* urls = nil;
        NSMutableArray* s_urls = [getMessageKey(meta,@"urls") mutableCopy];
        NSMutableArray* seq = [NSMutableArray new];
        BOOL notOrdinarySequence = NO;
        
        NSMutableArray* indexesToRemove = [NSMutableArray new];
        
        for (NSUInteger i = 0; i < [s_urls count]; ++i){
            NSString* s = [s_urls objectAtIndex:i];
            NSArray* components = [s componentsSeparatedByString:@"|"];
            
            NSString* counterStr = nil;
            NSString* urlStr = nil;
            NSString* schemeStr = nil;
            
            for (NSString* com in components){
                if ([com hasPrefix:@"$"]){
                    schemeStr = [com substringFromIndex:1];
                }
                else if ([com hasPrefix:@"http://"] || [com hasPrefix:@"https://"]){
                    urlStr = com;
                }
                else if ([[com lowercaseString] isEqualToString:@"ignore"]){
                    urlStr = nil;
                    break;
                }
                else {
                    int k = [com intValue];
                    if ([[@(k) stringValue] isEqualToString:com]){
                        counterStr = com;
                    }
                }
            }
            
            if (!urlStr){
                [indexesToRemove addObject:@(i)];
                continue;
            }
            
            if (schemeStr){
                NSURL* url = [NSURL URLWithString:[schemeStr stringByAppendingString:@"://apple.com"]];
                if (url){
                    if ([[UIApplication sharedApplication] canOpenURL:url]){
                        [indexesToRemove addObject:@(i)];
                        continue;
                    }
                }
            }
            
            [s_urls replaceObjectAtIndex:i withObject:urlStr];
            
            if (!counterStr){
                [seq addObject:@(1)];
            }
            else{
                if ([counterStr isEqualToString:@"0"]){
                    [seq addObject:@(0)];
                    notOrdinarySequence = YES;
                }
                else if ([counterStr intValue] > 1){
                    const int val = MIN(MAX(1,[counterStr intValue]),32);
                    [seq addObject:@(val)];
                    notOrdinarySequence = YES;
                }
                else{
                    [seq addObject:@(1)];
                }
            }
        }
        
        while ([indexesToRemove count]){
            NSUInteger idx = [[indexesToRemove lastObject] unsignedIntegerValue];
            [indexesToRemove removeLastObject];
            [s_urls removeObjectAtIndex:idx];
            if (idx < [s_removeAdsAction count]){
                [s_removeAdsAction removeObjectAtIndex:idx];
            }
        }
        
        urls = [s_urls copy];
        
        NSMutableString* sequence = nil;
        if (notOrdinarySequence){
            sequence = [NSMutableString new];
            BOOL notEmpty = YES;
            while (notEmpty) {
                notEmpty = NO;
                for (NSUInteger i = 0; i < [seq count]; ++i){
                    if ([[seq objectAtIndex:i] intValue] > 0){
                        notEmpty = YES;
                        [seq replaceObjectAtIndex:i withObject:@([[seq objectAtIndex:i] intValue] - 1)];
                        if ([sequence length] > 0){
                            [sequence appendFormat:@"|%d",(int)i];
                        }
                        else{
                            [sequence appendFormat:@"%d",(int)i];
                        }
                    }
                }
            }
        }
        
        if (![uuid isKindOfClass:[NSString class]] || ![uuid length]){
            return NO;
        }
        
        uuid = [uuid stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([uuid length] == 0){
            return NO;
        }
        
        if (![urls isKindOfClass:[NSArray class]] || ([urls count] == 0) || ![urls sn_isStrings]){
            return NO;
        }
        
        if (dates && ![dates isKindOfClass:[NSArray class]]){
            return NO;
        }
        
        NSString* const rootUUID = uuid;
        
        NSMutableArray* processedDates = [[NSMutableArray alloc] initWithCapacity:[dates count]];
        
        for (NSDictionary* date in dates){
            
            if (![date isKindOfClass:[NSDictionary class]]){
                return NO;
            }
            
            NSString* uuid = [date iSmartNews_objectForKey:@"uuid"];
            
            if (uuid){
                if (![uuid isKindOfClass:[NSString class]]){
                    return NO;
                }
            }
            else {
                uuid = rootUUID;
            }
            
            NSString* periods = [date iSmartNews_objectForKey:@"templates"];
            if (periods)
            {
                if (![periods isKindOfClass:[NSString class]]){
                    return NO;
                }
                
                static NSRegularExpression* startEndRegex = nil;
                if (!startEndRegex){
                    startEndRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\((\\d\\d):(\\d\\d)\\)$" options:NSRegularExpressionCaseInsensitive error:NULL];
                    if (!startEndRegex){
                        return NO;
                    }
                }
                
                id start = [date iSmartNews_objectForKey:@"start"];
                if (start){
                    if (![start isKindOfClass:[NSString class]]){
                        return NO;
                    }
                    NSArray* matches = [startEndRegex matchesInString:(NSString*)start options:0 range:NSMakeRange(0, [(NSString*)start length])];
                    if ([matches count] != 1){
                        return NO;
                    }
                    NSTextCheckingResult* r = [matches firstObject];
                    const int h = [[start substringWithRange:[r rangeAtIndex:1]] intValue];
                    if (h < 0 || h > 23){
                        return NO;
                    }
                    const int m = [[start substringWithRange:[r rangeAtIndex:2]] intValue];
                    if (m < 0 || m > 59){
                        return NO;
                    }
                }
                
                id end = [date iSmartNews_objectForKey:@"end"];
                if (end){
                    if (![end isKindOfClass:[NSString class]]){
                        return NO;
                    }
                    NSArray* matches = [startEndRegex matchesInString:(NSString*)end options:0 range:NSMakeRange(0, [(NSString*)end length])];
                    if ([matches count] != 1){
                        return NO;
                    }
                    NSTextCheckingResult* r = [matches firstObject];
                    const int h = [[start substringWithRange:[r rangeAtIndex:1]] intValue];
                    if (h < 0 || h > 23){
                        return NO;
                    }
                    const int m = [[start substringWithRange:[r rangeAtIndex:2]] intValue];
                    if (m < 0 || m > 59){
                        return NO;
                    }
                }
                
                if (!start){
                    start = @"(00:00)";
                }
                if (!end){
                    end = @"(23:59)";
                }
                
                NSArray* p = [[periods lowercaseString] componentsSeparatedByString:@"|"];
                for (NSString* k in p)
                {
                    id const shownLimit = [date iSmartNews_objectForKey:@"shownlimit"];
                    
                    if ([k isEqualToString:@"weekdays"])
                    {
                        NSMutableDictionary* obj = [@{
                                                     @"uuid": [uuid stringByAppendingFormat:@"-weekdays-generated-%@-%@",start,end],
                                                     @"start": [@"MO" stringByAppendingString:start],
                                                     @"end": [@"FR" stringByAppendingString:end],
                                                     } mutableCopy];
                        if (shownLimit){
                            [obj setObject:shownLimit forKey:@"shownlimit"];
                        }
                        [processedDates addObject:[obj copy]];
                        continue;
                    }
                    else if ([k isEqualToString:@"weekend"])
                    {
                        NSMutableDictionary* obj = [@{
                                                      @"uuid": [uuid stringByAppendingFormat:@"-weekend-generated-%@-%@",start,end],
                                                      @"start": [@"SA" stringByAppendingString:start],
                                                      @"end": [@"SU" stringByAppendingString:end],
                                                      } mutableCopy];
                        if (shownLimit){
                            [obj setObject:shownLimit forKey:@"shownlimit"];
                        }
                        [processedDates addObject:[obj copy]];
                        continue;
                    }
                    else if ([k isEqualToString:@"each_day_of_weekdays"])
                    {
                        for (NSString* d in @[@"MO",@"TU",@"WE",@"TH",@"FR"])
                        {
                            NSMutableDictionary* obj = [@{
                                                          @"uuid": [uuid stringByAppendingFormat:@"-each_day_of_weekdays-generated-%@-%@-%@",d,start,end],
                                                          @"start":[d stringByAppendingString:start],
                                                          @"end": [d stringByAppendingString:end],
                                                          } mutableCopy];
                            if (shownLimit){
                                [obj setObject:shownLimit forKey:@"shownlimit"];
                            }
                            [processedDates addObject:[obj copy]];
                        }
                        continue;
                    }
                    else if ([k isEqualToString:@"each_day_of_weekend"])
                    {
                        for (NSString* d in @[@"SA",@"SU"])
                        {
                            NSMutableDictionary* obj = [@{
                                                          @"uuid": [uuid stringByAppendingFormat:@"-each_day_of_weekend-generated-%@-%@-%@",d,start,end],
                                                          @"start":[d stringByAppendingString:start],
                                                          @"end": [d stringByAppendingString:end],
                                                          } mutableCopy];
                            if (shownLimit){
                                [obj setObject:shownLimit forKey:@"shownlimit"];
                            }
                            [processedDates addObject:[obj copy]];
                        }
                        continue;
                    }
                    else if ([k isEqualToString:@"each_day"])
                    {
                        for (NSString* d in @[@"MO",@"TU",@"WE",@"TH",@"FR",@"SA",@"SU"])
                        {
                            NSMutableDictionary* obj = [@{
                                                          @"uuid": [uuid stringByAppendingFormat:@"-each_day-generated-%@-%@-%@",d,start,end],
                                                          @"start":[d stringByAppendingString:start],
                                                          @"end": [d stringByAppendingString:end],
                                                          } mutableCopy];
                            if (shownLimit){
                                [obj setObject:shownLimit forKey:@"shownlimit"];
                            }
                            [processedDates addObject:[obj copy]];
                        }
                        continue;
                    }
                    else
                    {
                        return NO;
                    }
                }
            }
            else
            {
                id start = [date iSmartNews_objectForKey:@"start"];
                if (![start isKindOfClass:[NSDate class]] && ![start isKindOfClass:[NSString class]]){
                    return NO;
                }
                id end = [date iSmartNews_objectForKey:@"end"];
                if (![end isKindOfClass:[NSDate class]] && ![end isKindOfClass:[NSString class]]){
                    return NO;
                }
                
                start = sn_preprocessDate(start);
                end   = sn_preprocessDate(end);
                
                if (!start || !end)
                    return NO;
                
                NSMutableDictionary* d = [date mutableCopy];
                [d setObject:uuid forKey:@"uuid"];
                
                [processedDates addObject:[d copy]];
            }
        }
        
        dates = [processedDates copy];
        
        if (start && ![start isKindOfClass:[NSDate class]]){
            return NO;
        }
        
        if (end && ![end isKindOfClass:[NSDate class]]){
            return NO;
        }
        
        if (start && end && ([start timeIntervalSinceDate:end] >= 0)){
            return NO;
        }
        
        NSString* removeAdsAction = [s_removeAdsAction componentsJoinedByString:@"|"];
        
        if (removeAdsAction && ![removeAdsAction isKindOfClass:[NSString class]]){
            return NO;
        }
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context];
        [fetchRequest setEntity:entity];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"uuid = %@",uuid]];
        
        NSError* error = nil;
        NSArray* items = [context executeFetchRequest:fetchRequest error:&error];
        if (error){
            return NO;
        }
        
//INFO: new SmartNewsItem
        SmartNewsItem *item = [items lastObject];
        if (!item)
        {
            item = [NSEntityDescription insertNewObjectForEntityForName:@"SmartNewsItem" inManagedObjectContext:context];
            if (!item)
            {
                return NO;
            }
            
            [item setValue:uuid forKey:@"uuid"];
        }
        
        if ([randomize isKindOfClass:[NSNumber class]])
        {
            [item setValue:@([randomize boolValue]) forKey:@"randomize"];
        }
        else
        {
            [item setValue:@(NO) forKey:@"randomize"];
        }
        
        //Set only if "urlFixed" are empty
        if ((item.urlFixed == nil) || ([item.urlFixed length] == 0))
        {
            BOOL setUrlFixed = NO;
            
            if      ( ([fixUrl isKindOfClass:[NSNumber class]]) && ([fixUrl boolValue])    )
                setUrlFixed = YES;
            else if ( ([fixUrl isKindOfClass:[NSString class]]) && ([fixUrl intValue] > 0) )
                setUrlFixed = YES;
            
            if (setUrlFixed)
                item.urlFixed = @"!!!";
        }
        
        [item setValue:oncePerVersion forKey:@"oncePerVersion"];
        [item setValue:oncePerVersionCondition forKey:@"oncePerVersionCondition"];
        
        [item setValue:oncePerInstall forKey:@"oncePerInstall"];
        [item setValue:oncePerInstallCondition forKey:@"oncePerInstallCondition"];
        
#pragma mark - Reset shownInVersion
        if (![[item oncePerVersion] boolValue]){
            [item setShownInVersion:nil];
            [item setShownInVersionCondition:nil];
        }
        
        if (![[item oncePerInstall] boolValue]){
            [item setOncePerInstallShown:@(NO)];
        }
        
        NSString* onShow = [meta iSmartNews_objectForKey:@"onShow"];
        if (![onShow isKindOfClass:[NSString class]]){
            onShow = nil;
        }
        
        [item setValue:onShow forKey:@"onShow"];
        
        
        NSNumber* showOnlyIfUpgrade = [meta iSmartNews_objectForKey:@"showOnlyIfUpgrade"];
        [item setValue:@([showOnlyIfUpgrade isKindOfClass:[NSNumber class]] ? [showOnlyIfUpgrade boolValue] : NO) forKey:@"showOnlyIfUpgrade"];
        
        
        // bids_show
        id bids_show = sn_preprocessConditionValue([meta iSmartNews_objectForKey:@"showIfApps"]);
        [item setValue:bids_show forKey:@"bids_show"];
        
        // bids_skip
        id bids_skip = sn_preprocessConditionValue([meta iSmartNews_objectForKey:@"skipIfApps"]);
        [item setValue:bids_skip forKey:@"bids_skip"];
        
        //cond_skip
        id cond_skip = sn_preprocessConditionValue([meta iSmartNews_objectForKey:@"skipIf"]);
        [item setValue:cond_skip forKey:@"cond_skip"];
        
        //cond_show
        id cond_show = sn_preprocessConditionValue([meta iSmartNews_objectForKey:@"showIf"]);
        [item setValue:cond_show forKey:@"cond_show"];
        
        //Style
        NSObject* style = [meta iSmartNews_objectForKey:@"style"];
        NSString* styleDescription = nil;
        
        NSError* styleError = nil;
        if ([style isKindOfClass:[NSString class]])
        {
            styleDescription = [(NSString*)style lowercaseString];
            styleDescription = sn_preprocessConditionValue(styleDescription);
            
            NSDictionary* styleParsed = [NSDictionary dictionaryFromFlatLine:styleDescription optionAliases:@"anim:animation_ind:indicator_bg:background"];
            styleDescription = [styleParsed flatLineRepresentation:&styleError];
        }
        else if ([style isKindOfClass:[NSDictionary class]])
        {
            styleDescription = [(NSDictionary*)style flatLineRepresentation:&styleError];
            styleDescription = [styleDescription lowercaseString];
        }
        
        if ((styleError != nil) && ([styleDescription length] == 0))
            styleDescription = @"";
        
        [item setValue:styleDescription forKey:@"style"];
        
        [item setValue:minShowInterval forKey:@"minShowInterval"];
        [item setValue:start forKey:@"start"];
        [item setValue:end forKey:@"end"];
        [item setValue:removeAdsAction forKey:@"removeAdsAction"];
        [item setValue:orientations forKey:@"orientations"];
        [item setValue:priority forKey:@"priority"];
        [item setValue:segment forKey:@"segment"];
        
        [item setValue:minDelay forKey:@"minDelay"];
        [item setValue:maxDelay forKey:@"maxDelay"];
        
        [item setValue:autoHideInterval forKey:@"autoHideInterval"];
        
        if ([queue isKindOfClass:[NSString class]]){
            [item setValue:queue forKey:@"queue"];
        }
        else {
            [item setValue:nil forKey:@"queue"];
        }
        
        BOOL sequenceChanged = NO;
        
        if (sequence){
            
            NSString* next = [sequence copy];
            NSString* prev = [item valueForKey:@"sequenceSrc"];
            
            [item setValue:next forKey:@"sequenceSrc"];
            
            if (!prev || ![next isEqualToString:prev]){
                [item setValue:next forKey:@"sequence"];
                [item setValue:@(0) forKey:@"urlIndex"];
                sequenceChanged = YES;
            }
        }
        else {
            
            NSString* prev = [item valueForKey:@"sequenceSrc"];
            if (prev){
                [item setValue:@(0) forKey:@"urlIndex"];
                [item setValue:nil forKey:@"sequenceSrc"];
                [item setValue:nil forKey:@"sequence"];
                sequenceChanged = YES;
            }
        }
        
        
#pragma mark - Make AlertView MEGAURLs
        // Prosprocessing
        NSMutableArray* postProcessedUrls = [NSMutableArray new];
        [urls enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSURLComponents* components = [NSURLComponents componentsWithString:obj];
            //AlertView
            if ([[components host] isEqualToString:smartNewsAlertDomain()])
            {
                NSString* path = [components path];
                NSDictionary* alertDescription = [meta objectForKey:path];
                if ([alertDescription isKindOfClass:[NSDictionary class]])
                {
                    NSMutableDictionary* message = [NSMutableDictionary new];
                    extractSmartNewsMessage(alertDescription,message);
                    
                    if ([message objectForKey:iSmartNewsMessageTextKey])
                    {
                        NSMutableString* query = [NSMutableString new];
                        
                        for (NSString* key in [message allKeys])
                        {
                            if ([query length] > 0)
                            {
                                [query appendFormat:@"&%@=%@",key,[[message objectForKey:key] sn_stringByAddingPercentEncodingForRFC3986]];
                            }
                            else
                            {
                                [query appendFormat:@"%@=%@",key,[[message objectForKey:key] sn_stringByAddingPercentEncodingForRFC3986]];
                            }
                        }
                        
                        [components setQuery:query];
                        [postProcessedUrls addObject:stringFromNSURLComponents(components)];
                    }
                }
                else
                {
                    __block BOOL ok = NO;
                    
                    [[[components query] componentsSeparatedByString:@"&"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        NSArray* p = [obj componentsSeparatedByString:@"="];
                        if ([p count] == 2){
                            if ([[p objectAtIndex:0] isEqualToString:iSmartNewsMessageTextKey]){
                                ok = YES;
                                *stop = YES;
                            }
                        }
                    }];
                    
                    if (ok){
                        [postProcessedUrls addObject:obj];
                    }
                }
            }
            else //WebView
            {
                [postProcessedUrls addObject:obj];
            }
        }];
        urls = [postProcessedUrls copy];
        
        BOOL urlsChanged = NO;
        NSString* newUrls = [urls sn_join:@"!!!"];
        if (![item valueForKey:@"urlsSrc"] || ![newUrls isEqualToString:[item valueForKey:@"urlsSrc"]]){
            [item setValue:newUrls forKey:@"urlsSrc"];
            [item setValue:newUrls forKey:@"urls"];
            [item setValue:@(0) forKey:@"urlIndex"];
            urlsChanged = YES;
        }
        
        if (sequenceChanged || urlsChanged){
            if ([randomize isKindOfClass:[NSNumber class]] && [randomize boolValue]){
                [item randomizeUrlsAndSequence];
            }
        }
        
        dates = [dates sortedArrayUsingComparator:^NSComparisonResult(id o1, id o2){
            return [[o1 objectForKey:@"uuid"] caseInsensitiveCompare:[o2 objectForKey:@"uuid"]];
        }];
        
        NSFetchRequest *rangesFetchRequest = [[NSFetchRequest alloc] init];
        [rangesFetchRequest setEntity:[NSEntityDescription entityForName:@"SmartNewsTimeRange" inManagedObjectContext:context]];
        [rangesFetchRequest setPredicate:[NSPredicate predicateWithFormat:@"item == %@",item]];
        [rangesFetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"uuid" ascending:YES]]];
        
        NSArray* existingRanges = [context executeFetchRequest:rangesFetchRequest error:&error];
        if (error){
            [context deleteObject:item];
            saveContext(serviceName);
            return NO;
        }
        
        NSInteger i = 0,j = 0;
        
        for (NSDictionary* date in dates){
            
            NSDate* start = sn_preprocessDate([date iSmartNews_objectForKey:@"start"]);
            NSDate* end   = sn_preprocessDate([date iSmartNews_objectForKey:@"end"]);
            
            if (j < [existingRanges count]){
                
                NSManagedObject* range = [existingRanges objectAtIndex:j];
                
                
                if ([[date iSmartNews_objectForKey:@"uuid"] isEqualToString:[range valueForKey:@"uuid"]]){
                    
                    if (![start isEqualToDate:[range valueForKey:@"start"]]
                        || ![end isEqualToDate:[range valueForKey:@"end"]])
                    {
                        [range setValue:start forKey:@"start"];
                        [range setValue:end forKey:@"end"];
                        [range setValue:@(0) forKey:@"shown"];
                        [range setValue:nil forKey:@"probability"];
                    }
                    
                    if ([date iSmartNews_objectForKey:@"shownlimit"]){
                        [range setValue:[date iSmartNews_objectForKey:@"shownlimit"] forKey:@"shownLimit"];
                    }
                    else{
                        [range setValue:@(INT_MAX) forKey:@"shownLimit"];
                    }
                    
                    ++j;
                }
            }
            else{
                
                NSManagedObject *range = [NSEntityDescription insertNewObjectForEntityForName:@"SmartNewsTimeRange" inManagedObjectContext:context];
                
                [range setValue:[date iSmartNews_objectForKey:@"uuid"] forKey:@"uuid"];
                [range setValue:start forKey:@"start"];
                [range setValue:end forKey:@"end"];
                [range setValue:nil forKey:@"probability"];
                
                [range setValue:@(0) forKey:@"shown"];
                [range setValue:item forKey:@"item"];
                
                if ([date objectForKey:@"shownlimit"]){
                    [range setValue:[date iSmartNews_objectForKey:@"shownlimit"] forKey:@"shownLimit"];
                }
                else{
                    [range setValue:@(INT_MAX) forKey:@"shownLimit"];
                }
            }
            ++i;
        }
        
        for ( ; j < [existingRanges count]; ++j) {
            [context deleteObject:[existingRanges objectAtIndex:j]];
        }
        
        if (![metaUuid containsObject:uuid])
            [metaUuid addObject:uuid];
        
        saveContext(serviceName);
        
        return NO;
    }]];
}

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES SmartNewsItem* sn_findMetaItem(NSString* serviceName, NSString* uuid){
    
    NSManagedObjectContext* context = managedObjectContext(serviceName);
    if (!context)
        return nil;
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"uuid == %@",uuid]];
    return [[context executeFetchRequest:fetchRequest error:NULL] lastObject];
}

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSManagedObject* sn_findMetaRangeItem(NSString* serviceName, NSManagedObject* meta, NSString* uuid){
    
    NSManagedObjectContext* context = managedObjectContext(serviceName);
    if (!context)
        return nil;
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"SmartNewsTimeRange" inManagedObjectContext:context]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"(item == %@) AND (uuid == %@)",meta,uuid]];
    return [[context executeFetchRequest:fetchRequest error:NULL] lastObject];
}

static int dateOfWeek(NSCalendar* calendar, NSDate* date){
    NSDateComponents* weekComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:date];
    const long a = (14 - [weekComponents month]) / 12;
    const long y = [weekComponents year] - a;
    const long m = [weekComponents month] + 12 * a - 2;
    long nowOfWeek = (7000 + ([weekComponents day] + y + y / 4 - y / 100 + y / 400 + (31 * m) / 12)) % 7;
    if (nowOfWeek == 0){
        nowOfWeek = 7;
    }
    return (int)nowOfWeek;
}

static BOOL canResetShownCounterWeek(NSCalendar* calendar, NSDate* date1, NSDate* date2){
    const int f1 = dateOfWeek(calendar,date1);
    const int f2 = dateOfWeek(calendar,date2);
    
    NSDate* d1 = [date1 dateByAddingTimeInterval:-(f1 - 1)*24*3600];
    NSDate* d2 = [date2 dateByAddingTimeInterval:-(f2 - 1)*24*3600];
    
    NSDateComponents* components1 = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:d1];
    NSDateComponents* components2 = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:d2];
    
    return (components1.year != components2.year) || (components1.month != components2.month) || (components1.day != components2.day);
}

static BOOL canResetShownCounterMonth(NSCalendar* calendar, NSDate* date1, NSDate* date2){
    NSDateComponents* components1 = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth fromDate:date1];
    NSDateComponents* components2 = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth fromDate:date2];
    return (components1.year != components2.year) || (components1.month != components2.month);
}

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSArray* sn_metaNews(NSString* serviceName, NSArray* events){
    
    
    NSManagedObjectContext* context = managedObjectContext(serviceName);
    if (!context)
        return nil;
    
    iSmartNewsLog(@"Searching metanews for events: %@", events);
    
    NSArray* attachedEvents = [events filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [(SmartNewsEvent*)evaluatedObject newsItem] != nil;
    }]];

    NSArray* globalEvents =  [events filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [(SmartNewsEvent*)evaluatedObject newsItem] == nil;
    }]];
    
    NSDate* now = [NSDate ism_date];
    NSCalendar* calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    NSDateComponents* monthComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:now];
    [monthComponents setYear:SMARTNEWS_PER_MONTH_YEAR];
    [monthComponents setMonth:SMARTNEWS_PER_CONST_MONTH];
    NSDate* monthDate = [calendar dateFromComponents:monthComponents];
    
    NSDateComponents* weekComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:now];
    
    const long a = (14 - [weekComponents month]) / 12;
    const long y = [weekComponents year] - a;
    const long m = [weekComponents month] + 12 * a - 2;
    long nowOfWeek = (7000 + ([weekComponents day] + y + y / 4 - y / 100 + y / 400 + (31 * m) / 12)) % 7;
    if (nowOfWeek == 0){
        nowOfWeek = 7;
    }
    
    [weekComponents setYear:SMARTNEWS_PER_WEEK_YEAR];
    [weekComponents setMonth:SMARTNEWS_PER_CONST_MONTH];
    [weekComponents setDay:nowOfWeek];
    NSDate* weekDate = [calendar dateFromComponents:weekComponents];
    
    NSFetchRequest *fetchRequestForRanges = [[NSFetchRequest alloc] init];
    [fetchRequestForRanges setEntity:[NSEntityDescription entityForName:@"SmartNewsTimeRange" inManagedObjectContext:context]];
    [fetchRequestForRanges setPredicate:[NSPredicate predicateWithFormat:@"( ((start <= %@) AND (%@ < end)) OR ((start <= %@) AND (%@ < end)) OR ((start <= %@) AND (%@ < end)) )",now,now,monthDate,monthDate,weekDate,weekDate]];
    NSArray* foundMetaRanges = [context executeFetchRequest:fetchRequestForRanges error:NULL];
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterFullStyle];
    [formatter setTimeStyle:NSDateFormatterFullStyle];
    
    foundMetaRanges = [foundMetaRanges filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary* bind){
        
        if ([obj valueForKey:@"probability"]){
            id start = [obj valueForKey:@"start"];
            if (start){
                if ( [[calendar components:NSCalendarUnitYear fromDate:start] year] == SMARTNEWS_PER_WEEK_YEAR){
                    NSDate* probability = [formatter dateFromString:[obj valueForKey:@"probability"]];
                    if (probability)
                    {
                        if (canResetShownCounterWeek(calendar,probability,now))
                        {
                            [obj setValue:@(0) forKey:@"shown"];
                            [obj setValue:nil forKey:@"probability"];
                        }
                    }
                }
                else if ( [[calendar components:NSCalendarUnitYear fromDate:start] year] == SMARTNEWS_PER_MONTH_YEAR){
                    NSDate* probability = [formatter dateFromString:[obj valueForKey:@"probability"]];
                    if (probability)
                    {
                        if (canResetShownCounterMonth(calendar,probability,now))
                        {
                            [obj setValue:@(0) forKey:@"shown"];
                            [obj setValue:nil forKey:@"probability"];
                        }
                    }
                }
            }
        }
        
        NSNumber* shown = [obj valueForKey:@"shown"];
        NSNumber* shownLimit = [obj valueForKey:@"shownLimit"];
        return [shown unsignedIntegerValue] < [shownLimit unsignedIntegerValue];
    }]];
    
    saveContext(serviceName);
    
    NSMutableDictionary* foundMetaNewsSet =[NSMutableDictionary new];
    
    if ([foundMetaRanges count] != 0){
        
        for (NSManagedObject* range in foundMetaRanges){
            NSManagedObject* item = [range valueForKey:@"item"];
            
            NSDate* start = [item valueForKey:@"start"];
            if (start && ([start timeIntervalSinceNow] > 0))
                continue;
            
            NSDate* end = [item valueForKey:@"end"];
            if (end && ([end timeIntervalSinceNow] <= 0))
                continue;
            
            if (![foundMetaNewsSet objectForKey:[item valueForKey:@"uuid"]]){
                [foundMetaNewsSet setObject:@{@"rangeUuid":[range valueForKey:@"uuid"],@"item":item}
                                     forKey:[item valueForKey:@"uuid"]];
            }
        }
    }
    
    NSFetchRequest *fetchRequestForNoRangesNews = [[NSFetchRequest alloc] init];
    [fetchRequestForNoRangesNews setEntity:[NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context]];
    NSDate* ism_date = [NSDate ism_date];
    
    [fetchRequestForNoRangesNews setPredicate:[NSPredicate predicateWithFormat:@"timeRanges.@count == 0 AND (start == nil OR start >= %@) AND (end == nil OR end < %@)",ism_date,ism_date]];
    
    NSArray* foundMetaNoRangesNews = [[context executeFetchRequest:fetchRequestForNoRangesNews error:NULL]
                                      filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        SmartNewsItem* item = evaluatedObject;
        
        if ([[item events] count] == 0){
            if ([globalEvents count] != 0){
                return YES;
            }
        }
        else {
            for (SmartNewsEvent* event in attachedEvents){
                if ([event newsItem] == item){
                    return YES;
                }
            }
        }
        
        return NO;
    }]];
    
    if ([foundMetaNewsSet count] == 0 && [foundMetaNoRangesNews count] == 0){
        return nil;
    }
    
    NSArray* foundMetaNews = [[foundMetaNewsSet allKeys] sortedArrayUsingComparator:^NSComparisonResult(id o1, id o2){
        return [o1 caseInsensitiveCompare:o2];
    }];
    
    NSMutableArray* output = [NSMutableArray new];
    
    NSMutableArray* allNews = [NSMutableArray new];
    [allNews addObjectsFromArray:foundMetaNoRangesNews];

    static const char metaItemUuidKey;
    
    for (NSString* metaItemUuid in foundMetaNews){
        NSManagedObject* metaItem = [[foundMetaNewsSet objectForKey:metaItemUuid] objectForKey:@"item"];
        
        NSString* urlsSrc = [metaItem valueForKey:@"urlsSrc"];
        if (!urlsSrc || [urlsSrc isEqualToString:@""]){
            continue;
        }
        
        objc_setAssociatedObject(metaItem, &metaItemUuidKey, metaItemUuid, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [allNews addObject:metaItem];
    }
    
    // filter by bids_show/skip
    __block NSArray* bids;
    
    allNews = [[allNews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary* b){
        
        if (![[iSmartNewsSegment sharedSegment] matches:[obj valueForKey:@"segment"]]){
            return NO;
        }

        if ([obj valueForKey:@"bids_show"] && ![[obj valueForKey:@"bids_show"] isEqualToString:@""]){
            NSArray* bids_show = [[obj valueForKey:@"bids_show"] componentsSeparatedByString:@"|"];
            
            if ([bids_show count] > 0){
                BOOL show = NO;
                for (NSString* bid in bids_show){
                    if (![bid isEqualToString:@""]){
                        
                        if (!bids){

                            bids = nil;
                            if (!bids){
                                return YES;
                            }
                        }
                        
                        if ([bids indexOfObject:bid] != NSNotFound){
                            show = YES;
                            break;
                        }
                    }
                }
                if (!show){
                    return NO;
                }
            }
        }
        
        if ([obj valueForKey:@"bids_skip"] && ![[obj valueForKey:@"bids_skip"] isEqualToString:@""]){
            NSArray* bids_skip = [[obj valueForKey:@"bids_skip"] componentsSeparatedByString:@"|"];
            
            if ([bids_skip count] > 0){
                BOOL skip = NO;
                for (NSString* bid in bids_skip){
                    if (![bid isEqualToString:@""]){
                        
                        if (!bids){
                            bids = nil;
                            if (!bids){
                                return YES;
                            }
                        }
                        
                        if ([bids indexOfObject:bid] != NSNotFound){
                            skip = YES;
                            break;
                        }
                    }
                }
                if (skip){
                    return NO;
                }
            }
        }
        
        return YES;
    }]] mutableCopy];
    
    
    for (NSManagedObject* metaItem in [allNews copy]){
        
        NSString* urlsSrc = [metaItem valueForKey:@"urlsSrc"];
        if (!urlsSrc || [urlsSrc isEqualToString:@""]){
            continue;
        }
        
        SmartNewsItem* item = (SmartNewsItem*)metaItem;
        if ([[item events] count] == 0){
            if ([globalEvents count] == 0){
                continue;
            }
        }
        else {
            BOOL eventAccepted = NO;
            for (SmartNewsEvent* event in attachedEvents){
                if ([item.events containsObject:event]){
                    eventAccepted = YES;
                    break;
                }
            }
            if (!eventAccepted){
                continue;
            }
        }
        
        if (![item checkMinShowInterval])
        {
            continue;
        }
        
        if (![item checkAllowedForVersion] || ![item checkAllowedForInstall])
        {
            continue;
        }
        
        if (![item checkAllowedForAnotherConditions])
        {
            continue;
        }
        
//INFO: make dictionary by newsitem
        
        NSMutableDictionary* message = [NSMutableDictionary new];
        
        NSString* url = [(SmartNewsItem*)metaItem getCurrentURLString];
        
        if (url == nil)
            continue;
        
        if ([metaItem valueForKey:@"minDelay"] && [metaItem valueForKey:@"maxDelay"]){
            [message setObject:[metaItem valueForKey:@"minDelay"] forKey:@"minDelay"];
            [message setObject:[metaItem valueForKey:@"maxDelay"] forKey:@"maxDelay"];
        }
        
        if ([metaItem valueForKey:@"priority"]){
            [message setObject:[metaItem valueForKey:@"priority"] forKey:@"priority"];
        }
        
        [message setObject:[metaItem valueForKey:@"uuid"] forKey:@"uuid"];
        
        id metaItemUuid = objc_getAssociatedObject(metaItem, &metaItemUuidKey);
        if (metaItemUuid != nil)
        {
            id rangeUuidValue = [[foundMetaNewsSet objectForKey:metaItemUuid] objectForKey:@"rangeUuid"];
            if (rangeUuidValue != nil)
            {
                [message setObject:rangeUuidValue forKey:@"rangeUuid"];
            }
        }
        
        NSNumber* autoHideInterval = [metaItem valueForKey:@"autoHideInterval"];
        if (autoHideInterval != nil)
        {
            [message setObject:autoHideInterval forKey:@"autoHideInterval"];
        }
        
        NSString* removeAdsAction = [metaItem valueForKey:@"removeAdsAction"];
        if ([removeAdsAction length])
            [message setObject:removeAdsAction forKey:@"removeAdsAction"];
        
        [message setObject:@(YES) forKey:@"skipCache"];
        
        NSString* onShow = [metaItem valueForKey:@"onShow"];
        if (onShow){
            [message setObject:onShow forKey:@"onShow"];
        }
        
        NSString* orientations = [metaItem valueForKey:@"orientations"];
        if (orientations){
            [message setObject:orientations forKey:@"orientations"];
        }
        
        NSString* style = [metaItem valueForKey:@"style"];
        if (style){
            NSDictionary* styleParsed = [NSDictionary dictionaryFromFlatLine:style optionAliases:nil];
            [message setObject:styleParsed forKey:iSmartNewsMessageStyleKey];
        }
        
        NSURLComponents* components = [NSURLComponents componentsWithString:url];
        if ([[components host] isEqualToString:smartNewsAlertDomain()])
        {
            NSMutableDictionary* params = [NSMutableDictionary new];
            
            [[[components query] componentsSeparatedByString:@"&"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSArray* p = [obj componentsSeparatedByString:@"="];
                if ([p count] >= 2){
                    [params setObject:[[[p subarrayWithRange:NSMakeRange(1, [p count] - 1)] componentsJoinedByString:@"="] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                               forKey:[p objectAtIndex:0]];
                }
            }];
            
            [message setObject:[params objectForKey:iSmartNewsMessageTextKey] forKey:iSmartNewsMessageTextKey];
            
            if ([params objectForKey:iSmartNewsMessageActionKey] && [params objectForKey:iSmartNewsMessageUrlKey]){
                [message setObject:[params objectForKey:iSmartNewsMessageActionKey] forKey:iSmartNewsMessageActionKey];
                [message setObject:[params objectForKey:iSmartNewsMessageUrlKey] forKey:iSmartNewsMessageUrlKey];
            }
            
            if ([params objectForKey:iSmartNewsMessageCancelKey]){
                [message setObject:[params objectForKey:iSmartNewsMessageCancelKey] forKey:iSmartNewsMessageCancelKey];
            }
            
            if ([params objectForKey:iSmartNewsMessageTitleKey]){
                [message setObject:[params objectForKey:iSmartNewsMessageTitleKey] forKey:iSmartNewsMessageTitleKey];
            }
            
            if ([params objectForKey:iSmartNewsMessageReviewKey]){
                [message setObject:[params objectForKey:iSmartNewsMessageReviewKey] forKey:iSmartNewsMessageReviewKey];
            }
            
            if ([params objectForKey:iSmartNewsMessageReviewTypeKey]){
                [message setObject:[params objectForKey:iSmartNewsMessageReviewTypeKey] forKey:iSmartNewsMessageReviewTypeKey];
            }
            
            if ([params objectForKey:iSmartNewsMessageRemindKey]){
                [message setObject:[params objectForKey:iSmartNewsMessageRemindKey] forKey:iSmartNewsMessageRemindKey];
            }
            
            if ([params objectForKey:iSmartNewsMessageUrlKey]){
                [message setObject:[params objectForKey:iSmartNewsMessageUrlKey] forKey:iSmartNewsMessageUrlKey];
            }
            
            //If no any button, then add cancel
            if (![message objectForKey:iSmartNewsMessageCancelKey]
                && ![message objectForKey:iSmartNewsMessageReviewKey]
                && ![message objectForKey:iSmartNewsMessageRemindKey]
                && ![message objectForKey:iSmartNewsMessageActionKey])
            {
                [message setObject:NSLocalizedString(@"Cancel",) forKey:iSmartNewsMessageCancelKey];
            }
        }
        //ReviewDomain - one of direct action items
        else if ([[components host] isEqualToString:smartNewsReviewDomain()])
        {
            [message setObject:url forKey:iSmartNewsMessageTextKey];
            [message setObject:iSmartNewsContentTypeDirectAction forKey:iSmartNewsMessageTypeKey];
        }
        else
        {
            [message setObject:url forKey:iSmartNewsMessageTextKey];
            [message setObject:iSmartNewsContentTypeWeb forKey:iSmartNewsMessageTypeKey];
        }
        
        NSString* queue = [metaItem valueForKey:@"queue"];
        if (queue && [queue isKindOfClass:[NSString class]] && [queue length])
        {
            queue = [queue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([queue length])
                [message setObject:queue forKey:iSmartNewsMessageQueueKey];
        }
        
        [output addObject:message];
    }
    
    __block NSString* onlySingleUuid;
    [output enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([[obj valueForKey:@"uuid"] isEqualToString:@"what_is_new"]){
            onlySingleUuid = @"what_is_new";
            *stop = YES;
            return;
        }
        
        if ([[obj valueForKey:@"uuid"] isEqualToString:@"review"]){
            onlySingleUuid = @"review";
        }
        
    }];
    
    if (onlySingleUuid)
    {
        [output filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return [[evaluatedObject valueForKey:@"uuid"] isEqualToString:onlySingleUuid];
        }]];
    }
    else
    {
        [output sortUsingComparator:^NSComparisonResult(id o1, id o2){

            if ([[o1 valueForKey:@"uuid"] isEqualToString:@"what_is_new"]){
                return NSOrderedAscending;
            }
            else if ([[o2 valueForKey:@"uuid"] isEqualToString:@"what_is_new"]){
                return NSOrderedDescending;
            }

            if ([[o1 valueForKey:@"uuid"] isEqualToString:@"review"]){
                return NSOrderedAscending;
            }
            else if ([[o2 valueForKey:@"uuid"] isEqualToString:@"review"]){
                return NSOrderedDescending;
            }
            
            if ([o1 valueForKey:@"priority"] && ![o2 valueForKey:@"priority"]){
                return NSOrderedAscending;
            }
            else if (![o1 valueForKey:@"priority"] && [o2 valueForKey:@"priority"]){
                return NSOrderedDescending;
            }
            else if ([o1 valueForKey:@"priority"] && [o2 valueForKey:@"priority"]){
                const NSComparisonResult r = [[o1 valueForKey:@"priority"] compare:[o2 valueForKey:@"priority"]];
                if (r != NSOrderedSame){
                    return -r;// higher priority to top
                }
            }
            
            return [[o1 valueForKey:@"uuid"] caseInsensitiveCompare:[o2 valueForKey:@"uuid"]];
        }];
        
        // Select randomly only one
        if ([output count] > 1){
            
            NSMutableSet* eventsNames = [NSMutableSet setWithCapacity:[events count]];
            [events enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString* name = [(SmartNewsEvent*)obj name];
                if (![eventsNames containsObject:name]){
                    [eventsNames addObject:name];
                }
            }];
            
            if ([eventsNames count] > 1){
                const u_int32_t happyIndex = arc4random_uniform((uint32_t)[output count]);
                return [output subarrayWithRange:NSMakeRange(happyIndex, 1)];
            }
            else if ([eventsNames count] == 1) {
                
                if (!g_sn_eventShownNews){
                    g_sn_eventShownNews = [NSMutableDictionary dictionaryWithCapacity:10];
                }
                
                NSMutableDictionary* serviceShownEvents = [g_sn_eventShownNews objectForKey:serviceName];
                if (!serviceShownEvents){
                    serviceShownEvents = [NSMutableDictionary dictionaryWithCapacity:10];
                    [g_sn_eventShownNews setObject:serviceShownEvents forKey:serviceName];
                }
                
                NSString* eventName = [eventsNames anyObject];
                NSMutableArray* sequence = [serviceShownEvents objectForKey:eventName];
                if (!sequence){
                    sequence = [NSMutableArray new];
                    [serviceShownEvents setObject:sequence forKey:eventName];
                }
                
                do
                {
                    NSArray* remained = [output filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                        NSString* uuid = [evaluatedObject valueForKey:@"uuid"];
                        return [sequence indexOfObject:uuid] == NSNotFound;
                    }]];
                    
                    if ([remained count] == 0){
                        [sequence removeAllObjects];
                        continue;
                    }
                    
                    [sequence addObject:[[remained firstObject] valueForKey:@"uuid"]];
                    return [remained subarrayWithRange:NSMakeRange(0, 1)];
                    
                } while (YES);
            }
        }
    }
    
    return [output copy];
}

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
