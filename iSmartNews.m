
#import "iSmartNews.h"
#include <stdio.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "iSmartEventsCenter.h"
#import "iSmartNewsVisualizer.h"

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#pragma clang diagnostic ignored "-Wnullability-completeness"

#ifndef STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO
# define STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#endif

#if DEBUG
# if NO_SMARTNEWS_LOGS
#  define iSmartNewsLog(...)         ((void)0)
# else
#  define iSmartNewsLog(...)         NSLog(@"iSmartNews: %@",[NSString stringWithFormat:__VA_ARGS__])
# endif
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

#ifdef SMARTNEWS_COMPILE
# undef  SMARTNEWS_COMPILE
# define SMARTNEWS_COMPILE   0
#else
# define SMARTNEWS_COMPILE   1
#endif

NSString* const iSmartNewsUserDidOpenReviewNotification = @"ISNUDORN27346";

static BOOL UIApplicationWillResignActiveNotificationDone = NO;
static const char emulateAppActivateKey;
static const char connectionDataKey;

#if DEBUG || ADHOC
static NSURL* OriginalURL = nil;
static NSString* DebugURLPostFix = nil;
#endif//#if DEBUG || ADHOC

/*!
 @addtogroup iSmartNewsMessageKeys Keys used in description of message.
 @{
 */

/*! @brief
 If value with specified key presents, then should contain title of message as NSString object.
 */
extern NSString*  const  iSmartNewsMessageTitleKey;

/*! @brief
 If value with specified key presents, then should contain text of message as NSString object.
 */
extern NSString*  const  iSmartNewsMessageTextKey;

/*! @brief
 If value with specified key presents, then should contain title of cancel button as NSString object.
 In another case localized version of 'Cancel' will be used.
 */
extern NSString*  const  iSmartNewsMessageCancelKey;

/*! @brief
 If value with specified key presents, then should contain title of Ok button as NSString object.
 In another case localized version of 'Ok' will be used. If no iSmartNewsMessageUrlKey
 was found, then this button is also hidden, because nothing to open.
 */
extern NSString*  const  iSmartNewsMessageActionKey;

/*! @brief
 If value with specified key presents, then should contain text of link as NSString object.
 That link will be opened if Ok is pressed.
 */
extern NSString*  const  iSmartNewsMessageUrlKey;

/*! @brief
 If value with specified key presents, then should contain minimum NSDate object.
 If found, then module compares current date with that one and if current date
 is equal or older that start date, then message can be shown.
 */
extern NSString*  const  iSmartNewsMessageStartDateKey;

/*! @brief
 If value with specified key presents, then should contain maximum NSDate object.
 If found, then module compares current date with that one and if current date
 is equal or earlier that end date, then message can be shown.
 */
extern NSString*  const  iSmartNewsMessageEndDateKey;

/*! @brief
 If value with specified key presents, then should contain NSNumber object.
 If found, then if it is NO, then message is shown only once event if user
 clicks 'Cancel', in another case message will be shown until 'Ok' is pressed.
 By default NO is assumed.
 */
extern NSString*  const  iSmartNewsMessageRepeatKey;

/*! @brief
 If value with specified key presents, then should contain NSNumber object.
 If found, then if it is YES, then message is shown every time even if user pressed 'Ok' or 'Cancel'.
 By default NO is assumed.
 */
extern NSString*  const  iSmartNewsMessageAlwaysKey;

/*! @brief
 If value with specified key presents, then should contain NSNumber object.
 Contains number of calls to update required to show news.
 Default value is assumed to be 0.
 @note Value is supported only in shared instance of iSmartNews object.
 */
extern NSString*  const  iSmartNewsMessageCounterKey;

/*! @brief
 Assigns message to message queue.
 @note Value is supported only in shared instance of iSmartNews object.
 @since Version 1.4
 */
extern NSString*  const  iSmartNewsMessageQueueKey;

/*! @brief
 Sets special type of content.
 @see  iSmartNewsContentTypeWeb.
 @since Version 1.7
 */
extern NSString*  const iSmartNewsMessageTypeKey;

/*! @brief
 Sets special type of content to web.
 @see  iSmartNewsMessageTypeKey.
 @since Version 1.7
 */
extern NSString*  const iSmartNewsContentTypeWeb;

extern NSString*  const  iSmartNewsMessageReviewKey;
extern NSString*  const  iSmartNewsMessageRemindKey;

/*!
 @}
 */

static const char iSmartNews_hideStatusbar_originalKey;
static const char iSmartNews_hideStatusbarKey;


/*! @cond SkipThis
 ----------------------------------------------------------------------------
 */
@class iSmartNewsPopupViewController;

@interface iSmartNews() <iSmartNewsVisualizerDelegate>
@property (nonatomic, copy) iSmartEventsCenterCallbackCompletion eventsCenterCompletion;
@end
/*! ----------------------------------------------------------------------------
 @endcond
 */

#import "iSmartNewsCoreData.h"
#import "iSmartNewsUtils.h"
#import "iSmartNewsPopupNavigationController.h"
#import "iSmartNewsMeta.h"
#import "iSmartNews+UIApplication.h"
#import "iSmartNewsModalPanel.h"
#import "iSmartNewsRoundedRectView.h"
#import "iSmartNewsImages.h"
#import "iSmartNewsPopupViewController.h"
#import "iSmartNewsWindow.h"
#import "iSmartNewsVisualizer.h"
#import "iSmartNewsZip.h"
#import "iSmartNewsEvents.h"
#import "iSmartNewsDate.h"

#if SMARTNEWS_COMPILE
#import "iSmartNewsCoreData.m"
#import "iSmartNewsUtils.m"
#import "iSmartNewsPopupNavigationController.m"
#import "iSmartNewsMeta.m"
#import "iSmartNews+UIApplication.m"
#import "iSmartNewsModalPanel.m"
#import "iSmartNewsRoundedRectView.m"
#import "iSmartNewsImages.m"
#import "iSmartNewsPopupViewController.m"
#import "iSmartNewsWindow.m"
#import "iSmartNewsVisualizer.m"
#import "iSmartNewsZip.m"
#import "iSmartNewsEvents.m"
#import "iSmartNewsDate.m"
#import "iSmartNewsLocalization.m"
#endif

#import <CommonCrypto/CommonDigest.h>

static CanIShowAlertViewRightNowHandler gCanIShowAlertViewRightNow = nil;

NSString*  const  iSmartNewsMessageTitleKey = @"iSmartNewsMessageTitleKey";          //  NSString, message title
NSString*  const  iSmartNewsMessageTextKey = @"iSmartNewsMessageTextKey";            //  NSString, message text
NSString*  const  iSmartNewsMessageCancelKey = @"iSmartNewsMessageCancelKey";        //  NSString, title for 'cancel' button
NSString*  const  iSmartNewsMessageActionKey = @"iSmartNewsMessageActionKey";        //  NSString, title for 'ok' button
NSString*  const  iSmartNewsMessageReviewKey = @"iSmartNewsMessageReviewKey";
NSString*  const  iSmartNewsMessageRemindKey = @"iSmartNewsMessageRemindKey";
NSString*  const  iSmartNewsMessageUrlKey = @"iSmartNewsMessageUrlKey";              //  NSString, url to open if 'ok' was pressed
NSString*  const  iSmartNewsMessageStartDateKey = @"iSmartNewsMessageStartDateKey";  //  NSDate
NSString*  const  iSmartNewsMessageEndDateKey = @"iSmartNewsMessageEndDateKey";      //  NSDate
NSString*  const  iSmartNewsMessageRepeatKey = @"iSmartNewsMessageRepeatKey";        //  NSNumber (as bool)
NSString*  const  iSmartNewsMessageAlwaysKey = @"iSmartNewsMessageAlwaysKey";        //  NSNumber (as bool)
NSString*  const  iSmartNewsMessageCounterKey = @"iSmartNewsMessageCounterKey";      //  NSNumber
NSString*  const  iSmartNewsMessageQueueKey = @"iSmartNewsMessageQueueKey";           //  NSString, name of queue

NSString*  const iSmartNewsMessageTypeKey = @"iSmartNewsMessageTypeKey";             //  NSString, type of message. "web" for web content
NSString*  const iSmartNewsContentTypeWeb = @"web";

@interface iSmartNews()
@property (nonatomic,strong,readonly) NSString* service;
@property (nonatomic,strong,readonly) NSString* settingsPath;
@property (nonatomic,strong,readonly) NSString* cachePath;
@end

@implementation iSmartNews {
    
    UIBackgroundTaskIdentifier _updateBgTaskId;
    
    NSData* _currentNews;
    
    iSmartNewsVisualizer* _visualizer;
    
    NSMutableDictionary* _settings;
    
    /*! @cond SkipThis  */
    
    /*! @internal */
    NSURLConnection*        connection_;
    
    /*! @internal */
    NSMutableArray*         loadedNews_;
    
    /*! @internal */
    /*! @since Version 1.3 */
    NSUInteger              gate_;
    
    /*! @endcond  */
    
    NSString* currentQueue_;
    NSMutableDictionary* queuesInfo_;
    NSMutableDictionary* queuesTimeouts_;
    NSTimer* queueTimer_;
    NSTimer* retryTimer_;
    BOOL isFirst_;
    
    void (^_removeAdsActionBlock)();
    
    BOOL _advIsOnScreen;
    NSTimer* _advIsOnScreenWatchDogTimer;
}

static NSMutableDictionary* services = nil;

+ (iSmartNews*)sharedNews
{
    static iSmartNews* inst;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [(iSmartNews*)[self alloc] initWithServiceName:@"news"];
    });
    return inst;
}

+ (iSmartNews*)sharedAdvertising;
{
    static iSmartNews* inst;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [(iSmartNews*)[self alloc] initWithServiceName:@"customadv"];
    });
    return inst;
}

- (void)resetLoadedDataBuffer
{
    _currentNews = nil;
}

- (void)resetAll
{
    NSManagedObjectContext* context = managedObjectContext(self.service);
    if (context)
    {
        {
            NSFetchRequest *fetchReq = [[NSFetchRequest alloc] init];
            [fetchReq setEntity:[NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context]];
            [fetchReq setPredicate:[NSPredicate predicateWithValue:YES]];
            NSArray* items = [context executeFetchRequest:fetchReq error:NULL];
            
            for (NSManagedObject* mo in items){
                [context deleteObject:mo];
            }
        }
        
        {
            NSFetchRequest *fetchReq = [[NSFetchRequest alloc] init];
            [fetchReq setEntity:[NSEntityDescription entityForName:@"SmartNewsEvent" inManagedObjectContext:context]];
            [fetchReq setPredicate:[NSPredicate predicateWithValue:YES]];
            NSArray* items = [context executeFetchRequest:fetchReq error:NULL];
            
            for (NSManagedObject* mo in items){
                [context deleteObject:mo];
            }
        }
        
        saveContext(self.service);
    }
    
    _currentNews = nil;
    [self clearCache];
    [[self settings] removeAllObjects];
    [self save];
    
    [[g_sn_eventShownNews objectForKey:self.service] removeAllObjects];
    
    clearNewsLang();
    
    [self resetUpgradeInfo];
}

- (void)resetUpgradeInfo
{
    g_isUpgradeDetected = NO;
    g_isUpgrade = NO;
    g_AppUpgradeDone = NO;
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SNVersionOfLastRun"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SNUpgrade"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)updateUpgradeInfo
{
    detectUpgrade(YES);
}

- (NSMutableDictionary*)settings
{
    if (!_settings)
    {
        _settings = [[NSMutableDictionary alloc] initWithContentsOfFile:[self settingsPath]];
        if (!_settings)
            _settings = [[NSMutableDictionary alloc] init];
        
        iSmartNewsLog(@"_settings: %@",_settings);
    }
    
    return _settings;
}

+ (void)setCanIShowAlertViewRightNowHandler:(CanIShowAlertViewRightNowHandler)CanIShowAlertViewRightNow
{
    gCanIShowAlertViewRightNow = [CanIShowAlertViewRightNow copy];
}

- (void)resetRunCounter
{
    [[self settings] setObject:[NSNumber numberWithUnsignedLongLong:0] forKey:@"counter"];
    [self save];
}

- (void)save
{
    if (_settings)
    {
        [_settings writeToFile:[self settingsPath] atomically:YES];
        iSmartNewsLog(@"_settings saved");
    }
}

- (void)advWillShow
{
    _advIsOnScreen = YES;
    [_advIsOnScreenWatchDogTimer invalidate];
    _advIsOnScreenWatchDogTimer = [NSTimer scheduledTimerWithTimeInterval:600 target:self selector:@selector(advDidHide) userInfo:nil repeats:NO];
}

- (void)advDidHide
{
    [_advIsOnScreenWatchDogTimer invalidate];
    _advIsOnScreenWatchDogTimer = nil;
    _advIsOnScreen = NO;
}

/*! @brief Contructor */
- (id)initWithServiceName:(NSString*)serviceName
{
	self = [super init];

	if ( self )
	{
        _service = [serviceName copy];
        
        __weak iSmartNews* wSelf = self;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(advWillShow) name:@"iSmartAdvertisingWillShowFullscreenBannerNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(advDidHide) name:@"iSmartAdvertisingDidHideFullscreenBannerNotification" object:nil];
        
        [[iSmartEventsCenter sharedCenter] registerService:self.service
                                                  callback:^(NSString* event, iSmartEventsCenterCallbackCompletion completion){
                                                      
                                                      if ([event isEqualToString:iSmartEventsCenterAppActivateEvent]){
                                                          if (!UIApplicationWillResignActiveNotificationDone){
                                                              completion(iSmartEventsCenterCallbackContinue,nil);
                                                              return;
                                                          }
                                                      }
                                                      
                                                      if (_advIsOnScreen){
                                                          completion(iSmartEventsCenterCallbackContinue,nil);
                                                          return;
                                                      }
                                                      
                                                      iSmartNews* this = wSelf;
                                                      
                                                      NSManagedObjectContext* context = managedObjectContext(this.service);
                                                      
                                                      NSEntityDescription *entity = [NSEntityDescription entityForName:@"SmartNewsEvent" inManagedObjectContext:context];
                                                      
                                                      NSFetchRequest *fetchAllRequest = [[NSFetchRequest alloc] init];
                                                      [fetchAllRequest setEntity:entity];
                                                      [fetchAllRequest setPredicate:[NSPredicate predicateWithValue:YES]];
                                                      
                                                      //
                                                      if (([[context executeFetchRequest:fetchAllRequest error:NULL] count] == 0)
                                                          && [event isEqualToString:iSmartEventsCenterAppActivateEvent])
                                                      {
                                                          if (!this.eventsCenterCompletion)
                                                          {
                                                              this.eventsCenterCompletion = completion;
                                                              [this showForActiveEvents:@[]];
                                                          }
                                                          else
                                                          {
                                                              completion(iSmartEventsCenterCallbackContinue,nil);
                                                          }
                                                          return;
                                                      }
                                                      
                                                      
                                                      NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
                                                      [fetchRequest setEntity:entity];
                                                      [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"name = %@",event]];
                                                      
                                                      NSError* error = nil;
                                                      NSMutableArray* matches = [[context executeFetchRequest:fetchRequest error:&error] mutableCopy];
                                                      if (!matches || [matches count] == 0)
                                                      {
                                                          completion(iSmartEventsCenterCallbackContinue,nil);
                                                          return;
                                                      }
                                                      
                                                      NSMutableArray* activeEvents = [NSMutableArray new];
                                                      
                                                      for (SmartNewsEvent* eventObj in matches)
                                                      {
                                                          NSString* stateType;
                                                          
                                                          do
                                                          {
                                                              NSString* currentPattern = [eventObj currentPattern];
                                                              if (!currentPattern || [currentPattern isEqualToString:@""])
                                                              {
                                                                  [eventObj setCurrentPattern:[eventObj initialPattern]];
                                                                  currentPattern = [eventObj initialPattern];
                                                              }
                                                              
                                                              NSMutableArray* parts = [[currentPattern componentsSeparatedByString:@"|"] mutableCopy];
                                                              
                                                              do {
                                                                  NSString* currentPart = [parts firstObject];
                                                                  NSArray* state = [currentPart componentsSeparatedByString:@"="];
                                                                  stateType = [state firstObject];
                                                                  NSInteger stateCounter = [[state lastObject] integerValue];
                                                                  if (stateCounter == 0)
                                                                  {
                                                                      [parts removeObjectAtIndex:0];
                                                                      
                                                                      if ([parts count] == 0)
                                                                      {
                                                                          break;
                                                                      }
                                                                      
                                                                      continue;
                                                                  }
                                                                  
                                                                  [parts replaceObjectAtIndex:0 withObject:[NSString stringWithFormat:@"%@=%d",stateType,(int)(stateCounter - 1)]];
                                                                  break;
                                                                  
                                                              } while (YES);
                                                              
                                                              if ([parts count] == 0)
                                                              {
                                                                  [eventObj setCurrentPattern:[eventObj initialPattern]];
                                                                  continue;
                                                              }
                                                              
                                                              [eventObj setCurrentPattern:[parts componentsJoinedByString:@"|"]];
                                                              break;
                                                          }
                                                          while (YES);
                                                          
                                                          if ([stateType isEqualToString:@"on"])
                                                          {
                                                              [activeEvents addObject:eventObj];
                                                          }
                                                      }
                                                      
                                                      saveContext(this.service);
                                                      
                                                      if ([activeEvents count] == 0)
                                                      {
                                                          completion(iSmartEventsCenterCallbackContinue,nil);
                                                          return;
                                                      }

                                                      if (!this.eventsCenterCompletion)
                                                      {
                                                          this.eventsCenterCompletion = completion;
                                                          [this showForActiveEvents:activeEvents];
                                                      }
                                                      else
                                                      {
                                                          completion(iSmartEventsCenterCallbackContinue,nil);
                                                      }
                                                  }
                                                 forEvents:nil
                                              withPriority:1000];
        
        [self settings];// load
        
        if (![[[self settings] objectForKey:@"launchDate"] isKindOfClass:[NSDate class]]){
            [[self settings] setObject:[NSDate ism_date] forKey:@"launchDate"];
            [self save];
        }
        
        queuesTimeouts_ = [NSMutableDictionary new];
        [self loadQueuesInfo];
        
        gate_ = UINT_MAX;
        loadedNews_ = [[NSMutableArray alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UIWindowDidBecomeKeyNotification) name:UIWindowDidBecomeKeyNotification object:nil];
        
        if (!services){
            services = [NSMutableDictionary new];
        }
        [services setObject:self forKey:serviceName];
	}

	return self;
}

+ (iSmartNews*)newsForService:(NSString*)name
{
    return [services objectForKey:name];
}

- (void)UIWindowDidBecomeKeyNotification
{
}

/*! @brief Destructor */
- (void)dealloc
{   
    [self save];
    [connection_ cancel];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark Cache

- (NSString*)settingsPath
{
    if ([self.service isEqualToString:@"news"]){
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:@"iSmartNewsCacheSettings.plist"];
    }
    else {
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:[@"iSmartNewsCacheSettings" stringByAppendingFormat:@"_%@.plist",self.service]];
    }
}

- (NSString*)cachePath
{
    if ([self.service isEqualToString:@"news"]){
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                        stringByAppendingPathComponent:@"iSmartNewsCache.txt"];
    }
    else {
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:[@"iSmartNewsCache" stringByAppendingFormat:@"_%@.txt",self.service]];
    }
}

- (void)clearCache
{
    iSmartNewsMainThread;
    
    [[NSFileManager defaultManager] removeItemAtPath:[self cachePath] error:NULL];
    
    iSmartNewsLog(@"clearCache");        
}

- (void)setCacheValue:(NSDictionary*)_value
{
    if ([_value objectForKey:@"skipCache"])
        return;
    
    FILE* file = fopen([[self cachePath] UTF8String], "a");
    if (file)
    {
        const char* v = [news_md5ForDictionary(_value) UTF8String];
        fwrite(v, strlen(v), 1, file);
        fwrite("\n", 1, 1, file);
        fflush(file);
        fclose(file);
        iSmartNewsLog(@"setCacheValue:%@ -> %s",_value,v);
    }
}

- (BOOL)checkIfMessageWasAlreadyShown:(NSDictionary*)_message
{
    if ([_message objectForKey:@"skipCache"])
        return NO;
    
    FILE* cache = fopen([[self cachePath] UTF8String], "r");
    if (!cache)
        return NO;
    
    rewind(cache);

    const char* key = [news_md5ForDictionary(_message) UTF8String];
    BOOL retVal = NO;
    
    while(!retVal)
    {
        char buf[129];
        memset(buf,0,sizeof(buf));
        if (!fgets(buf, sizeof(buf)-1, cache))
            break;
        
        size_t bytesRead = strlen(buf);
        
        for (; bytesRead && (buf[bytesRead-1]=='\n' || buf[bytesRead-1]=='\r'); --bytesRead )
            buf[bytesRead-1]=0;
        
        if (bytesRead != CC_MD5_DIGEST_LENGTH * 2)
            continue;
        
        if (!memcmp(key, buf, CC_MD5_DIGEST_LENGTH * 2))
            retVal = YES;
    }
    
    fclose(cache);
    
    iSmartNewsLog(@"checkIfMessageWasAlreadyShown:%@ -> %d",_message,retVal);
    
    return retVal;
}

#pragma mark -
#pragma mark Logic

- (BOOL)pumpUrls:(BOOL)emulateAppActivate
{
    assert(!connection_);
    assert([NSThread isMainThread]);
    
    NSString* urlString = [_url absoluteString];
    
    urlString = [NSString stringWithFormat:@"%@%@v=%@", urlString, [urlString rangeOfString:@"?"].length > 0 ? @"&" : @"?", [[self class] versionString]];
    
    NSURL* url = [NSURL URLWithString:urlString];
    if (!url)
    {
        return NO;
    }
    
    NSURLRequest* request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringCacheData // NO CACHE!!!
                                         timeoutInterval:7];
    if (!request)
    {
        return NO;
    }
    
    connection_ = [NSURLConnection connectionWithRequest:request delegate:self];

    if (!connection_)
    {
        return NO;
    }
    
    if (emulateAppActivate){
        objc_setAssociatedObject(connection_, &emulateAppActivateKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return YES;
}

- (void)completeEvent
{
    if (self.eventsCenterCompletion){
        iSmartEventsCenterCallbackCompletion cb = self.eventsCenterCompletion;
        self.eventsCenterCompletion = nil;
        
        NSArray* allServices = @[@"upgrade",@"review"];
        NSArray* existingServices = [services allKeys];
        if (existingServices){
            allServices = [allServices arrayByAddingObjectsFromArray:existingServices];
        }
        
        cb(iSmartEventsCenterCallbackContinue,[allServices filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return ![evaluatedObject isEqualToString:self.service];
        }]]);
    }
}

- (void)_update:(BOOL)emulateAppActivate
{
    iSmartNewsMainThread;
    
    Class iSmartBarrierClass = NSClassFromString(@"iSmartBarrier");
    if (iSmartBarrierClass)
    {
        SEL sharedBarrierSel = NSSelectorFromString(@"sharedBarrier");
        id (*sharedBarrierFunc) (id self, SEL _cmd) = (id (*) (id self, SEL _cmd))objc_msgSend;
        id sharedBarrier = sharedBarrierFunc(iSmartBarrierClass,sharedBarrierSel);
        if (sharedBarrier)
        {
            SEL allowedSel = NSSelectorFromString(@"allowed");
            if ([sharedBarrier respondsToSelector:allowedSel])
            {
                BOOL (*allowedFunc) (id self, SEL _cmd) = (BOOL (*) (id self, SEL _cmd))objc_msgSend;
                if (!allowedFunc(sharedBarrier,allowedSel))
                {
                    return;
                }
            }
        }
    }
    
    iSmartNewsLog(@"Update called");
    
    if ( connection_ )
    {
        [connection_ cancel];
        connection_ = nil;
        
        iSmartNewsLog(@"Previous connection canceled");
    }
    
    if ([self pumpUrls:emulateAppActivate] && ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive))
    {
        if (_updateBgTaskId == UIBackgroundTaskInvalid)
        {
            _updateBgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [[UIApplication sharedApplication] endBackgroundTask:_updateBgTaskId];
                _updateBgTaskId = UIBackgroundTaskInvalid;
                [connection_ cancel];
                connection_ = nil;
            }];
        }
    }
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
}

- (void)clearAndHideAlert
{
    [_visualizer forceHide];
    [self resetVisualizerVar];
    
    [retryTimer_ invalidate];
    retryTimer_ = nil;
    
    [queueTimer_ invalidate];
    queueTimer_ = nil;
    
    currentQueue_ = nil;

    [queuesTimeouts_ removeAllObjects];
    [loadedNews_ removeAllObjects];
    
    [self completeEvent];
}


- (void)parseEvents:(NSData*)newData
{
    if (!newData){
        return;
    }
    
    if (![newData length]){
        return;
    }
    
    NSArray* origNews = [self newsFromData:newData];
    
    if ([origNews isKindOfClass:[NSArray class]])
    {
        NSMutableSet* loadedMeta = [NSMutableSet new];
        preprocessMeta(self.service, origNews,loadedMeta);
        preprocessEvents(self.service, origNews);
    }
}

- (NSDate*)launchDate
{
    NSDate*  launchDate = [[self settings] objectForKey:@"launchDate"];
    if (![launchDate isKindOfClass:[NSDate class]]){
        [[self settings] setObject:[NSDate ism_date] forKey:@"launchDate"];
        [self save];
        launchDate = [[self settings] objectForKey:@"launchDate"];
    }
    return launchDate;
}

- (void)resetLaunchDate
{
    [[self settings] setObject:[NSDate ism_date] forKey:@"launchDate"];
    [self save];
}

- (NSArray*)newsFromData:(NSData*)data
{
    NSString* tmpFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"iSmartNewsTempFile" stringByAppendingFormat:@"_%@.tmp",[self service]]];
    [[NSFileManager defaultManager] removeItemAtPath:tmpFile error:0];
    [data writeToFile:tmpFile atomically:YES];
    NSArray* origNews = [[NSArray alloc] initWithContentsOfFile:tmpFile];
    [[NSFileManager defaultManager] removeItemAtPath:tmpFile error:NULL];
    
    SEL __lsrv_applySel = NSSelectorFromString(@"__lsrv_apply");
    if (__lsrv_applySel && [origNews respondsToSelector:__lsrv_applySel])
    {
        NSArray* (*f__lsrv_apply) (id self, SEL _cmd) = (NSArray* (*) (id self, SEL _cmd))objc_msgSend;
        origNews = f__lsrv_apply(origNews,__lsrv_applySel);
    }
    
    return origNews;
}

- (void)parse:(NSData*)newData events:(NSArray*)events
{
    if (!newData){
        [self completeEvent];
        iSmartNewsLog(@"No data loaded");
        return;
    }
    
    [queuesTimeouts_ removeAllObjects];
    
    [retryTimer_ invalidate];
    retryTimer_ = nil;
    
    [queueTimer_ invalidate];
    queueTimer_ = nil;
    
    [loadedNews_ removeAllObjects];
    gate_ = UINT_MAX;
    
    currentQueue_ = nil;
    
    isFirst_ = YES;
    
    NSMutableSet* loadedMeta = [NSMutableSet new];
    
    cleanMessageKeysCache();
    
    NSDate*  launchDate = [self launchDate];
    
    if ([newData length])
    {
        NSArray* origNews = [self newsFromData:newData];
        
        if ([origNews isKindOfClass:[NSArray class]])
        {
            NSArray* news = preprocessMeta(self.service, origNews,loadedMeta);
            preprocessEvents(self.service, origNews);
            
            for (NSDictionary* _desc in news)
            {
                NSDictionary* desc = _desc;
                
                if ([desc isKindOfClass:[NSDictionary class]]){
                    desc = [desc iSmartNews_dictionaryWithLowercaseKeys];                    
                }
                
                NSMutableDictionary* message = [[NSMutableDictionary alloc] init];
                @try
                {
                    NSNumber* counter = (NSNumber*)getMessageKey(desc,@"counter");
                    NSString* messageType = (NSString*)getMessageKey(desc, @"type");

                    NSNumber* firstshowinterval = (NSNumber*)getMessageKey(desc,@"FirstShowInterval");
                    if ([firstshowinterval isKindOfClass:[NSNumber class]] && launchDate)
                    {
                        NSDate* currentDate = [NSDate ism_date];
                        if ([currentDate iSmartNews_calendarIntervalSinceDate:launchDate] < [firstshowinterval unsignedIntegerValue]){
                            iSmartNewsLog(@"FirstShowInterval not reached: %d",(int)([currentDate iSmartNews_calendarIntervalSinceDate:launchDate]));
                            continue;
                        }
                    }
                    
                    extractSmartNewsMessage(desc,message);
                    
                    // -- since version 1.3
                    if (![message objectForKey:iSmartNewsMessageTitleKey] 
                        && ![message objectForKey:iSmartNewsMessageTextKey] )
                    {
                        // special section
                        NSNumber* gate = (NSNumber*)getMessageKey(desc,@"gate");
                        if ([gate isKindOfClass:[NSNumber class]])
                            gate_ = [gate unsignedIntValue];
                        
                        // -- since version 1.4
                        NSArray* queues = (NSArray*)getMessageKey(desc,@"queues");
                        if ([queues isKindOfClass:[NSArray class]])
                        {
                            for (NSDictionary* dict in queues)
                            {
                                NSString* name = (NSString*)getMessageKey(dict,@"name");
                                NSNumber* timeout = (NSNumber*)getMessageKey(dict,@"timeout");
                                
                                if ([name isKindOfClass:[NSString class]]
                                    && [timeout isKindOfClass:[NSNumber class]])
                                {
                                    if ([timeout doubleValue] < 0){
                                        timeout = @(1);
                                    }
                                    else if ([timeout doubleValue] > 1000){
                                        timeout = @(1000);
                                    }
                                    
                                    NSNumber* timeoutRange = (NSNumber*)getMessageKey(dict,@"timeoutRange");
                                    if ([timeoutRange isKindOfClass:[NSNumber class]]){
                                        if ([timeoutRange doubleValue] > 0 &&
                                            [timeoutRange doubleValue] < 1000
                                            ){
                                            const uint32_t b = [timeout unsignedIntValue];
                                            const uint32_t r = [timeoutRange unsignedIntValue];
                                            timeout = @(b + (r << 16));
                                        }
                                    }
                                    
                                    [queuesTimeouts_ setObject:timeout forKey:name];
                                }
                            }
                        }
                        // --
                    }

                    // --                    
                    // new since version 1.2
                    if (counter && [counter isKindOfClass:[NSNumber class]])
                        [message setObject:counter forKey:iSmartNewsMessageCounterKey];
                    // --

                    if (([message objectForKey:iSmartNewsMessageTitleKey] || [message objectForKey:iSmartNewsMessageTextKey])
                        && ![self checkIfMessageWasAlreadyShown:message])
                    {
                        if (!messageType
                            || ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0)
                            || ![messageType isEqualToString:iSmartNewsContentTypeWeb])
                        {
                            [loadedNews_ addObject:message];
                            iSmartNewsLog(@"Message parsed: %@",message);
                        }
                    }
                    else
                    {
                        iSmartNewsLog(@"parse iteration: message skipped, because title, text key were not found or message was already shown");
                    }
                }        
                @catch(...){}
            }
        }
        else{
            iSmartNewsLog(@"Not NSArray object, skipped");
        }
    }
    
    removeOldMeta(self.service, loadedMeta);
    
    // -- since 2.0
    NSArray* meta = metaNews(self.service, events);
    if ([meta count] > 0){
        [loadedNews_ addObjectsFromArray:meta];
    }
    metaReset(self.service);
    dumpMeta(self.service);
    
    // -- since 1.4
    [loadedNews_ sortUsingComparator:^NSComparisonResult(id o1, id o2){
        NSDictionary* m1 = o1;
        NSDictionary* m2 = o2;
        
        NSString* q1 = [m1 objectForKey:iSmartNewsMessageQueueKey];
        NSString* q2 = [m2 objectForKey:iSmartNewsMessageQueueKey];
        
        if (!q1 && !q2)
        {
            return NSOrderedSame;
        }
        else if (!q1 && q2)
        {
            return NSOrderedAscending;
        }
        else if (q1 && !q2)
        {
            return NSOrderedDescending;
        }
        else
        {
            return [q1 caseInsensitiveCompare:q2];
        }
    }];
    iSmartNewsLog(@"NEW SORTED: %@",loadedNews_);
    // --
    
    if ([loadedNews_ count])
    {
        [self showNextMessage];
    }
    else
    {
        [self completeEvent];
        iSmartNewsLog(@"No messages");
    }
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
    const UInt64 counter = [[[self settings] objectForKey:@"counter"] unsignedLongLongValue];
    
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
        
        NSString* title = [description objectForKey:iSmartNewsMessageTitleKey];
        NSString* message = [description objectForKey:iSmartNewsMessageTextKey];            
        NSString* cancel = [description objectForKey:iSmartNewsMessageCancelKey];                        
        NSString* ok = [description objectForKey:iSmartNewsMessageActionKey];
        NSString* url = [description objectForKey:iSmartNewsMessageUrlKey];
        NSString* review = [description objectForKey:iSmartNewsMessageReviewKey];
        
        if ([ok isEqualToString:@"default"]){
            ok = NSLocalizedString(@"OK",);
        }
        
        if ([review isEqualToString:@"default"]){
            review = news_reviewRate();
        }
        
        if (review){
            
            if ([title isEqualToString:@"default"]){
                title = news_reviewTitle();
            }
            
            if ([message isEqualToString:@"default"]){
                message = news_reviewMessage();
            }
        }
        
        if ([cancel isEqualToString:@"default"]){
            cancel = NSLocalizedString(@"Cancel",);
        }
        
        NSString* remind = [description objectForKey:iSmartNewsMessageRemindKey];

        if ([remind isEqualToString:@"default"]){
            remind = news_reviewLater();
        }
        
        NSString* queue = [description objectForKey:iSmartNewsMessageQueueKey];
        if (queue)
        {
            if (!currentQueue_ || ![queue isEqualToString:currentQueue_])
            {
                currentQueue_ = [queue copy];

                NSUInteger nQueued = 0;
                
                for (NSDictionary* m in loadedNews_)
                {
                    NSString* queue = [m objectForKey:iSmartNewsMessageQueueKey];
                    if ([queue isEqualToString:currentQueue_])
                        nQueued++;
                }
                
                NSMutableDictionary* q = [queuesInfo_ objectForKey:@"indexes"];
                if (!q || ![q isKindOfClass:[NSMutableDictionary class]])
                {
                    q = [NSMutableDictionary new];
                    [queuesInfo_ setObject:q forKey:@"indexes"];
                }
                
                NSNumber* n = [q objectForKey:queue];
                if (!n)
                {
                    n = @(0);
                    [q setObject:n forKey:queue];
                }
                
                if ([n unsignedIntValue] >= nQueued)
                {
                    n = @(0);
                    [q setObject:n forKey:queue];
                }
                
                [loadedNews_ removeObjectsInRange:NSMakeRange(0, [n unsignedIntValue])];
                [loadedNews_ removeObjectsInRange:NSMakeRange(1, nQueued - [n unsignedIntValue] - 1)];

                n = @([n unsignedIntValue] + 1);
                [q setObject:n forKey:queue];
                
                [self saveQueuesInfo];
                
                iSmartNewsLog(@"NEXT INDEX %@",n);
                
                NSNumber* timeout = [queuesTimeouts_ objectForKey:queue];
                if (timeout)
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

        if (gCanIShowAlertViewRightNow && !gCanIShowAlertViewRightNow(self)){
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
        
        if ([uuid length] > 0){
            
            SmartNewsItem* metaItem = findMetaItem(self.service, uuid);
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
                        NSManagedObject* metaRangeItem = findMetaRangeItem(serviceName, metaItem,rangeUuid);
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
            _visualizer = [[iSmartNewsVisualizer alloc] initWebViewVisualizerWithURL:[NSURL URLWithString:message]
                                                                 showRemoveAdsButton:showRemoveAdsButton];
        }
        else
        {
            _visualizer = [[iSmartNewsVisualizer alloc] initAlertViewVisualizerWithTitle:title
                                                                                 message:message
                                                                                  cancel:cancel
                                                                                      ok:(url?(ok?ok:NSLocalizedString(@"OK",)):nil)
                                                                                  review:review
                                                                                  remind:remind
                           ];
            
        }
        
        if (!_visualizer){
            continue;
        }

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
        
        if ([description objectForKey:@"minDelay"] && [description objectForKey:@"maxDelay"]){
            _visualizer.delayRange = NSMakeRange([[description objectForKey:@"minDelay"] unsignedIntegerValue],
                                                 [[description objectForKey:@"maxDelay"] unsignedIntegerValue] - [[description objectForKey:@"minDelay"] unsignedIntegerValue]);
        }
        
        _visualizer.metaUUID = uuid;
        _visualizer.iTunesId = self.iTunesId;
        _visualizer.onShow = [description objectForKey:@"onShow"];
        _visualizer.delegate = self;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_visualizer show];
        });

        return;
    }
    
    
    if (!connection_ && ([loadedNews_ count] == 0)){
        [self completeEvent];
    }
}

#pragma mark -

- (void)cancelWasPressed
{
    if (![loadedNews_ count])
        return;
    
    NSDictionary* message = [loadedNews_ objectAtIndex:0];
    
    iSmartNewsLog(@"CANCEL button clicked");
    
    if (![[message objectForKey:iSmartNewsMessageAlwaysKey] boolValue]
        && ![[message objectForKey:iSmartNewsMessageRepeatKey] boolValue])
    {
        [self setCacheValue:message];
    }
    
    [loadedNews_ removeObjectAtIndex:0];
    
    //--
    // new since version 1.3
    if (--gate_ == 0)
    {
        [loadedNews_ removeAllObjects];
        [self completeEvent];
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
        [self setCacheValue:message];
    
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
        [self completeEvent];
        return;
    }
    //--
    
    [self showNextMessage];
}


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
        [self completeEvent];
        return;
    }
    //--
    
    [self showNextMessage];
}

- (void)saveLastShown:(NSString*)uuid condition:(NSString*)condition
{
    if (uuid && ![uuid isEqualToString:@""]){
        
        NSManagedObjectContext* context = managedObjectContext(self.service);
        NSFetchRequest *fetchReq = [[NSFetchRequest alloc] init];
        [fetchReq setEntity:[NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context]];
        [fetchReq setPredicate:[NSPredicate predicateWithFormat:@"uuid == %@",uuid]];
        NSArray* news = [context executeFetchRequest:fetchReq error:NULL];
        
        if ([news count] == 1){
            
            SmartNewsItem* item = [news firstObject];
            [item setLastShown:[NSDate ism_date]];
            
            if ([[item oncePerVersion] boolValue]){
                
                __block BOOL setShownInVersion = YES;
                
                if ([item oncePerVersionCondition]){
                    NSString* conditions = [[item oncePerVersionCondition] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (![conditions isEqualToString:@""]){
                        setShownInVersion = NO;
                        [[conditions componentsSeparatedByString:@"|"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            NSString* itemCondition = [[obj lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            if ([condition isEqualToString:itemCondition]){
                                setShownInVersion = YES;
                                *stop = YES;
                            }
                        }];
                    }
                }
                
                if (setShownInVersion){
                    [item setShownInVersion:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
                }
            }
            
            saveContext(self.service);
        }
    }
}

#pragma mark -
#pragma mark UIAlerViewDelegate

- (void)visualizerDidClickRemoveAds:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    [self saveLastShown:visualizer.metaUUID condition:@"removeads"];
    
    [self resetVisualizerVar];

    NSDictionary* description = [loadedNews_ objectAtIndex:0];
    
    [self nothingWasPressed];
    
    NSString* removeAdsAction = [description objectForKey:@"removeAdsAction"];
    
    if ([[removeAdsAction lowercaseString] isEqualToString:@"app"])
    {
        if (_removeAdsActionBlock)
        {
            void (^removeAdsActionBlock)() = [_removeAdsActionBlock copy];
            
            [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                removeAdsActionBlock();
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            });
        }
    }
    else
    {
        if (removeAdsAction){
            
            if ([removeAdsAction rangeOfString:@"${URL}"].location != NSNotFound){
                if ([visualizer url]){
                    NSCharacterSet *chars = NSCharacterSet.URLQueryAllowedCharacterSet;
                    NSString* encodedString = [[[visualizer url] absoluteString] stringByAddingPercentEncodingWithAllowedCharacters:chars];
                    removeAdsAction = [removeAdsAction stringByReplacingOccurrencesOfString:@"${URL}" withString:encodedString];
                }
                else {
                    removeAdsAction = [removeAdsAction stringByReplacingOccurrencesOfString:@"${URL}" withString:@"alert"];
                }
            }
            
            NSURL* removeAdsUrl = [NSURL URLWithString:removeAdsAction];
            
            if (removeAdsUrl && [[UIApplication sharedApplication] canOpenURL:removeAdsUrl]){
                [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] openURL:removeAdsUrl];
                    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                });
            }
        }
    }
}

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
    
    [self saveLastShown:visualizer.metaUUID condition:@"cancel"];
    
    [self resetVisualizerVar];
    
    [self nothingWasPressed];
}

- (void)visualizerDidClickCancel:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    [self saveLastShown:visualizer.metaUUID condition:@"cancel"];
    
    [self resetVisualizerVar];
    
    [self cancelWasPressed];
}

- (void)visualizerDidClickOk:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    [self saveLastShown:visualizer.metaUUID condition:@"ok"];
    
    [self resetVisualizerVar];
    
    [self actionWasPressed];
}

- (void)visualizerDidClickOpenReview:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    [self saveLastShown:visualizer.metaUUID condition:@"review"];
    
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
    
    [self saveLastShown:visualizer.metaUUID condition:@"cancel"];
    
    [self resetVisualizerVar];
    
    [self nothingWasPressed];
}

- (void)visualizerDidClickRemindLaterReview:(iSmartNewsVisualizer*)visualizer
{
    if (![loadedNews_ count])
        return;
    
    if (visualizer != _visualizer)
        return;
    
    [self saveLastShown:visualizer.metaUUID condition:@"remind"];
    
    [self resetVisualizerVar];
    
    [self nothingWasPressed];
}

#pragma mark -
#pragma mark Properties

- (NSURL*)preprocessURL:(NSURL*)url{
#if DEBUG || ADHOC
    OriginalURL = [url copy];
    if (OriginalURL){
        if ([GetDebugURLPostFix() length] > 0){
            NSURLComponents* urlComponents = [[NSURLComponents alloc] initWithString:[OriginalURL absoluteString]];
            NSString* path = [urlComponents path];
            NSString* parent = [path stringByDeletingLastPathComponent];
            NSString* lastComponent = [path lastPathComponent];
            NSString* extension = [lastComponent pathExtension];
            if (extension){
                NSString* pureName = [lastComponent stringByDeletingPathExtension];
                [urlComponents setPath:[parent stringByAppendingPathComponent:[[pureName stringByAppendingFormat:@"_%@",GetDebugURLPostFix()] stringByAppendingPathExtension:extension]]];
            }
            else {
                [urlComponents setPath:[parent stringByAppendingPathComponent:[lastComponent stringByAppendingFormat:@"_%@",GetDebugURLPostFix()]]];
            }
            url = [urlComponents URL];
        }
    }
#endif
    return url;
}

- (void)setUrl:(NSURL *)url
{
    iSmartNewsMainThread;
    
    iSmartNewsLog(@"setUrl: %@",url);

    url = [self preprocessURL:url];
    
    if ([[url absoluteString] isEqualToString:[_url absoluteString]])
        return;
    
    _url = [url copy];
    
    NSString* urlsMD5 = [queuesInfo_ objectForKey:@"URLS"];
    NSString* currentMd5 = md5ForArray(_url?@[[_url absoluteString]]:nil);
    
    if (![urlsMD5 isEqualToString:currentMd5])
    {
        NSString* path = [self queuesInfoSavePath];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
            queuesInfo_ = [NSMutableDictionary new];
        }
    }
    
    [queuesInfo_ setObject:md5ForArray(_url?@[[_url absoluteString]]:nil) forKey:@"URLS"];
    [self saveQueuesInfo];
}

#pragma mark -
#pragma mark NSURLConnection delegate

- (BOOL)connection:(NSURLConnection* )connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace* )protectionSpace
{
    if (connection != connection_){
        return NO;
    }
    
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection* )connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge* )challenge
{
    if (connection != connection_){
        return;
    }
    
    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (connection != connection_){
        return;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (connection != connection_){
        return;
    }
    
    NSMutableData* buffer = objc_getAssociatedObject(connection, &connectionDataKey);
    if (!buffer)
    {
        buffer = [NSMutableData new];
        objc_setAssociatedObject(connection, &connectionDataKey, buffer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
	[buffer appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (connection != connection_){
        return;
    }
    
    iSmartNewsLog(@"Connection did fail %@",[error localizedDescription]);
    
    const BOOL emulateAppActivate = [objc_getAssociatedObject(connection_, &emulateAppActivateKey) boolValue];
    
    connection_ = nil;
    objc_setAssociatedObject(connection, &connectionDataKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (_updateBgTaskId != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:_updateBgTaskId];
        _updateBgTaskId = UIBackgroundTaskInvalid;
    }
    
    if (emulateAppActivate){
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive){
            if (sn_AppUpgradeDone()){
                [[iSmartEventsCenter sharedCenter] postEvent:iSmartEventsCenterAppDidFinishLaunchingAfterUpgradeEvent];
            }
            else {
                [[iSmartEventsCenter sharedCenter] postEvent:iSmartEventsCenterAppDidFinishLaunchingEvent];
            }
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (connection != connection_){
        return;
    }
    
    iSmartNewsLog(@"Connection did finish loading");
    
    NSMutableData* buffer = objc_getAssociatedObject(connection, &connectionDataKey);
    objc_setAssociatedObject(connection, &connectionDataKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    _currentNews = [buffer copy];
    
    const BOOL emulateAppActivate = [objc_getAssociatedObject(connection_, &emulateAppActivateKey) boolValue];

    connection_ = nil;
    
    NSString* header = [[NSString alloc] initWithData:_currentNews encoding:NSUTF8StringEncoding];
    
    [self parseEvents:_currentNews];
    
    metaReset(self.service);
    
    if (_updateBgTaskId != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:_updateBgTaskId];
        _updateBgTaskId = UIBackgroundTaskInvalid;
    }
    
    if (emulateAppActivate){
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive){
            if (sn_AppUpgradeDone()){
                [[iSmartEventsCenter sharedCenter] postEvent:iSmartEventsCenterAppDidFinishLaunchingAfterUpgradeEvent];
            }
            else {
                [[iSmartEventsCenter sharedCenter] postEvent:iSmartEventsCenterAppDidFinishLaunchingEvent];
            }
        }
    }
}

- (void)showForActiveEvents:(NSArray*)events
{
    [self parse:_currentNews events:events];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    iSmartNewsLog(@"willCacheResponse: return nil");
    return nil;
}

#pragma mark - Queues support

- (NSString*)queuesInfoSavePath
{
    if ([self.service isEqualToString:@"news"]){
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:@"iSmartNewsQueuesSettings.plist"];
    }
    else {
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:[@"iSmartNewsQueuesSettings" stringByAppendingFormat:@"_%@.plist",self.service]];
    }
}

- (void)loadQueuesInfo
{
    NSString* path = [self queuesInfoSavePath];
    queuesInfo_ = [[NSDictionary dictionaryWithContentsOfFile:path] mutableCopy];
    if (!queuesInfo_ || ![[queuesInfo_ objectForKey:@"URLS"] isKindOfClass:[NSString class]])
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        }
        
        queuesInfo_ = [NSMutableDictionary new];
    }
    else
    {
        NSString* urlsMD5 = [queuesInfo_ objectForKey:@"URLS"];
        NSString* currentMd5 = md5ForArray( _url?@[[_url absoluteString]]:nil);
        
        if (![urlsMD5 isEqualToString:currentMd5])
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
            }
            queuesInfo_ = [NSMutableDictionary new];
        }
    }
}

- (void)saveQueuesInfo
{
    if (!_url)
        return;
    
    NSString* path = [self queuesInfoSavePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    
    [queuesInfo_ writeToFile:path atomically:YES];
}

#pragma mark -

- (void)incrementCounter {
    const UInt64 counter = [[[self settings] objectForKey:@"counter"] unsignedLongLongValue];
    [[self settings] setObject:[NSNumber numberWithUnsignedLongLong:(counter + 1)] forKey:@"counter"];
    [self save];
}

- (void)UIApplicationWillResignActiveNotification{
    UIApplicationWillResignActiveNotificationDone = YES;
}

- (void)UIApplicationDidEnterBackgroundNotification {
    [self _update:NO];
    [self clearAndHideAlert];
}

- (void)UIApplicationWillEnterForegroundNotification {
    metaReset(self.service);
    [self _update:NO];
    [self incrementCounter];
}

- (void)UIApplicationDidFinishLaunchingNotification {
    if (![[[self settings] objectForKey:@"launchDate"] isKindOfClass:[NSDate class]]){
        [[self settings] setObject:[NSDate ism_date] forKey:@"launchDate"];
        [self save];
    }
    [self _update:YES];
    [self incrementCounter];
}

#if DEBUG || ADHOC
static NSString* GetDebugURLPostFix()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DebugURLPostFix = [[NSUserDefaults standardUserDefaults] stringForKey:@"news.debug.postfix"];
    });
    return DebugURLPostFix;
}
#endif//#if DEBUG || ADHOC

- (void)UIApplicationDidBecomeActiveNotification{
    metaReset(self.service);
}

- (void)setRemoveAdsActionBlock:(void(^)())block{
    _removeAdsActionBlock = [block copy];
}

+ (NSString*)versionString{
    return iSmartNewsVersion;
}

+ (void)load
{
    SwizzleInstanceMethod([UIApplication class], @selector(setStatusBarHidden:animated:),@selector(iSmartNews_setStatusBarHidden:animated:));
    SwizzleInstanceMethod([UIApplication class], @selector(setStatusBarHidden:withAnimation:),@selector(iSmartNews_setStatusBarHidden:withAnimation:));
    SwizzleInstanceMethod([UIApplication class], @selector(isStatusBarHidden),@selector(iSmartNews_isStatusBarHidden));
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews] UIApplicationDidEnterBackgroundNotification];
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews] UIApplicationDidFinishLaunchingNotification];
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews] UIApplicationWillEnterForegroundNotification];
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews] UIApplicationWillResignActiveNotification];
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews] UIApplicationDidBecomeActiveNotification];
                                                  }];
    
}

#if DEBUG || ADHOC
- (void)showSingleWebTestMessage{
    
    NSData* data = [[NSString stringWithFormat:
                     @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                     @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
                     @"<plist version=\"1.0\">"
                     @"<array>"
                     @"<dict>"
                     @"<key>gate</key>"
                     @"<integer>20</integer>"
                     @"</dict>"
                     @"<dict>"
                     @"<key>type</key>"
                     @"<string>web</string>"
                     @"<key>start</key>"
                     @"<date>2011-10-03T19:30:42Z</date>"
                     @"<key>end</key>"
                     @"<date>2017-10-05T19:30:44Z</date>"
                     @"<key>title</key>"
                     @"<string>%@</string>"
                     @"<key>text</key>"
                     @"<string>http://google.com</string>"
                     @"<key>text_ru</key>"
                     @"<string>http://google.com.ru</string>"
                     @"<key>repeat</key>"
                     @"<true/>"
                     @"<key>counter</key>"
                     @"<integer>1</integer>"
                     @"<key>always</key>"
                     @"<true/>"
                     @"</dict>"
                     @"</array>"
                     @"</plist>",[@(arc4random()) stringValue]]
                    dataUsingEncoding:NSUTF8StringEncoding];
    
    [self parse:data events:nil];
}
- (void)showTestMessage{
    NSData* data = [[NSString stringWithFormat:
                            @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                            @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
                            @"<plist version=\"1.0\">"
                            @"<array>"
                            @"<dict>"
                            @"<key>gate</key>"
                            @"<integer>20</integer>"
                            @"</dict>"
                            @"<dict>"
                            @"<key>cancel</key>"
                            @"<string>cancel</string>"
                            @"<key>start</key>"
                            @"<date>2011-10-03T19:30:42Z</date>"
                            @"<key>end</key>"
                            @"<date>2017-10-05T19:30:44Z</date>"
                            @"<key>link</key>"
                            @"<string>http://google.com</string>"
                            @"<key>link_PT_pt_768x1024</key>"
                            @"<string>http://google.com</string>"
                            @"<key>ok</key>"
                            @"<string>open url</string>"
                            @"<key>text</key>"
                            @"<string>Some very very very very very very very very very very very very very very very very very very very very very very very very very very very very very very very very very very very long message!%@</string>"
                            @"<key>text_ru</key>"
                            @"<string>Простое и длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное длинное сообщение!</string>"
                            @"<key>title</key>"
                            @"<string>title</string>"
                            @"<key>repeat</key>"
                            @"<true/>"
                            @"<key>counter</key>"
                            @"<integer>1</integer>"
                            @"<key>always</key>"
                            @"<true/>"
                            @"</dict>"
                            @"<dict>"
                            @"<key>type</key>"
                            @"<string>web</string>"
                            @"<key>start</key>"
                            @"<date>2011-10-03T19:30:42Z</date>"
                            @"<key>end</key>"
                            @"<date>2017-10-05T19:30:44Z</date>"
                            @"<key>text</key>"
                            @"<string>http://google.com</string>"
                            @"<key>text_ru</key>"
                            @"<string>http://google.com.ru</string>"
                            @"<key>repeat</key>"
                            @"<true/>"
                            @"<key>counter</key>"
                            @"<integer>1</integer>"
                            @"<key>always</key>"
                            @"<true/>"
                            @"</dict>"
                            @"</array>"
                            @"</plist>",[@(arc4random()) stringValue]]
                           dataUsingEncoding:NSUTF8StringEncoding];
    [self parse:data events:nil];
}
#endif

@end
