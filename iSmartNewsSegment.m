//
//  iSmartNewsSegment.m
//  iSmartNewsDemo
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsSegment.h"
#import "iSmartNewsInternal.h"



static NSString* const LastFetchDateKey = @"ISNSDLFD";
static NSString* const LastFetchDateSourceURLKey = @"ISNSDLFDSU";
static NSString* const SegmentsKey = @"ISNSDCS";
static NSString* const ApiKeyKey = @"ISNSDAK";
static NSString* const SourceUrlKey = @"ISNSDSU";
static NSString* const DefaultSourceUrlKey = @"ISNSDSDU";

@interface iSmartNewsSegment()
{
    UIBackgroundTaskIdentifier _bgTask;
    NSArray* _currentSegments;
    BOOL _fetching;
}
@property (nonatomic, copy) NSString* sourceURLTemplate;
@end

@implementation iSmartNewsSegment

- (NSString*)loadKey:(NSString*)key
{
    NSData* data = [[NSUserDefaults standardUserDefaults] dataForKey:key];
    if (data){

            NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (string){
                return string;
            }
    }
    return nil;
}

- (void)set:(NSString*)value forKey:(NSString*)key
{
    if (value){
        NSData* data = [value dataUsingEncoding:NSUTF8StringEncoding];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:key];
    }
    else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (instancetype)sharedSegment
{
    static iSmartNewsSegment* sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];;
    if (self)
    {
        
#if DEBUG // self test
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString* orig = @"1e532cfa-d28b-4c12-b814-f5ee666a9eec";
                assert([[self urlEncode:orig] isEqualToString:orig]);
                
                assert([[self urlEncode:@"MWU1MzJjZmEtZDI4Yi00YzEyLWI4MTQtZjVlZTY2NmE5ZWVj="]
                        isEqualToString:@"MWU1MzJjZmEtZDI4Yi00YzEyLWI4MTQtZjVlZTY2NmE5ZWVj%3D"]);
                
                assert([[self urlEncode:@"elogKV4VIDz6glcsEg+xyYdZURzYjbGuYZXu5J82p5MLuxGdh8cz+G6z9jbnAls3gj5+oulOZBWRMTmTThNUjDLZmL1nassfvKbm5NF5vGY="]
                        isEqualToString:@"elogKV4VIDz6glcsEg%2BxyYdZURzYjbGuYZXu5J82p5MLuxGdh8cz%2BG6z9jbnAls3gj5%2BoulOZBWRMTmTThNUjDLZmL1nassfvKbm5NF5vGY%3D"]);
            });
        });
#endif
        
        _apiKey = [self loadKey:ApiKeyKey];
        if (!_apiKey){
            _apiKey = @"dummy_key";
        }
        
        NSString* defaultSourceURL = [self loadKey:DefaultSourceUrlKey];
        if (defaultSourceURL){
            _defaultSourceURLTemplate = defaultSourceURL;
        }
        
        NSString* sourceURL = [self loadKey:SourceUrlKey];
        if (sourceURL){
            _sourceURLTemplate = sourceURL;
        }
        
        NSString* segments = [self loadKey:SegmentsKey];
        if ([segments length] > 0){
            _currentSegments = [segments componentsSeparatedByString:@"|"];
            if ([_currentSegments count] == 0){
                _currentSegments = @[@"undefined"];
            }
        }
        else {
            _currentSegments = @[@"undefined"];
        }
        iSmartNewsLog(@"Set user segments: %@", _currentSegments);
        [self set:[_currentSegments componentsJoinedByString:@"|"] forKey:SegmentsKey];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue
                                                                  ] usingBlock:^(NSNotification * _Nonnull note) {
                                                               [self _fetch];
                                                           }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue
                                                                  ] usingBlock:^(NSNotification * _Nonnull note) {
                                                               [self _fetch];
                                                           }];
    }
    return self;
}

- (void)setDefaultSourceURLTemplate:(NSString *)defaultSourceURLTemplate
{
    if (_defaultSourceURLTemplate && defaultSourceURLTemplate && [_defaultSourceURLTemplate isEqual:defaultSourceURLTemplate]){
        return;
    }
    
    _defaultSourceURLTemplate = defaultSourceURLTemplate;
    
    [self set:_defaultSourceURLTemplate forKey:DefaultSourceUrlKey];
    
    if (!_defaultSourceURLTemplate){
        return;
    }
    
    [self _fetch];
}

- (void)setSourceURLTemplate:(NSString *)sourceURLTemplate
{
    if (_sourceURLTemplate && sourceURLTemplate && [_sourceURLTemplate isEqual:sourceURLTemplate]){
        return;
    }
    
    _sourceURLTemplate = sourceURLTemplate;
    
    [self set:_sourceURLTemplate forKey:SourceUrlKey];
    
    if (!_sourceURLTemplate){
        return;
    }
    
    iSmartNewsLog(@"Set segment fetch URL: %@", _sourceURLTemplate);
 
    [self _fetch];
}

- (NSString*)uid
{
    return nil;
}

- (NSString*)nuid
{

    return nil;
}

- (void)_fetch
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_realFetch) object:nil];
    [self performSelector:@selector(_realFetch) withObject:nil afterDelay:0.1];
}

- (NSString*)urlEncode:(NSString*)unencodedString
{
    NSString *encodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                                    NULL,
                                                                                                    (CFStringRef)unencodedString,
                                                                                                    NULL,
                                                                                                    (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                                    kCFStringEncodingUTF8 ));
    return encodedString;
}

- (void)_realFetch
{
    if (!sn_allowUpdate())
    {
        return;
    }
    
    if (_fetching){
        return;
    }
    
    if (!_sourceURLTemplate){
        return;
    }
    
    NSString* const uid = [self uid];
    NSString* const nuid = [self nuid];
    
    NSString* urlString = _sourceURLTemplate;
    
    if ([urlString rangeOfString:@"${UID}"].location != NSNotFound)
    {
        if ([uid length] == 0)
            return;

        urlString = [urlString stringByReplacingOccurrencesOfString:@"${UID}" withString:[self urlEncode:uid]];
    }
    
    if ([urlString rangeOfString:@"${NUID}"].location != NSNotFound)
    {
        if ([nuid length] == 0)
            return;

        urlString = [urlString stringByReplacingOccurrencesOfString:@"${NUID}" withString:[self urlEncode:nuid]];
    }
    
    if ([urlString rangeOfString:@"${KEY}"].location != NSNotFound){
        if (!_apiKey){
            return;
        }
        urlString = [urlString stringByReplacingOccurrencesOfString:@"${KEY}" withString:[self urlEncode:_apiKey]];
    }

    NSURL* url =  [NSURL URLWithString:urlString];
    if (!url){
        return;
    }
    
    NSDate* const lastFetch = [[NSUserDefaults standardUserDefaults] objectForKey:LastFetchDateKey];
    if (lastFetch)
    {
        NSDate* const now = [NSDate ism_date];
        if ([now iSmartNews_calendarIntervalSinceDate:lastFetch] == 0)
        {
            NSString* const lastUsedURL = [self loadKey:LastFetchDateSourceURLKey];
            // check url
            if (lastUsedURL){
                // return if URL was the same
                if ([lastUsedURL isEqualToString:[url absoluteString]]){
                    return;
                }
            }
            else {
                return;
            }
        }
    }
    
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    if (!request){
        return;
    }
    
    _bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
        _bgTask = UIBackgroundTaskInvalid;
    }];
    
    _fetching = YES;
    
#pragma warning repleace deprecated NSURLConnection
#pragma clang diagnostic push                                   //NSURLConnection
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
                               
                               [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
                               _bgTask = UIBackgroundTaskInvalid;
                               
                               _fetching = NO;
                               
                               if (connectionError || [data length] == 0){
                                   return;
                               }
                               
                               NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                               if (!json){
                                   return;
                               }
                               
                               NSArray* const segments = [json objectForKey:@"segments"];
                               if (![segments isKindOfClass:[NSArray class]]){
                                   return;
                               }
                               
                               [self set:[url absoluteString] forKey:LastFetchDateSourceURLKey];
                               
                               [[NSUserDefaults standardUserDefaults] setObject:[NSDate ism_date] forKey:LastFetchDateKey];
                               [[NSUserDefaults standardUserDefaults] synchronize];
                               
                               NSArray* checkedSegments = [segments filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                                   return [evaluatedObject isKindOfClass:[NSString class]] && [[evaluatedObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] != 0;
                               }]];
                               
                               if ([checkedSegments count] > 0){
                                   NSMutableArray* trimmedSegments = [NSMutableArray arrayWithCapacity:[checkedSegments count]];
                                   [segments enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                       [trimmedSegments addObject:[obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                                   }];
                                   
                                   _currentSegments = [trimmedSegments copy];
                                   if ([_currentSegments count] == 0){
                                       _currentSegments = @[@"undefined"];
                                   }
                                   iSmartNewsLog(@"Set user segments: %@", _currentSegments);
                                   [self set:[_currentSegments componentsJoinedByString:@"|"] forKey:SegmentsKey];
                               }
                               else {
                                   _currentSegments = @[@"undefined"];
                                   iSmartNewsLog(@"Set user segments: %@", _currentSegments);
                                   [self set:[_currentSegments componentsJoinedByString:@"|"] forKey:SegmentsKey];
                               }
                           }];
#pragma clang diagnostic pop                            //NSURLConnection
}

- (BOOL)matches:(NSString *)segment
{
    assert([_currentSegments count] > 0);
    
    if ([segment length] == 0){
        return YES;
    }
    
    __block BOOL matches = NO;
    NSArray* const segmentsToCheck = [segment componentsSeparatedByString:@"|"];
    [segmentsToCheck enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([_currentSegments indexOfObject:obj] != NSNotFound){
            matches = YES;
            *stop = YES;
        }
    }];
    
    return matches;
}

- (void)reset
{
    iSmartNewsLog(@"Resetting segments...");
    
    _sourceURLTemplate = nil;
    
    _currentSegments = @[@"undefined"];
    iSmartNewsLog(@"Set user segments: %@", _currentSegments);
    [self set:[_currentSegments componentsJoinedByString:@"|"] forKey:SegmentsKey];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LastFetchDateKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:SourceUrlKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)preprocess:(NSArray*)items
{
    [items enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (![obj isKindOfClass:[NSDictionary class]]){
            return;
        }
        
        if (![obj objectForKey:@"segments"]){
            return;
        }
        
        NSDictionary* info = [obj objectForKey:@"segments"];
        if (![info isKindOfClass:[NSDictionary class]]){
            return;
        }
        
        info = [info iSmartNews_dictionaryWithLowercaseKeys];
        
        NSString* source = [info iSmartNews_objectForKey:@"source"];
        if (![source isKindOfClass:[NSString class]]){
            return;
        }
        
        if ([source isEqualToString:@"default"]){
            if (self.defaultSourceURLTemplate){
                self.sourceURLTemplate = self.defaultSourceURLTemplate;
            }
        }
        else if ([source isEqualToString:@"disable"]){
            self.sourceURLTemplate = nil;
        }
        else {
            self.sourceURLTemplate = source;
        }
    }];
}

@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
