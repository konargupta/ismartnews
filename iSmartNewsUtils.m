//
//  iSmartNewsUtils.m
//  iSmartNewsDemo
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsUtils.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/utsname.h>

#import <zlib.h>

#import <JavaScriptCore/JavaScriptCore.h>

#import "iSmartNewsInternal.h"

#import <errno.h>

#if SMARTNEWS_COMPILE
EXTERN_OR_STATIC INLINE_INTERNAL_ATTRIBUTES void sn_swizzleInstanceMethod(Class class, SEL old, SEL newSelector); //Used in UIScrollView(ex)
#endif

static char UIScrollViewExSettingsKey = 0;

@implementation UIScrollView(ex)

-(NSMutableDictionary*) _ex_settingsMake:(BOOL) make
{
    NSMutableDictionary* _ex_settings = objc_getAssociatedObject(self, &UIScrollViewExSettingsKey);
    
    if ((make == YES) && (_ex_settings == nil))
    {
        _ex_settings = [NSMutableDictionary new];
        objc_setAssociatedObject(self, &UIScrollViewExSettingsKey, _ex_settings, OBJC_ASSOCIATION_RETAIN);
    }
    
    return _ex_settings;
}

-(BOOL)horizontalScrollDisable
{
    return [[[self _ex_settingsMake:NO] objectForKey:@"horizontalScrollDisable"] boolValue];
}

-(void)setHorizontalScrollDisable:(BOOL)horizontalScrollDisable
{
    [[self _ex_settingsMake:horizontalScrollDisable] setObject:@(horizontalScrollDisable) forKey:@"horizontalScrollDisable"];
}

-(BOOL)verticalScrollDisable
{
    return [[[self _ex_settingsMake:NO] objectForKey:@"verticalScrollDisable"] boolValue];
}

-(void)setVerticalScrollDisable:(BOOL)verticalScrollDisable
{
    [[self _ex_settingsMake:verticalScrollDisable] setObject:@(verticalScrollDisable) forKey:@"verticalScrollDisable"];
}

-(void)_ex_setContentOffset:(CGPoint)contentOffset
{
    NSDictionary* _ex_settings = [self _ex_settingsMake:NO];
    
    if (_ex_settings)
    {
        if ([[_ex_settings objectForKey:@"verticalScrollDisable"] boolValue])
        {
            contentOffset.y = 0;
        }
    
        if ([[_ex_settings objectForKey:@"horizontalScrollDisable"] boolValue])
        {
            contentOffset.x = 0;
        }
    }
    
    [self _ex_setContentOffset:contentOffset];
}

+(void)load
{
    sn_swizzleInstanceMethod(self,@selector(setContentOffset:),@selector(_ex_setContentOffset:));
}
@end

@implementation NSArray(SmartNews)
- (BOOL)sn_isStrings{
    for (NSString* s in self){
        if (![s isKindOfClass:[NSString class]]){
            return NO;
        }
    }
    return YES;
}
- (BOOL)sn_isDates{
    for (NSString* s in self){
        if (![s isKindOfClass:[NSDate class]]){
            return NO;
        }
    }
    return YES;
}
- (NSString*)sn_join:(NSString*)sep{
    NSMutableString* tmp = [NSMutableString string];
    for (NSString* s in self){
        if ([tmp length]){
            [tmp appendString:sep];
        }
        [tmp appendString:s];
    }
    return [tmp copy];
}
@end

static NSString* mk_lang    = nil;
static NSString* mk_country = nil;

static NSString* mk_deviceModel = nil;
static NSString* mk_simpleDeviceModel = nil;
static NSString* mk_screenSize = nil;


EXTERN_OR_STATIC INTERNAL_ATTRIBUTES BOOL sn_allowUpdate()
{
    return YES;
}

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES void sn_cleanMessageKeysCache(){
    mk_lang = nil;
    mk_country = nil;
}

NSString* smartNewsAlertDomain()
{
    return @"alertview.io";
}

NSString* smartNewsReviewDomain()
{
    return @"review.io";
}

NSSet* sn_protectedItems(){
    NSRegularExpression *subscribe_regex = [NSRegularExpression regularExpressionWithPattern:@"^subscribe[_.*]?$"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:NULL];
    assert(subscribe_regex);
    return [NSSet setWithObjects:@"review", @"what_is_new", subscribe_regex, nil];
}

void extractSmartNewsMessage(NSDictionary* desc, NSMutableDictionary* message)
{
    NSDate* startDate = (NSDate*)getMessageKey(desc,@"start");
    NSDate* endDate = (NSDate*)getMessageKey(desc,@"end");
    NSString* title = (NSString*)getMessageKey(desc,@"title");
    NSString* text = (NSString*)getMessageKey(desc,@"text");
    NSString* link = (NSString*)getMessageKey(desc,@"link");
    NSString* cancel = (NSString*)getMessageKey(desc,@"cancel");
    NSString* ok = (NSString*)getMessageKey(desc,@"ok");
    NSString* review = (NSString*)getMessageKey(desc,@"review");
    NSString* remind = (NSString*)getMessageKey(desc,@"remind");
    NSNumber* once = (NSNumber*)getMessageKey(desc,@"repeat");
    NSNumber* always = (NSNumber*)getMessageKey(desc,@"always");
    NSString* messageType = (NSString*)getMessageKey(desc, @"type");
    NSNumber* allowAllIphoneOrientations = (NSNumber*)getMessageKey(desc, @"allowAllIphoneOrientations");
    
    NSString* reviewType = (NSString*)getMessageKey(desc,@"review_type");
    
    NSDictionary* style = (NSString*)getMessageKey(desc, @"style");
    
    if ([allowAllIphoneOrientations isKindOfClass:[NSNumber class]]){
        [message setObject:allowAllIphoneOrientations forKey:@"allowAllIphoneOrientations"];
    }
    
    if (startDate && [startDate isKindOfClass:[NSDate class]])
        [message setObject:startDate forKey:iSmartNewsMessageStartDateKey];
    
    if (endDate && [endDate isKindOfClass:[NSDate class]])
        [message setObject:endDate forKey:iSmartNewsMessageEndDateKey];
    
    if (title && [title isKindOfClass:[NSString class]])
        [message setObject:title forKey:iSmartNewsMessageTitleKey];
    
    if (text && [text isKindOfClass:[NSString class]])
        [message setObject:text forKey:iSmartNewsMessageTextKey];
    
    if (link && [link isKindOfClass:[NSString class]])
        [message setObject:link forKey:iSmartNewsMessageUrlKey];
    
    if (cancel && [cancel isKindOfClass:[NSString class]])
        [message setObject:cancel forKey:iSmartNewsMessageCancelKey];
    
    if (ok && [ok isKindOfClass:[NSString class]])
        [message setObject:ok forKey:iSmartNewsMessageActionKey];
    
    if (remind && [remind isKindOfClass:[NSString class]])
        [message setObject:remind forKey:iSmartNewsMessageRemindKey];
    
    if (review && [review isKindOfClass:[NSString class]])
        [message setObject:review forKey:iSmartNewsMessageReviewKey];
    
    if (once && [once isKindOfClass:[NSNumber class]])
        [message setObject:once forKey:iSmartNewsMessageRepeatKey];
    
    if (always && [always isKindOfClass:[NSNumber class]])
        [message setObject:always forKey:iSmartNewsMessageAlwaysKey];
    
    if (messageType && [messageType isKindOfClass:[NSString class]])
        [message setObject:messageType forKey:iSmartNewsMessageTypeKey];
    
    if (style && [style isKindOfClass:[NSDictionary class]])
        [message setObject:style forKey:iSmartNewsMessageStyleKey];
    
    // Fill text if title was set
    if (![message objectForKey:iSmartNewsMessageTextKey] && [message objectForKey:iSmartNewsMessageTitleKey])
    {
        [message setObject:@"" forKey:iSmartNewsMessageTextKey];
    }
    
    if (reviewType && [reviewType isKindOfClass:[NSString class]])
        [message setObject:reviewType forKey:iSmartNewsMessageReviewTypeKey];
    
    // -- since version 1.4
    NSString* queue = (NSString*)getMessageKey(desc,@"queue");
    if (queue && [queue isKindOfClass:[NSString class]])
    {
        queue = [queue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([queue length])
            [message setObject:queue forKey:iSmartNewsMessageQueueKey];
    }
    // --
}

void clearNewsLang()
{
    mk_country = nil;
    mk_lang = nil;
}

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSString* firstApplicableOSVersionConditionFromKeys(NSArray* keys, NSString* customOSV)
{
    NSString* firstApplicableOSVersionConditionFromExistingKeys = nil;
    //iOS version filtration:
    //Equal or More - IOS+10, IOS+10.3, IOS+7.1.3
    //Equal         - IOS=10, IOS10
    //Less          - IOS-8
    
    for (NSString* key in keys)
    {
        if ([key rangeOfString:@"IOS" options:NSCaseInsensitiveSearch].location == NSNotFound)
            continue;
        
        NSRange range = [key rangeOfString:@"[Ii][Oo][Ss][=\\+-]{0,1}[\\d\\.]+" options:NSRegularExpressionSearch];
        if (range.location != NSNotFound)
        {
            NSString* currentOSCondition = [key substringWithRange:range];
            
            unichar conditionChar = [currentOSCondition characterAtIndex:3];
            if ((conditionChar != '=') && (conditionChar != '-') && (conditionChar != '+'))
            {
                currentOSCondition = [currentOSCondition stringByReplacingCharactersInRange:NSMakeRange(3, 0) withString:@"="];
                conditionChar = '=';
            }
            
#if !(DEBUG || ADHOC)
            static
#endif
            NSArray* systemVersionComponents = nil;
            
            if (systemVersionComponents == nil)
            {
#if DEBUG || ADHOC
                if (customOSV == nil)
#endif
                {
                    customOSV = [[UIDevice currentDevice] systemVersion];
                }
                
                systemVersionComponents = [customOSV componentsSeparatedByString:@"."];
            }
            
            NSString* needVersion = [currentOSCondition substringFromIndex:4];
            NSArray* needVersionComponents = [needVersion componentsSeparatedByString:@"."];
            
            @try
            {
                BOOL applicable = YES;
                for ( NSInteger i = 0;
                     (i < [needVersionComponents count]) && applicable;
                     i++)
                {
                    NSInteger needVC    = [[needVersionComponents objectAtIndex:i] integerValue];
                    NSInteger currentVC = ([systemVersionComponents count] > i) ? ([[systemVersionComponents objectAtIndex:i] integerValue]) : 0;
                    
                    if (conditionChar == '=')
                    {
                        applicable = applicable && (currentVC == needVC);
                    }
                    else if (conditionChar == '+')
                    {
                        if (currentVC > needVC)
                            break;
                        
                        applicable = applicable && (currentVC >= needVC);
                    }
                    else if (conditionChar == '-')
                    {
                        if (currentVC < needVC)
                            break;
                        
                        //If last component - more strong condition
                        if (i == ([needVersionComponents count] - 1))
                        {
                            applicable = applicable && (currentVC < needVC);
                        }
                        else
                        {
                            applicable = applicable && (currentVC <= needVC);
                        }
                    }
                }
                
                if (applicable)
                    firstApplicableOSVersionConditionFromExistingKeys = currentOSCondition;
            }
            @catch(NSException* e)
            {
                firstApplicableOSVersionConditionFromExistingKeys = nil;
            }
            
            if ([firstApplicableOSVersionConditionFromExistingKeys length] > 0)
                break;
        }
    }
    
    return firstApplicableOSVersionConditionFromExistingKeys;
}

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSString* firstApplicableKey(NSArray* availableKeys, NSString* prefix)
{
    NSString* applicableOSVersionCondition = firstApplicableOSVersionConditionFromKeys(availableKeys, nil);
    
    if ([applicableOSVersionCondition length] > 0)
    {
        NSString* key = [prefix stringByAppendingFormat:@"_%@", applicableOSVersionCondition];
        
        if ([availableKeys indexOfObject:key] != NSNotFound)
            return key;
    }
    
    return nil;
}

/*! @internal */
id getMessageKey(NSDictionary* _dict, NSString* _key)
{
    if (_dict == nil)
        return nil;
    
    assert(_key != nil);
    
    _key = [_key lowercaseString];
    
    if (!mk_lang){
        NSArray*  preferredLanguages   = [NSLocale preferredLanguages];
        mk_lang    = [preferredLanguages count] ? [[preferredLanguages objectAtIndex:0] lowercaseString] : [[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] lowercaseString];
        NSArray* components = [mk_lang componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_-"]];
        if ([components count] >= 2){
            if ([[components objectAtIndex:0] isEqualToString:@"zh"]
                && ([[components objectAtIndex:1] isEqualToString:@"hans"] || [[components objectAtIndex:1] isEqualToString:@"hant"])){
                mk_lang = [[components objectAtIndex:0] stringByAppendingFormat:@"_%@",[components objectAtIndex:1]];
            }
            else {
                mk_lang = [components objectAtIndex:0];// special fix for iOS9, sometimes it return language + country: ru_BY
            }
        }
        else{
            mk_lang = [components objectAtIndex:0];// special fix for iOS9, sometimes it return language + country: ru_BY
        }
    }
    
    if (!mk_country){
        mk_country = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
        mk_country = [mk_country lowercaseString];
        iSmartNewsLog(@"lang = %@, country = %@",mk_lang,mk_country);
    }
    
    if (!mk_deviceModel)
    {
        struct utsname systemInfo;
        memset(&systemInfo, 0, sizeof(systemInfo));
        uname(&systemInfo);
        mk_deviceModel = [[NSString stringWithCString:systemInfo.machine
                                          encoding:NSUTF8StringEncoding] lowercaseString];
    }
    
    
    if (!mk_simpleDeviceModel){
        mk_simpleDeviceModel = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"ipad" : @"iphone";
    }
    

    if (!mk_screenSize){
        
        if ([mk_deviceModel isEqualToString:@"ipad6,8"]){ // hack
            mk_screenSize = @"2048x2732";
        }
        else {
            const CGRect bounds = [[UIScreen mainScreen] bounds];
            const CGFloat scale = [[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f;
            const int w = MIN((int)(scale * bounds.size.width),(int)(bounds.size.height * scale));
            const int h = MAX((int)(scale * bounds.size.width),(int)(bounds.size.height * scale));
            
            mk_screenSize = [NSString stringWithFormat:@"%dx%d",w,h];
        }
    }
    
    NSObject* retVal = nil;
    
#define KEYS_WITH_PREFIX(PREFIX) [[_dict allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", (PREFIX)]]
    
    //NSArray* keyCandidats = [[_dict allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", _key]];
    //NSString* mk_osversion = firstApplicableOSVersionConditionFromKeys(keyCandidats, nil);
    
    // try to get variant for full locale + size
    if (mk_deviceModel && !retVal)
        retVal = [_dict objectForKey:[_key stringByAppendingFormat:@"_%@_%@_%@",mk_lang,mk_country,mk_deviceModel]];
    
    if (mk_simpleDeviceModel && !retVal)
        retVal = [_dict objectForKey:[_key stringByAppendingFormat:@"_%@_%@_%@",mk_lang,mk_country,mk_simpleDeviceModel]];
    
    // try to get variant for full locale + size
    if (!retVal)
        retVal = [_dict objectForKey:[_key stringByAppendingFormat:@"_%@_%@_%@",mk_lang,mk_country,mk_screenSize]];
    
    // try to get variant for full locale
    if (!retVal)
        retVal = [_dict objectForKey:[_key stringByAppendingFormat:@"_%@_%@",mk_lang,mk_country]];
    
    
    
    if (mk_deviceModel && !retVal)
    {
        NSString* keyPrefix     = [_key stringByAppendingFormat:@"_%@_%@",mk_lang,mk_deviceModel];
        NSArray*  availableKeys = KEYS_WITH_PREFIX(keyPrefix);
        if ([availableKeys count] > 0)
        {
            NSString* key2 = firstApplicableKey(availableKeys, keyPrefix);
            retVal = [_dict objectForKey:(key2!=nil)?(key2):(keyPrefix)];
        }
    }
    
    if (mk_simpleDeviceModel && !retVal)
    {
        NSString* keyPrefix     = [_key stringByAppendingFormat:@"_%@_%@",mk_lang,mk_simpleDeviceModel];
        NSArray*  availableKeys = KEYS_WITH_PREFIX(keyPrefix);
        if ([availableKeys count] > 0)
        {
            NSString* key2 = firstApplicableKey(availableKeys, keyPrefix);
            retVal = [_dict objectForKey:(key2!=nil)?(key2):(keyPrefix)];
        }
    }
    
    // try to get variant for language + size
    if (!retVal)
    {
        NSString* keyPrefix     = [_key stringByAppendingFormat:@"_%@_%@",mk_lang,mk_screenSize];
        NSArray*  availableKeys = KEYS_WITH_PREFIX(keyPrefix);
        if ([availableKeys count] > 0)
        {
            NSString* key2 = firstApplicableKey(availableKeys, keyPrefix);
            retVal = [_dict objectForKey:(key2!=nil)?(key2):(keyPrefix)];
        }
    }
    
    // try to get variant for language
    if (!retVal)
    {
        NSString* keyPrefix     = [_key stringByAppendingFormat:@"_%@",mk_lang];
        NSArray*  availableKeys = KEYS_WITH_PREFIX(keyPrefix);
        if ([availableKeys count] > 0)
        {
            NSString* key2 = firstApplicableKey(availableKeys, keyPrefix);
            retVal = [_dict objectForKey:(key2!=nil)?(key2):(keyPrefix)];
        }
    }
    
    if (mk_deviceModel && !retVal)
    {
        NSString* keyPrefix     = [_key stringByAppendingFormat:@"_%@",mk_deviceModel];
        NSArray*  availableKeys = KEYS_WITH_PREFIX(keyPrefix);
        if ([availableKeys count] > 0)
        {
            NSString* key2 = firstApplicableKey(availableKeys, keyPrefix);
            retVal = [_dict objectForKey:(key2!=nil)?(key2):(keyPrefix)];
        }
    }
    
    if (mk_simpleDeviceModel && !retVal)
    {
        NSString* keyPrefix     = [_key stringByAppendingFormat:@"_%@",mk_simpleDeviceModel];
        NSArray*  availableKeys = KEYS_WITH_PREFIX(keyPrefix);
        if ([availableKeys count] > 0)
        {
            NSString* key2 = firstApplicableKey(availableKeys, keyPrefix);
            retVal = [_dict objectForKey:(key2!=nil)?(key2):(keyPrefix)];
        }
    }
    
    // try to get variant for size
    if (!retVal)
    {
        NSString* keyPrefix     = [_key stringByAppendingFormat:@"_%@",mk_screenSize];
        NSArray*  availableKeys = KEYS_WITH_PREFIX(keyPrefix);
        if ([availableKeys count] > 0)
        {
            NSString* key2 = firstApplicableKey(availableKeys, keyPrefix);
            retVal = [_dict objectForKey:(key2!=nil)?(key2):(keyPrefix)];
        }
    }
    
    //Only for iOS version
    if (!retVal)
    {
        NSString* keyPrefix     = _key;
        NSArray*  availableKeys = KEYS_WITH_PREFIX([keyPrefix stringByAppendingString:@"_"]); //Special for exclude keys without suffix
        if ([availableKeys count] > 0)
        {
            NSString* key2 = firstApplicableKey(availableKeys, keyPrefix);
            retVal = [_dict objectForKey:(key2!=nil)?(key2):(keyPrefix)];
        }
    }
    
    // peek default
    if (!retVal)
        retVal = [_dict objectForKey:_key];
    
    return retVal;
}

/*! @internal */
EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSString* sn_md5ForArray(NSArray* _array)
{
    CC_MD5_CTX  ctx;
    CC_MD5_Init(&ctx);
    
    for (NSString* value in _array)
    {
        const void* data = 0;
        int         len  = 0;
        
        if ([value isKindOfClass:[NSString class]])
        {
            data = [(NSString*)value UTF8String];
            len  = (int)strlen((const  char*)data);
        }
        else if ([value isKindOfClass:[NSDate class]])
        {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
            [dateFormatter setDateStyle:NSDateFormatterFullStyle];
            NSString* date = [dateFormatter stringFromDate:(NSDate*)value];
            data = [date UTF8String];
            len  = (int)strlen((const  char*)data);
        }
        else if ([value isKindOfClass:[NSNumber class]])
        {
            NSString* s = [(NSNumber*)value stringValue];
            data = [s UTF8String];
            len  = (int)strlen((const  char*)data);
        }
        
        CC_MD5_Update(&ctx,data,len);
    }
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    memset(digest, 0, sizeof(digest));
    CC_MD5_Final(digest, &ctx);
    
    return [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            digest[0],  digest[1],
            digest[2],  digest[3],
            digest[4],  digest[5],
            digest[6],  digest[7],
            digest[8],  digest[9],
            digest[10], digest[11],
            digest[12], digest[13],
            digest[14], digest[15]];
}

/*! @internal */
EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSString* sn_md5ForDictionary(NSDictionary* _dict)
{
    CC_MD5_CTX  ctx;
    CC_MD5_Init(&ctx);
    
    for (NSString* k in [_dict allKeys])
    {
        {
            const void* data = [k UTF8String];
            int         len  = (int)strlen((const  char*)data);
            CC_MD5_Update(&ctx,data,len);
        }
        
        {
            const void* data = 0;
            int         len  = 0;
            
            NSObject* value = [_dict objectForKey:k];
            
            if ([value isKindOfClass:[NSString class]])
            {
                data = [(NSString*)value UTF8String];
                len  = (int)strlen((const  char*)data);
            }
            else if ([value isKindOfClass:[NSDate class]])
            {
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
                [dateFormatter setDateStyle:NSDateFormatterFullStyle];
                NSString* date = [dateFormatter stringFromDate:(NSDate*)value];
                data = [date UTF8String];
                len  = (int)strlen((const  char*)data);
            }
            else if ([value isKindOfClass:[NSNumber class]])
            {
                NSString* s = [(NSNumber*)value stringValue];
                data = [s UTF8String];
                len  = (int)strlen((const  char*)data);
            }
            
            CC_MD5_Update(&ctx,data,len);
        }
    }
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &ctx);
    
    return [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            digest[0],  digest[1],
            digest[2],  digest[3],
            digest[4],  digest[5],
            digest[6],  digest[7],
            digest[8],  digest[9],
            digest[10], digest[11],
            digest[12], digest[13],
            digest[14], digest[15]];
}

EXTERN_OR_STATIC INLINE_INTERNAL_ATTRIBUTES void sn_swizzleInstanceMethod(Class class, SEL old, SEL newSelector)
{
    Method oldMethod = class_getInstanceMethod(class, old);
    Method newMethod = class_getInstanceMethod(class, newSelector);
    
    if(class_addMethod(class, old, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
    {
        class_replaceMethod(class, newSelector, method_getImplementation(oldMethod), method_getTypeEncoding(oldMethod));
    }
    else
    {
        method_exchangeImplementations(oldMethod, newMethod);
    }
}

 NSString* RemoveAdsString(){
    
    NSString* lang = nil;
    {
        NSArray*  preferredLanguages   = [NSLocale preferredLanguages];
        lang    = [preferredLanguages count] ? [preferredLanguages objectAtIndex:0] : [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
        lang = [[[[lang stringByReplacingOccurrencesOfString:@"-" withString:@"_"] componentsSeparatedByString:@"_"] firstObject] uppercaseString];
    }
    
    if ([lang isEqualToString:@"IT"]) return @"Rimuovi pubblicità";
    if ([lang isEqualToString:@"ZH"]) return @"移除廣告";
    if ([lang isEqualToString:@"NL"]) return @"Verwijder reclame";
    if ([lang isEqualToString:@"JA"]) return @"広告削除";
    if ([lang isEqualToString:@"SV"]) return @"Ta bort reklam";
    if ([lang isEqualToString:@"ES"]) return @"Quitar anuncios";
    if ([lang isEqualToString:@"KO"]) return @"광고 제거";
    if ([lang isEqualToString:@"DE"]) return @"Werbung entfernen";
    if ([lang isEqualToString:@"FR"]) return @"Supprimer les pubs";
    if ([lang isEqualToString:@"PT"]) return @"Remover Anúncios";
    if ([lang isEqualToString:@"RU"]) return @"Убрать рекламу";
    if ([lang isEqualToString:@"AR"]) return @"إزالة الإعلانات";
    return @"Remove ADs";
}

@implementation UIView (iSmartNewsFindFirstResponder)
- (id)iSmartNewsFindFirstResponder_findFirstResponder
{
    if (self.isFirstResponder) {
        return self;
    }
    for (UIView *subView in self.subviews) {
        id responder = [subView iSmartNewsFindFirstResponder_findFirstResponder];
        if (responder) return responder;
    }
    return nil;
}
@end


@implementation NSDate(iSmartNews)

- (NSUInteger)iSmartNews_calendarIntervalSinceDate:(NSDate*)sinceDate
{
    if (sinceDate == nil)
        return 0;
    
    NSCalendar* currentCalendar = [NSCalendar currentCalendar];
    
    const NSCalendarUnit units = NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay;
    
    NSDateComponents* selfComponents = [currentCalendar components:units fromDate:self];
    NSDateComponents* sinceComponents = [currentCalendar components:units fromDate:sinceDate];
    
    selfComponents.hour = 0;
    selfComponents.minute = 0;
    selfComponents.second = 0;
    
    sinceComponents.hour = 0;
    sinceComponents.minute = 0;
    sinceComponents.second = 0;
    
#if DEBUG
    static BOOL onceToken = NO;
    if (!onceToken)
    {
        onceToken = YES;
        
        {
            NSDateComponents* components1 = [[NSDateComponents alloc] init];
            
            components1.year = 2000;
            components1.month = 1;
            components1.day = 1;
            components1.hour = 10;
            components1.minute = 10;
            components1.second = 10;
            
            NSDateComponents* components2 = [[NSDateComponents alloc] init];
            
            components2.year = 2000;
            components2.month = 1;
            components2.day = 2;
            components2.hour = 10;
            components2.minute = 10;
            components2.second = 10;
            
            assert([[[NSCalendar currentCalendar] dateFromComponents:components1] iSmartNews_calendarIntervalSinceDate:[[NSCalendar currentCalendar] dateFromComponents:components2]] == 1);
            
        }
        
        {
            NSDateComponents* components1 = [[NSDateComponents alloc] init];
            
            components1.year = 2000;
            components1.month = 1;
            components1.day = 30;
            components1.hour = 10;
            components1.minute = 10;
            components1.second = 10;
            
            NSDateComponents* components2 = [[NSDateComponents alloc] init];
            
            components2.year = 2000;
            components2.month = 2;
            components2.day = 1;
            components2.hour = 10;
            components2.minute = 10;
            components2.second = 10;
            
            assert([[[NSCalendar currentCalendar] dateFromComponents:components1] iSmartNews_calendarIntervalSinceDate:[[NSCalendar currentCalendar] dateFromComponents:components2]] == 2);
            
        }
        
        {
            NSDateComponents* components1 = [[NSDateComponents alloc] init];
            
            components1.year = 2000;
            components1.month = 1;
            components1.day = 30;
            components1.hour = 10;
            components1.minute = 10;
            components1.second = 10;
            
            NSDateComponents* components2 = [[NSDateComponents alloc] init];
            
            components2.year = 2000;
            components2.month = 1;
            components2.day = 30;
            components2.hour = 23;
            components2.minute = 59;
            components2.second = 59;
            
            assert([[[NSCalendar currentCalendar] dateFromComponents:components1] iSmartNews_calendarIntervalSinceDate:[[NSCalendar currentCalendar] dateFromComponents:components2]] == 0);
            
        }
        
        {
            NSDateComponents* components1 = [[NSDateComponents alloc] init];
            
            components1.year = 2000;
            components1.month = 1;
            components1.day = 31;
            components1.hour = 0;
            components1.minute = 0;
            components1.second = 0;
            
            NSDateComponents* components2 = [[NSDateComponents alloc] init];
            
            components2.year = 2000;
            components2.month = 1;
            components2.day = 30;
            components2.hour = 23;
            components2.minute = 59;
            components2.second = 59;
            
            assert([[[NSCalendar currentCalendar] dateFromComponents:components1] iSmartNews_calendarIntervalSinceDate:[[NSCalendar currentCalendar] dateFromComponents:components2]] == 1);
            
        }
        
        {
            NSDateComponents* components1 = [[NSDateComponents alloc] init];
            
            components1.year = 2000;
            components1.month = 1;
            components1.day = 31;
            components1.hour = 23;
            components1.minute = 59;
            components1.second = 59;
            
            NSDateComponents* components2 = [[NSDateComponents alloc] init];
            
            components2.year = 2000;
            components2.month = 2;
            components2.day = 1;
            components2.hour = 1;
            components2.minute = 0;
            components2.second = 0;
            
            assert([[[NSCalendar currentCalendar] dateFromComponents:components1] iSmartNews_calendarIntervalSinceDate:[[NSCalendar currentCalendar] dateFromComponents:components2]] == 1);
            
        }
        
        {
            NSDateComponents* components1 = [[NSDateComponents alloc] init];
            
            components1.year = 2000;
            components1.month = 1;
            components1.day = 31;
            components1.hour = 23;
            components1.minute = 59;
            components1.second = 59;
            
            NSDateComponents* components2 = [[NSDateComponents alloc] init];
            
            components2.year = 2000;
            components2.month = 2;
            components2.day = 2;
            components2.hour = 1;
            components2.minute = 0;
            components2.second = 0;
            
            assert([[[NSCalendar currentCalendar] dateFromComponents:components1] iSmartNews_calendarIntervalSinceDate:[[NSCalendar currentCalendar] dateFromComponents:components2]] == 2);
            
        }
        
        {
            NSDateComponents* components1 = [[NSDateComponents alloc] init];
            
            components1.year = 2000;
            components1.month = 1;
            components1.day = 31;
            components1.hour = 23;
            components1.minute = 59;
            components1.second = 59;
            
            NSDateComponents* components2 = [[NSDateComponents alloc] init];
            
            components2.year = 2000;
            components2.month = 2;
            components2.day = 3;
            components2.hour = 1;
            components2.minute = 0;
            components2.second = 0;
            
            assert([[[NSCalendar currentCalendar] dateFromComponents:components1] iSmartNews_calendarIntervalSinceDate:[[NSCalendar currentCalendar] dateFromComponents:components2]] == 3);
            
        }
    }
#endif
    
    const NSTimeInterval t = fabs([[currentCalendar dateFromComponents:selfComponents] timeIntervalSinceDate:[currentCalendar dateFromComponents:sinceComponents]])/(3600.0 * 24.);
    return (NSUInteger)t;
}

@end



@implementation NSDictionary (iSmartNewsLowercaseKeys)

- (id)iSmartNews_objectForKey:(id)key{
    return getMessageKey(self,key);
}

/*
 Recursive algorithm to find all nested dictionary keys and create an NSMutableDictionary copy with all keys converted to lowercase
 Returns an NSMutableDictionary with all keys and nested keys converted to lowercase.
 */
+ (NSMutableDictionary *)iSmartNews_dictionaryWithLowercaseKeysFromDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *resultDict = [NSMutableDictionary dictionaryWithCapacity:[dictionary count]];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        // There are 3 types of objects to consider, NSDictionary, NSArray and everything else
        id resultObj;
        if ([obj isKindOfClass:NSDictionary.class])
        {
            // Recursively dig deeper into this nested dictionary
            resultObj = [NSMutableDictionary iSmartNews_dictionaryWithLowercaseKeysFromDictionary:obj];
        }
        else if ([obj isKindOfClass:NSArray.class])
        {
            /*
             Iterate over this nested NSArray. Recursively convert any NSDictionary objects to the lowercase version.
             If the array contains another array then continue to recursively dig deeper.
             */
            resultObj = [NSMutableArray arrayWithCapacity:[obj count]];
            for (id arrayObj in obj)
            {
                if ([arrayObj isKindOfClass:NSDictionary.class])
                    [resultObj addObject:[NSMutableDictionary iSmartNews_dictionaryWithLowercaseKeysFromDictionary:arrayObj]];
                else if ([arrayObj isKindOfClass:NSArray.class])
                    [resultObj addObject:[NSMutableDictionary iSmartNews_arrayWithLowercaseKeysForDictionaryArray:arrayObj]];
                else
                    [resultObj addObject:arrayObj];
            }
        }
        else
        {
            // The object is not an NSDictionary or NSArray so keep the object as is
            resultObj = obj;
        }
        
        // The result object has been converted and can be added to the dictionary. Note this object may be nested inside a larger dictionary.
        [resultDict setObject:resultObj forKey:[key lowercaseString]];
    }];
    return resultDict;
}

/*
 Convienience method to create a new dictionary object with all lowercase keys from an existing instance
 */
- (NSMutableDictionary *)iSmartNews_dictionaryWithLowercaseKeys
{
    return [NSMutableDictionary iSmartNews_dictionaryWithLowercaseKeysFromDictionary:self];
}

#pragma mark - Private helpers

/*
 Convert NSDictionary keys to lower case when embedded in an NSArray
 */
+ (NSMutableArray *)iSmartNews_arrayWithLowercaseKeysForDictionaryArray:(NSArray *)dictionaryArray
{
    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:[dictionaryArray count]];
    for (id eachObj in dictionaryArray)
    {
        if ([eachObj isKindOfClass:NSDictionary.class])
            [resultArray addObject:[NSMutableDictionary iSmartNews_dictionaryWithLowercaseKeysFromDictionary:eachObj]];
        else if ([eachObj isKindOfClass:NSArray.class])
            [resultArray addObject:[NSMutableDictionary iSmartNews_arrayWithLowercaseKeysForDictionaryArray:eachObj]];
    }
    return resultArray;
}

#if DEBUG || ADHOC
+(void)load
{
    //Tests
    
    NSArray* keysTest1 = @[@"urls_ru_ios=7", @"urls_ru_ios=7.3.1", @"urls_ru_ios+10", @"urls_ru_ios+10.3", @"urls_ru_ios+9.3", @"urls_ru_ios-9.0", @"urls_ru_ios-8.1", @"urls_ru_ios-8.0"];
    
    NSArray* keysTest2 = @[@"urls_ru_ios=7.3.1", @"urls_ru_ios+10.3", @"urls_ru_ios+9.3", @"urls_ru_ios-8.0", @"urls_ru_ios-9.0"];
    
    NSArray* keysTest3 = @[@"urls_ru_ios-7.3.1", @"urls_ru_ios-9.3.5", @"urls_ru_ios-10.3.2"];
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest1, @"7.1");
        assert([result isEqualToString:@"ios=7"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest1, @"7.3.1");
        assert([result isEqualToString:@"ios=7"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest2, @"7.3.1");
        assert([result isEqualToString:@"ios=7.3.1"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest1, @"8.0");
        assert([result isEqualToString:@"ios-9.0"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest1, @"8.1");
        assert([result isEqualToString:@"ios-9.0"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest1, @"7.2");
        assert([result isEqualToString:@"ios=7"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest2, @"7.2");
        assert([result isEqualToString:@"ios-8.0"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest2, @"8.0");
        assert([result isEqualToString:@"ios-9.0"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest1, @"10.0");
        assert([result isEqualToString:@"ios+10"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest1, @"10.1");
        assert([result isEqualToString:@"ios+10"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest1, @"10.3");
        assert([result isEqualToString:@"ios+10"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest2, @"10.2");
        assert([result isEqualToString:@"ios+9.3"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest2, @"10.3");
        assert([result isEqualToString:@"ios+10.3"]);
    }
    
    //Strong conditions
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"10.3");
        assert([result isEqualToString:@"ios-10.3.2"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"10.3.1");
        assert([result isEqualToString:@"ios-10.3.2"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"10.3.2");
        assert(result == nil);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"9.3.5");
        assert([result isEqualToString:@"ios-10.3.2"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"9.3.4");
        assert([result isEqualToString:@"ios-9.3.5"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"7.3.2");
        assert([result isEqualToString:@"ios-9.3.5"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"7.3.1");
        assert([result isEqualToString:@"ios-9.3.5"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"7.3.0");
        assert([result isEqualToString:@"ios-7.3.1"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"7.3");
        assert([result isEqualToString:@"ios-7.3.1"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"7.2");
        assert([result isEqualToString:@"ios-7.3.1"]);
    }
    
    {
        NSString* result = firstApplicableOSVersionConditionFromKeys(keysTest3, @"7");
        assert([result isEqualToString:@"ios-7.3.1"]);
    }
    
    iSmartNewsLog(@"Test IOS version filration - successfully");
    
    getMessageKey(@{}, @""); //Initialization of variables
    
    NSString* keyBasic           = @"test";
    NSString* keyDev             = [keyBasic stringByAppendingFormat:@"_%@",    mk_deviceModel];
    NSString* keyLang            = [keyBasic stringByAppendingFormat:@"_%@",    mk_lang];
    NSString* keyLangScreensize  = [keyBasic stringByAppendingFormat:@"_%@_%@", mk_lang, mk_screenSize];
    NSString* keyLangDev         = [keyBasic stringByAppendingFormat:@"_%@_%@", mk_lang, mk_deviceModel];
    
    NSString* osvConditionTrue  = [NSString stringWithFormat:@"ios+%@", [[UIDevice currentDevice] systemVersion]];
    NSString* osvConditionFalse = [NSString stringWithFormat:@"ios-%@", [[UIDevice currentDevice] systemVersion]];
    
    NSMutableDictionary* dict = [NSMutableDictionary new];
    NSArray* validKeys = @[keyBasic, keyDev, keyLang, keyLangScreensize, keyLangDev];
    
    NSUInteger v = 0;
    for (NSString* key in validKeys)
    {
        NSNumber* r = nil;
        
        v++;
        [dict setObject:@(v) forKey:key];
        r = getMessageKey(dict, keyBasic);
        
        assert([r unsignedIntegerValue] == v);
        
        v++;
        NSString* keyWithFalseIOS = [key stringByAppendingFormat:@"_%@", osvConditionFalse];
        [dict setObject:@(v) forKey:keyWithFalseIOS];
        r = getMessageKey(dict, keyBasic);
        
        assert([r unsignedIntegerValue] == (v-1));
        
        v++;
        NSString* keyWithTrueIOS = [key stringByAppendingFormat:@"_%@", osvConditionTrue];
        [dict setObject:@(v) forKey:keyWithTrueIOS];
        r = getMessageKey(dict, keyBasic);
        
        assert([r unsignedIntegerValue] == v);
    }
    
    iSmartNewsLog(@"Test IOS version filration with othes keys - successfully");
}
#endif

@end


NSString* stringFromNSURLComponents(NSURLComponents* components)
{
    if ([components respondsToSelector:@selector(string)])
    {
        return [components string];
    }
    else
    {
        NSMutableString* str = [NSMutableString stringWithFormat:@"%@://%@",[components scheme],[components host]];
        
        if ([[components scheme] isEqualToString:@"http"] && [[components port] intValue] == 80){
            // do nothing
        }
        else if ([[components scheme] isEqualToString:@"https"] && [[components port] intValue] == 443){
            // do nothing
        }
        else
        {
            NSNumber* port = [components port];
            if (port != nil)
            {
                [str appendFormat:@":%@",port];
            }
        }
        
        NSString* path = [components path];
        if (path != nil)
        {
            [str appendFormat:@"%@",path];
        }
        
        NSString* query = [components query];
        if (query != nil && ![query isEqualToString:@""])
        {
            [str appendFormat:@"?%@",query];
        }
        
        NSString* fragment = [components fragment];
        if (fragment != nil && ![fragment isEqualToString:@""])
        {
            [str appendFormat:@"#%@",fragment];
        }
        
        return [str copy];
    }
}

@implementation NSString (iSmartNews)
- (nullable NSString *)sn_stringByAddingPercentEncodingForRFC3986 {
    NSString *unreserved = @"=-._~";
    NSMutableCharacterSet *allowed = [NSMutableCharacterSet
                                      alphanumericCharacterSet];
    [allowed addCharactersInString:unreserved];
    return [self
            stringByAddingPercentEncodingWithAllowedCharacters:
            allowed];
}
@end

@implementation SNUUID
{
    uint8_t _currentValue[sizeof(uuid_t) + sizeof(uint64_t)];
}

+(instancetype) sharedInstance
{
    static SNUUID* sharedInstance = nil;
    if (sharedInstance == nil)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            
            sharedInstance = [SNUUID new];
        });
    }
    return sharedInstance;
}

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        uuid_t bytes;
        [[NSUUID new] getUUIDBytes:bytes];
        
        memset(&_currentValue[0], 0,     sizeof(_currentValue));
        memcpy(&_currentValue[0], bytes, sizeof(uuid_t));
    }
    return self;
}

-(NSString*) shortIUID //InternalUseIdentifier
{
    uint64_t* varp = (uint64_t*)((&_currentValue[0]) + sizeof(uuid_t));
    
    (*varp)++;
    
    uLong crc32Value = crc32(0, &_currentValue[0], sizeof(_currentValue));
    
    NSString* crc32HexValue = [[NSString stringWithFormat:@"%08lx", crc32Value] uppercaseString];
    
    return crc32HexValue;
}

+(NSString*) shortIUID
{
    return [[self sharedInstance] shortIUID];
}

@end


@interface NSDictionary (FlatlineCodec)
@end

@implementation NSDictionary (FlatlineCodec)

-(NSString*) flatLineRepresentation:(NSError**) error
{
    NSMutableArray* lines = [NSMutableArray new];
    NSMutableString* rootLine = [NSMutableString new];
    
    for (NSString* key in [self allKeys])
    {
        NSObject* value = [self objectForKey:key];
        
        if ([value isKindOfClass:[NSDictionary class]])
        {
            NSDictionary* subItems = (NSDictionary*)value;
            
            NSString* subLine = [subItems flatLineRepresentation:error];
            if ([subLine length] > 0)
            {
                NSString* line = [NSString stringWithFormat:@"%@_%@", key, subLine];
                [lines addObject:line];
            }
        }
        else
        {
            const char* entry = NULL;
            
            entry = strpbrk([key UTF8String], "_:|");
            if (entry != NULL)
            {
                if (error != nil)
                    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{@"reason" : @"key contains eeserved characters"}];
                
                return nil;
            }
            
            if ([value isKindOfClass:[NSString class]] != YES)
            {
                if (error != nil)
                    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{@"reason" : @"value are invalid"}];
                
                return nil;
            }
            
            entry = strpbrk([(NSString*)value UTF8String], "_:|");
            
            if (entry != NULL)
            {
                if (error != nil)
                    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{@"reason" : @"value contains eeserved characters"}];
    
                return nil;
            }
            
            if ([rootLine length] > 0)
            {
                [rootLine appendString:@"_"];
            }
            
            [rootLine appendFormat:@"%@:%@", key, value];
        }
    }
    
    if ([rootLine length] > 0)
    {
        [lines insertObject:[rootLine copy] atIndex:0];
    }
    
    NSString* result = [lines componentsJoinedByString:@"|"];
    return result;
}

+(NSDictionary*) dictionaryFromFlatLine:(NSString*) flatLine optionAliases:(NSString*) optionAliases
{
    NSMutableDictionary* result = [NSMutableDictionary new];
    
    NSDictionary* keyAliases = nil;
    
    if ([optionAliases length] > 0)
    {
        keyAliases = [self dictionaryFromFlatLine:optionAliases optionAliases:nil];
    }
    
    NSArray* lines = [flatLine componentsSeparatedByString:@"|"];
    
    for (NSString* line in lines)
    {
        NSMutableDictionary* subItems = [NSMutableDictionary new];
        NSString* prefix = @"";
        NSArray* components = [line componentsSeparatedByString:@"_"];

        for (NSString* component in components)
        {
            if ([component containsString:@":"])
            {
                NSArray* kv = [component componentsSeparatedByString:@":"];
                
                NSString* value = [kv lastObject];
                NSString* key   = [kv firstObject];
                
                NSString* key2 = [keyAliases objectForKey:key];
                if (key2) { key = key2; }
                
                [subItems setValue:value forKey:key];
            }
            else
            {
                if ([prefix length] == 0)
                {
                    prefix = component;
                }
                else
                {
                    prefix = [NSString stringWithFormat:@"%@_%@", prefix, component];
                }
            }
        }
        
        if ([prefix length] > 0)
        {
            [result setValue:[subItems copy] forKey:prefix];
        }
        else
        {
            [result addEntriesFromDictionary:subItems];
        }
    }
    
    return [result copy];
}

#if DEBUG || ADHOC
+(void)load
{
    //Auto tests
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSDictionary* test1 = @{
                                @"mode_1" : @{
                                                @"param1" : @"xxx",
                                                @"param2" : @"2222",
                                                },
                                
                                @"mode_2" : @{
                                        @"parama" : @"aaaaaaaa",
                                        @"paramb" : @"0987654321",
                                        },
                                
                                @"rootparam"   : @"value-x",
                                @"root.param2" : @"value.y",
                                
                                };
        
        NSString* test1_fl = [test1 flatLineRepresentation:nil];
        
        NSDictionary* test1_restore = [NSDictionary dictionaryFromFlatLine:test1_fl optionAliases:nil];
        
        assert([test1_restore isEqualToDictionary:test1]);
        
    });
}
#endif
@end




#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
