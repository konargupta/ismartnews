/*!
 @file       iSmartNews.m
 */

#import "iSmartNews.h"
#include <stdio.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#import <StoreKit/StoreKit.h>

#import "iSmartEventsCenter.h"
#import "iSmartNewsVisualizer.h"
#import "iSmartNewsDisplayList.h"
#import "iSmartNewsEmbeddedPanel.h"


#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#pragma clang diagnostic ignored "-Wnullability-completeness"

#import "iSmartNewsInternal.h"

#ifdef SMARTNEWS_COMPILE
# if !ISMARTNEWS_DEMO
#  undef  SMARTNEWS_COMPILE
#  define SMARTNEWS_COMPILE     (0)
# endif
#else
# define SMARTNEWS_COMPILE      (1)
#endif

#pragma mark - Submodules

#if !defined(ISMART_EVENT_CENTER_VERSION) || !defined(ISMART_EVENT_CENTER_VERSION_1_1_2) || (ISMART_EVENT_CENTER_VERSION < ISMART_EVENT_CENTER_VERSION_1_1_2)
#error Your version of iSmartEventCenter is outdated. Please update iSmartEventCenter submodule
#endif

#pragma mark -


NSString* const iSmartNewsUserDidOpenReviewNotification     = @"ISNUDORN27346";
NSString* const iSmartNewsDidOpenCallbackNotification       = @"ISNDOCBNF96735026";

NSString* const iSmartNewsDidShowNewsItemNotification       = @"ISNDSNSN77866876";
NSString* const iSmartNewsDidCloseNewsItemNotification      = @"ISNDCNIN2837598423";

static BOOL UIApplicationWillResignActiveNotificationDone = NO;
//static const char emulateAppActivateKey;
//static const char connectionDataKey;

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

extern NSString*  const  iSmartNewsMessageReviewTypeKey;

static const char iSmartNews_hideStatusbar_originalKey;
static const char iSmartNews_hideStatusbarKey;



EXTERN_OR_STATIC INLINE_INTERNAL_ATTRIBUTES NSString* _str_i_smrt()
{
    return @"iSmart";
}

EXTERN_OR_STATIC INLINE_INTERNAL_ATTRIBUTES NSString* _str_i_smrt_news()
{
    return @"iSmartNews";
}


/*! @cond SkipThis
 ----------------------------------------------------------------------------
 */
@class iSmartNewsPopupViewController;

@interface iSmartNews() <iSmartNewsDisplayListDelegate, iSmartNewsEmbeddedPanelDelegate, iSmartNewsUpdaterDelegate>
@property (nonatomic, copy) iSmartEventsCenterCallbackCompletion eventsCenterCompletion;
@end
/*! ----------------------------------------------------------------------------
 @endcond
 */

#import "iSmartNewsCoreData.h"
#import "iSmartNewsUtils.h"
#import "iSmartNewsMeta.h"
//#import "iSmartNewsPopupNavigationController.h"
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
#import "iSmartNewsLocalization.h"
#import "iSmartNewsSegment.h"
#import "iSmartNewsActions.h"

#import "iSmartNewsUpdate.h"

#if SMARTNEWS_COMPILE
#import "iSmartNewsCoreData.m"
#import "iSmartNewsUtils.m"
#import "iSmartNewsMeta.m"
//#import "iSmartNewsPopupNavigationController.m"
#import "iSmartNews+UIApplication.m"
#import "iSmartNewsModalPanel.m"
#import "iSmartNewsEmbeddedPanel.m"
#import "iSmartNewsRoundedRectView.m"
#import "iSmartNewsImages.m"
#import "iSmartNewsPopupViewController.m"
#import "iSmartNewsWindow.m"
#import "iSmartNewsVisualizer.m"
#import "iSmartNewsZip.m"
#import "iSmartNewsEvents.m"
#import "iSmartNewsDate.m"
#import "iSmartNewsLocalization.m"
#import "iSmartNewsSegment.m"
#import "iSmartNewsDisplayList.m"
#import "iSmartNewsQueuesInfo.m"
#import "iSmartNewsActions.m"

#import "iSmartNewsUpdate.m"
#endif

#import <CommonCrypto/CommonDigest.h>

#import "iSmartNewsInternal.h"

static iSmartNewsAllowBlock gCanIShowAlertViewRightNow = nil;
static iSmartNewsAllowBlock g_fetchHandler = nil;

NSString*  const  iSmartNewsMessageTitleKey     = @"iSmartNewsMessageTitleKey";         //  NSString, message title
NSString*  const  iSmartNewsMessageTextKey      = @"iSmartNewsMessageTextKey";          //  NSString, message text
NSString*  const  iSmartNewsMessageCancelKey    = @"iSmartNewsMessageCancelKey";        //  NSString, title for 'cancel' button
NSString*  const  iSmartNewsMessageActionKey    = @"iSmartNewsMessageActionKey";        //  NSString, title for 'ok' button
NSString*  const  iSmartNewsMessageReviewKey    = @"iSmartNewsMessageReviewKey";
NSString*  const  iSmartNewsMessageRemindKey    = @"iSmartNewsMessageRemindKey";

NSString*  const  iSmartNewsMessageReviewTypeKey = @"iSmartNewsMessageReviewTypeKey";   //Native ReviewAlert or openURL

NSString*  const  iSmartNewsMessageUrlKey       = @"iSmartNewsMessageUrlKey";           //  NSString, url to open if 'ok' was pressed
NSString*  const  iSmartNewsMessageStartDateKey = @"iSmartNewsMessageStartDateKey";     //  NSDate
NSString*  const  iSmartNewsMessageEndDateKey   = @"iSmartNewsMessageEndDateKey";       //  NSDate
NSString*  const  iSmartNewsMessageRepeatKey    = @"iSmartNewsMessageRepeatKey";        //  NSNumber (as bool)
NSString*  const  iSmartNewsMessageAlwaysKey    = @"iSmartNewsMessageAlwaysKey";        //  NSNumber (as bool)
NSString*  const  iSmartNewsMessageCounterKey   = @"iSmartNewsMessageCounterKey";       //  NSNumber
NSString*  const  iSmartNewsMessageQueueKey     = @"iSmartNewsMessageQueueKey";         //  NSString, name of queue

NSString*  const iSmartNewsMessageTypeKey       = @"iSmartNewsMessageTypeKey";          //  NSString, type of message. "web" for web content
NSString*  const iSmartNewsContentTypeWeb       = @"web";

@implementation iSmartNews
{
    iSmartNewsUpdater* _updater;
    
    //UIBackgroundTaskIdentifier _updateBgTaskId;
    //NSURLConnection*        connection_;
    
    iSmartNewsDisplayList* _mainDisplayList;
    
    NSData* _currentNews;

    NSMutableDictionary* _settings;

    void (^_removeAdsActionBlock)();
    
    BOOL _advIsOnScreen;
    NSTimer* _advIsOnScreenWatchDogTimer;
    
    NSMutableSet*        _embeddedPanelsEvents;
    NSMutableDictionary* _embeddedPanels;
    
    BOOL _dispatchForceUpdateIfEmpty;
    
    BOOL _integratedWithEventCenter;
}

static NSMutableDictionary* services = nil;

#pragma mark - Init
/*! @brief Contructor */
- (id)initWithServiceName:(NSString*)serviceName
{
    self = [super init];
    
    if ( self )
    {
        [iSmartNewsActions sharedInstance];
        
        _service = [serviceName copy];
        
        //Config insance
        
        if ([_service isEqualToString:@"news"])
        {
            _integratedWithEventCenter = YES;
        }
        else if ([_service isEqualToString:@"customadv"])
        {
            _dispatchForceUpdateIfEmpty = YES;
        }
        
        __weak iSmartNews* wSelf = self;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(advWillShow) name:@"iSmartAdvertisingWillShowFullscreenBannerNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(advDidHide)  name:@"iSmartAdvertisingDidHideFullscreenBannerNotification" object:nil];
        
        _embeddedPanelsEvents = [NSMutableSet new];
        _embeddedPanels       = [NSMutableDictionary new];
        
        if (_integratedWithEventCenter)
        {
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
                                                          
                                                          NSArray* applicableEvents = [this fetchEventsWithNames:@[event] applyPattern:NO];
                                        
                                                          if (([applicableEvents count] == 0) && [event isEqualToString:iSmartEventsCenterAppActivateEvent])
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
                                                          
                                                          NSArray* activeEvents = [this fetchEventsWithNames:@[event] applyPattern:YES];
                                                          
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
        }
        
        [self settings];// load
        
        if (![[[self settings] objectForKey:@"launchDate"] isKindOfClass:[NSDate class]]){
            [[self settings] setObject:[NSDate ism_date] forKey:@"launchDate"];
            [self save];
        }
        
        [[iSmartNewsQueuesInfo queuesInfoForService:[self service]] loadQueuesInfo];
        //[self loadQueuesInfo];
        _mainDisplayList = [iSmartNewsDisplayList new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UIWindowDidBecomeKeyNotification) name:UIWindowDidBecomeKeyNotification object:nil];
        
        if (!services)
        {
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

-(NSArray*) fetchEventsWithNames:(NSArray*) names applyPattern:(BOOL) applyPattern
{
    NSManagedObjectContext* context = managedObjectContext([self service]);
    
    NSEntityDescription* entity = [NSEntityDescription entityForName:@"SmartNewsEvent" inManagedObjectContext:context];
    
    NSFetchRequest* fetchAllRequest = [[NSFetchRequest alloc] init];
    [fetchAllRequest setEntity:entity];
    [fetchAllRequest setPredicate:[NSPredicate predicateWithValue:YES]];

    NSArray* allEvents = [context executeFetchRequest:fetchAllRequest error:NULL];
    
    if ([allEvents count] == 0)
    {
        return nil;
    }
    
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    
    if ([names count] > 1)
    {
        NSMutableArray* subpredicates = [NSMutableArray new];
        for (NSString* name in names)
        {
            NSPredicate* subpredicate = [NSPredicate predicateWithFormat:@"name ==[c] %@", name];
            [subpredicates addObject:subpredicate];
        }
        NSPredicate* finalPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:subpredicates];
        
        [fetchRequest setPredicate:finalPredicate];
    }
    else
    {
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"name ==[c] %@", [names firstObject]]];
    }
    
    NSError* error = nil;
    NSMutableArray* matchedEvents = [[context executeFetchRequest:fetchRequest error:&error] mutableCopy];
    if (!matchedEvents || [matchedEvents count] == 0)
    {
        return nil;
    }
    
    NSMutableArray* activeEvents = [NSMutableArray new];
    
    if (applyPattern)
    {
        for (SmartNewsEvent* eventObj in matchedEvents)
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
                
                do
                {
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
    }
    else
    {
        [activeEvents addObjectsFromArray:matchedEvents];
    }
    
    saveContext(self.service);
    
    return activeEvents;
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
    
    sn_evenShownNewsClearForService(self.service);
    
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
    sn_detectUpgrade(YES);
}


- (void)UIWindowDidBecomeKeyNotification
{
}

/*! @brief Destructor */
- (void)dealloc
{
    [self save];
    
    [_updater cancel];
    _updater.delegate = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Intergation
+ (void)setCanIShowAlertViewRightNowHandler:(iSmartNewsAllowBlock)CanIShowAlertViewRightNow
{
    gCanIShowAlertViewRightNow = [CanIShowAlertViewRightNow copy];
}

+ (void)setAllowFetchHandler:(iSmartNewsAllowBlock)fetchHandler
{
    g_fetchHandler = [fetchHandler copy];
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

- (void)setRemoveAdsActionBlock:(void(^)())block{
    _removeAdsActionBlock = [block copy];
}

+ (NSString*)versionString{
    return iSmartNewsVersion;
}

- (void)markReviewAsShown
{
    NSManagedObjectContext* context = managedObjectContext(self.service);
    NSFetchRequest *fetchReq = [[NSFetchRequest alloc] init];
    [fetchReq setEntity:[NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context]];
    [fetchReq setPredicate:[NSPredicate predicateWithFormat:@"uuid == %@",@"review"]];
    NSArray* news = [context executeFetchRequest:fetchReq error:NULL];
    if ([news count] > 0) {
        SmartNewsItem* item = [news firstObject];
        [self saveLastShown:item.uuid condition:@"review"];
    }
}

- (void)openReview
{
    [self sendSpecialEventForShowReviewItem];
}

- (void)sendSpecialEventForShowReviewItem
{
    if (_integratedWithEventCenter)
    {
        [[iSmartEventsCenter sharedCenter] postEvent:@"review:show_review_manually"];
    }
#if DEBUG || ADHOC
    else
    {
        assert(0 && "Use SharedNews instance");
    }
#endif
}

- (void)openReviewUrl
{
    [self openReviewWithType:nil];
}

- (void)openReviewWithType:(NSString*) type
{
    NSDictionary* additionalInfo = ([type length] > 0) ? @{@"reviewType" : type} : nil;
    [[iSmartNewsActions sharedInstance] performAction:iSmartNewsActionReviewOpen item:nil additionalInfo:additionalInfo completionHandler:nil];
}

-(void)setITunesId:(NSString *)iTunesId
{
    _iTunesId = iTunesId;
    [[iSmartNewsActions sharedInstance] setITunesId:iTunesId];
}

#pragma mark -
#pragma mark Embedded

-(UIView<iSmartNewsPanelProtocol>*) getEmbeddedPanelForEvents:(NSArray*) events error:(NSError**) error
{
    NSSet* eventsSet = [NSSet setWithArray:events];
    
    if ([_embeddedPanelsEvents intersectsSet:eventsSet])
    {
        NSLog(@"Events are used");
        return nil;
    }
    
    [_embeddedPanelsEvents addObjectsFromArray:events];
    
    iSmartNewsEmbeddedPanel* panel = [[iSmartNewsEmbeddedPanel alloc] initWithFrame:CGRectMake(0, 0, 320, 290)];
    [self refreshAssignedPanel:panel];
    
    [panel assignUUID:[[NSUUID new] UUIDString]];
    [_embeddedPanels setObject:panel forKey:[panel uuid]];
    
    [panel startRotationWithEvents:events];
    
    return panel;
}

-(BOOL) kickEmbeddedPanelWithUUID:(NSString*) uuid
{
    iSmartNewsEmbeddedPanel* panel = [_embeddedPanels objectForKey:uuid];
    
    if (panel)
    {
        [panel setActive:NO];
        
        for (NSString* event in [panel rotationEvents])
        {
            [_embeddedPanelsEvents removeObject:event];
        }
        
        [_embeddedPanels removeObjectForKey:uuid];
        [panel removeFromSuperview];
        panel = nil;
        
        return YES;
    }
    
    return NO;
}

-(void)refreshAssignedPanel:(iSmartNewsEmbeddedPanel *)panel
{
    panel.internalDelegate = self;
    panel.iTunesId = self.iTunesId;
    panel.service = self.service;
}

-(void)panelDidCompleteShown:(iSmartNewsEmbeddedPanel *)panel
{
    [self loadForEmbededPanel:panel];
}

#pragma mark -
#pragma mark DisplayList

-(void)displayListWasEnded:(iSmartNewsDisplayList *)displayList
{
    if (displayList == _mainDisplayList)
    {
        [self completeEvent];
    }
}

-(BOOL)displayListCanShowAlertView:(iSmartNewsDisplayList *)displayList
{
    if (gCanIShowAlertViewRightNow)
    {
        return gCanIShowAlertViewRightNow(self);
    }
    else
    {
        return YES;
    }
}

-(UInt64)displayListGetCounterValue:(iSmartNewsDisplayList *)displayList
{
    assert(_mainDisplayList == displayList);
    
    UInt64 counter = [[[self settings] objectForKey:@"counter"] unsignedLongLongValue];
    
    return counter;
}

-(iSmartNewsSaveLastShowResult) displayList:(iSmartNewsDisplayList*) displayList markItemIsShown:(NSDictionary*) item info:(NSDictionary*) info
{
    NSString* uuid = [item objectForKey:@"uuid"];
    BOOL isMessage = [[info objectForKey:@"isMessage"] boolValue];
    
    NSString* condition = [info objectForKey:@"condition"];

    //Meta item
    if (([uuid length] > 0) && (isMessage == NO))
    {
        return [self saveLastShown:uuid condition:condition];
    }
    else
    {
        [self setCacheValue:item];
        return iSmartNewsLastShowSavedSuccessfully;
    }
}

-(void)displayListWasAssignedNewMessages:(iSmartNewsDisplayList *)displayList
{
    
}

#pragma mark Actions
-(void)displayList:(iSmartNewsDisplayList *)displayList performAction:(iSmartNewsDisplayAction)action item:(NSObject *)item
{
    switch (action)
    {
        case iSmartNewsDisplayActionRemoveAdsBasic:
        {
            if ([item isKindOfClass:[NSDictionary class]])
            {
                NSString* removeAdsAction = [(NSDictionary*)item objectForKey:@"removeAdsAction"];
                
                if ([removeAdsAction rangeOfString:@"${URL}"].location != NSNotFound)
                {
                    NSURL* visualizerURL = [[displayList visualizer] url];
                    if (visualizerURL)
                    {
                        NSCharacterSet *chars = NSCharacterSet.URLQueryAllowedCharacterSet;
                        NSString* encodedString = [[visualizerURL absoluteString] stringByAddingPercentEncodingWithAllowedCharacters:chars];
                        removeAdsAction = [removeAdsAction stringByReplacingOccurrencesOfString:@"${URL}" withString:encodedString];
                    }
                    else
                    {
                        removeAdsAction = [removeAdsAction stringByReplacingOccurrencesOfString:@"${URL}" withString:@"alert"];
                    }
                }
                
                NSURL* removeAdsUrl = [NSURL URLWithString:removeAdsAction];
                
                if (removeAdsUrl && [[UIApplication sharedApplication] canOpenURL:removeAdsUrl])
                {
                    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [[UIApplication sharedApplication] openURL:removeAdsUrl];
                        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                    });
                }
            }
        }
        break;
            
        case iSmartNewsDisplayActionRemoveAdsApplication:
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
        break;
            
        default:
            break;
    }
}

#pragma mark -
#pragma mark - Start Show
- (void)loadForEmbededPanel:(iSmartNewsEmbeddedPanel*)panel
{
    [self refreshAssignedPanel:panel];
    
    NSArray* activeEventNames = nil;
    
    NSString* activeEvent = [panel currentEvent];
    if (activeEvent != nil)
    {
        activeEventNames = @[activeEvent];
    }
    
    if ([activeEventNames count] == 0)
        return;
    
    NSArray* events = [self fetchEventsWithNames:activeEventNames applyPattern:YES];
    
    if (events == nil)
    {
        [panel setIsReady:NO];
        
        if (_dispatchForceUpdateIfEmpty)
        {
            [self forceUpdate];
        }
    }
    else
    {
        [self parse:_currentNews events:events forDisplayList:[panel displayList]];
    }
}

- (void)showForActiveEvents:(NSArray*)events
{
    [self parse:_currentNews events:events];
}

#pragma mark -
#pragma mark Logic

- (BOOL)pumpUrls:(BOOL)emulateAppActivate
{
    assert(![_updater isActive]);
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
                                         timeoutInterval:10.0f];
    if (!request)
    {
        return NO;
    }
    
    if (!_updater)
    {
        _updater = [[iSmartNewsUpdater alloc] init];
    }
    
    _updater.delegate = self;
    [_updater beginUpdateWithURLRequest:request userInfo:@{@"emulateAppActivate" : @(emulateAppActivate)}];
    
    if ([_updater isActive] == NO)
    {
        return NO;
    }

    return YES;
}

- (void)completeEvent
{
    if (_integratedWithEventCenter && self.eventsCenterCompletion)
    {
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

- (void)_updateWithEmuAppActivate:(BOOL)emulateAppActivate
{
    iSmartNewsMainThread;
    
    if (!sn_allowUpdate())
    {
        return;
    }
    
    if (g_fetchHandler && !g_fetchHandler(self)){
        return;
    }
    
    iSmartNewsLog(@"Update called");
    
    if ([_updater isActive])
    {
        [_updater cancel];
        
        iSmartNewsLog(@"Previous connection canceled");
    }
    
    [self pumpUrls:emulateAppActivate];
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
     
        sn_preprocessMeta(self.service, origNews,loadedMeta);
        
        preprocessEvents(self.service, origNews);
        [[iSmartNewsSegment sharedSegment] preprocess:origNews];
    }
}

- (NSArray*)newsFromData:(NSData*)data
{
    NSString* _ism_tmpf = [NSString stringWithFormat:@"%@%@", _str_i_smrt_news(), @"TempFile"];
#if DEBUG
    assert([@"iSmartNewsTempFile" isEqualToString:_ism_tmpf]);
#endif
    
    NSString* tmpFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[_ism_tmpf stringByAppendingFormat:@"_%@.tmp",[self service]]];
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
    _mainDisplayList.delegate = self;
    _mainDisplayList.service  = [self service];
    
    [self parse:newData events:events forDisplayList:_mainDisplayList];
}

- (void)parse:(NSData*)newData events:(NSArray*)events forDisplayList:(iSmartNewsDisplayList*) displayList
{
    if (!newData){
        [self completeEvent];
        iSmartNewsLog(@"No data loaded");
        
        if (_dispatchForceUpdateIfEmpty)
        {
            [self forceUpdate];
        }
        return;
    }

    NSMutableArray*      n_loadedNews     = [NSMutableArray new];
    NSMutableDictionary* n_queuesTimeouts = [NSMutableDictionary new];
    NSNumber* n_gate = nil;
    
    NSMutableSet* loadedMeta = [NSMutableSet new];
    
    sn_cleanMessageKeysCache();
    
    NSDate*  launchDate = [self launchDate];
    
    if ([newData length])
    {
        NSArray* origNews = [self newsFromData:newData];
        
        if ([origNews isKindOfClass:[NSArray class]])
        {
            NSArray* news = sn_preprocessMeta(self.service, origNews,loadedMeta);
            preprocessEvents(self.service, origNews);
            [[iSmartNewsSegment sharedSegment] preprocess:origNews];
            
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
                            n_gate = [NSNumber numberWithUnsignedInteger:[gate unsignedIntegerValue]];
                        
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
                                    
                                    [n_queuesTimeouts setObject:timeout forKey:name];
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
                            [n_loadedNews addObject:message];
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
    
    sn_removeOldMeta(self.service, loadedMeta);
    
    // -- since 2.0
    NSArray* meta = sn_metaNews(self.service, events);
    if ([meta count] > 0){
        [n_loadedNews addObjectsFromArray:meta];
    }
    sn_metaReset(self.service);
    
    // -- since 1.4
    [n_loadedNews sortUsingComparator:^NSComparisonResult(id o1, id o2){
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
    iSmartNewsLog(@"NEW SORTED: %@",n_loadedNews);
    // --
    
    if ([n_loadedNews count])
    {
        NSMutableDictionary* enveronment = [NSMutableDictionary new];
        if ([n_queuesTimeouts count] > 0)
        {
            [enveronment setObject:n_queuesTimeouts forKey:@"queuesTimeouts"];
        }
        
        if (n_gate != nil)
        {
            [enveronment setObject:n_gate forKey:@"gate"];
        }
        
        [displayList assignNews:n_loadedNews enveronment:enveronment];
        [displayList showNextMessage];
    }
    else
    {
        [self completeEvent];
        iSmartNewsLog(@"No messages");
    }
}

#pragma mark - Mark And Check Shown -
#pragma mark Meta News
- (iSmartNewsSaveLastShowResult)saveLastShown:(NSString*)uuid condition:(NSString*)condition
{
    iSmartNewsSaveLastShowResult result = iSmartNewsLastShowItemNotFound;
    
    if (uuid && ![uuid isEqualToString:@""]){
        
        NSManagedObjectContext* context = managedObjectContext(self.service);
        NSFetchRequest *fetchReq = [[NSFetchRequest alloc] init];
        [fetchReq setEntity:[NSEntityDescription entityForName:@"SmartNewsItem" inManagedObjectContext:context]];
        [fetchReq setPredicate:[NSPredicate predicateWithFormat:@"uuid == %@",uuid]];
        NSArray* news = [context executeFetchRequest:fetchReq error:NULL];
        
        if ([news count] == 1){
            
            result = iSmartNewsLastShowConditionNotFound; //Not ItemNotFound
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
                    [item setShownInVersionCondition:condition];
                    result = iSmartNewsLastShowSavedSuccessfully;
                }
            }
            else if ([[item oncePerInstall] boolValue]){
                
                __block BOOL setShownPerInstall = YES;
                
                if ([item oncePerInstallCondition]){
                    NSString* conditions = [[item oncePerInstallCondition] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (![conditions isEqualToString:@""]){
                        setShownPerInstall = NO;
                        [[conditions componentsSeparatedByString:@"|"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            
                            NSString* itemCondition = [[obj lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            if ([condition isEqualToString:itemCondition]){
                                setShownPerInstall = YES;
                                *stop = YES;
                            }
                        }];
                    }
                }
                
                if (setShownPerInstall){
                    [item setOncePerInstallShown:@(YES)];
                    result = iSmartNewsLastShowSavedSuccessfully;
                }
            }
            
            saveContext(self.service);
        }
    }
    
    return result;
}

#pragma mark Legacy news
- (NSString*)cachePath
{
    NSString* _word_cache = [NSStringFromClass([NSCachedURLResponse class]) substringWithRange:NSMakeRange(2, 5)];
    NSString* _ismn_c = [NSString stringWithFormat:@"%@%@", _str_i_smrt_news(), _word_cache];
#if DEBUG
    assert([@"iSmartNewsCache" isEqualToString:_ismn_c]);
#endif
    
    if ([self.service isEqualToString:@"news"])
    {
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.txt", _ismn_c]];
    }
    else
    {
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:[_ismn_c stringByAppendingFormat:@"_%@.txt",self.service]];
    }
}

- (void)setCacheValue:(NSDictionary*)_value
{
    if ([_value objectForKey:@"skipCache"])
        return;
    
    FILE* file = fopen([[self cachePath] UTF8String], "a");
    if (file)
    {
        const char* v = [sn_md5ForDictionary(_value) UTF8String];
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
    
    const char* key = [sn_md5ForDictionary(_message) UTF8String];
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

- (void)clearCache
{
    iSmartNewsMainThread;
    
    [[NSFileManager defaultManager] removeItemAtPath:[self cachePath] error:NULL];
    
    iSmartNewsLog(@"clearCache");
}

#pragma mark -
#pragma mark Settings

- (NSString*)settingsPath
{
    NSString* _ismn_cs = [NSString stringWithFormat:@"%@%@", _str_i_smrt_news(), @"CacheSettings"];
#if DEBUG
    assert([@"iSmartNewsCacheSettings" isEqualToString:_ismn_cs]);
#endif
    
    if ([self.service isEqualToString:@"news"])
    {
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", _ismn_cs]];
    }
    else
    {
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:[_ismn_cs stringByAppendingFormat:@"_%@.plist",self.service]];
    }
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

- (void)save
{
    if (_settings)
    {
        [_settings writeToFile:[self settingsPath] atomically:YES];
        iSmartNewsLog(@"_settings saved");
    }
}

- (void)resetRunCounter
{
    [[self settings] setObject:[NSNumber numberWithUnsignedLongLong:0] forKey:@"counter"];
    [self save];
}

- (void)incrementCounter
{
    const UInt64 counter = [[[self settings] objectForKey:@"counter"] unsignedLongLongValue];
    [[self settings] setObject:[NSNumber numberWithUnsignedLongLong:(counter + 1)] forKey:@"counter"];
    [self save];
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

- (void)forceUpdate
{
    [self _updateWithEmuAppActivate:NO];
}

#pragma mark -
#pragma mark Properties

- (NSURL*)preprocessURL:(NSURL*)url
{
#if DEBUG || ADHOC
    OriginalURL = [url copy];
    if (OriginalURL)
    {
        if ([GetDebugURLPostFix() length] > 0)
        {
            NSURLComponents* urlComponents = [[NSURLComponents alloc] initWithString:[OriginalURL absoluteString]];
            NSString* path = [urlComponents path];
            NSString* parent = [path stringByDeletingLastPathComponent];
            NSString* lastComponent = [path lastPathComponent];
            NSString* extension = [lastComponent pathExtension];
            if (extension)
            {
                NSString* pureName = [lastComponent stringByDeletingPathExtension];
                [urlComponents setPath:[parent stringByAppendingPathComponent:[[pureName stringByAppendingFormat:@"_%@",GetDebugURLPostFix()] stringByAppendingPathExtension:extension]]];
            }
            else
            {
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

    [[iSmartNewsQueuesInfo queuesInfoForService:[self service]] setURL:url];
}

#pragma mark -
#pragma mark Updater delegate

-(void) updaterDidFailWithError:(NSError*) error userInfo:(NSDictionary*) userInfo
{
    iSmartNewsLog(@"Connection did fail %@",[error localizedDescription]);
    
    const BOOL emulateAppActivate = [[userInfo objectForKey:@"emulateAppActivate"] boolValue];
    
    if (emulateAppActivate)
    {
#if DEBUG || ADHOC
        assert(_integratedWithEventCenter);
#endif
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
        {
            if (sn_AppUpgradeDone())
            {
                [[iSmartEventsCenter sharedCenter] postEvent:iSmartEventsCenterAppDidFinishLaunchingAfterUpgradeEvent tryToDeferDeliveryInsteadOfSkipping:YES];
            }
            else
            {
                [[iSmartEventsCenter sharedCenter] postEvent:iSmartEventsCenterAppDidFinishLaunchingEvent tryToDeferDeliveryInsteadOfSkipping:YES];
            }
        }
    }
}

-(void) updaterDidFinishWithData:(NSData*) data  userInfo:(NSDictionary*) userInfo
{
    NSUInteger previousNewsLength = [_currentNews length];
    
    _currentNews = [data copy];
    
    const BOOL emulateAppActivate = [[userInfo objectForKey:@"emulateAppActivate"] boolValue];
    
    [self parseEvents:_currentNews];
    
    sn_metaReset(self.service);
    
    if (emulateAppActivate)
    {
#if DEBUG || ADHOC
        assert(_integratedWithEventCenter);
#endif
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
        {
            if (sn_AppUpgradeDone())
            {
                [[iSmartEventsCenter sharedCenter] postEvent:iSmartEventsCenterAppDidFinishLaunchingAfterUpgradeEvent tryToDeferDeliveryInsteadOfSkipping:YES];
            }
            else
            {
                [[iSmartEventsCenter sharedCenter] postEvent:iSmartEventsCenterAppDidFinishLaunchingEvent tryToDeferDeliveryInsteadOfSkipping:YES];
            }
        }
    }
    
#warning TODO - check need notify
    if (([_currentNews length] > 0) && (previousNewsLength != [_currentNews length]))
    {
        [self notifyAllEmbededPanels];
    }
}

-(void) notifyAllEmbededPanels
{
    for (iSmartNewsEmbeddedPanel* panel in [_embeddedPanels allValues])
    {
        [panel performSelector:@selector(newItemsAvailable) withObject:nil afterDelay:0.0f];
    }
}

#pragma mark -
#pragma mark - Appliaction state

- (void)UIApplicationWillResignActiveNotification{
    UIApplicationWillResignActiveNotificationDone = YES;
}

- (void)UIApplicationDidEnterBackgroundNotification {
    [self _updateWithEmuAppActivate:NO];
    [self _fetchAppIdIfNeeded];
    
    [_mainDisplayList forceHide];
}

- (void)UIApplicationWillEnterForegroundNotification {
    sn_metaReset(self.service);
    [self _updateWithEmuAppActivate:NO];
    [self incrementCounter];
}

- (void)UIApplicationDidFinishLaunchingNotification
{
    if (![[[self settings] objectForKey:@"launchDate"] isKindOfClass:[NSDate class]])
    {
        [[self settings] setObject:[NSDate ism_date] forKey:@"launchDate"];
        [self save];
    }
    
    if (_integratedWithEventCenter)
    {
        [self _updateWithEmuAppActivate:YES];
    }
    else
    {
        [self _updateWithEmuAppActivate:NO];
    }
    
    [self incrementCounter];
    [self _fetchAppIdIfNeeded];
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
    
    sn_metaReset(self.service);
}

- (void)_fetchAppIdIfNeeded
{
    if (self.iTunesId)
    {
        return;
    }
    
    if (!sn_allowUpdate())
    {
        return;
    }
    
    NSString* bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSString* str = [@"http://itunes.apple.com/lookup?bundleId=" stringByAppendingString:bundleId];
    NSURL* url = [NSURL URLWithString:str];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    
    UIBackgroundTaskIdentifier const task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
    
#pragma warning repleace deprecated NSURLConnection
#pragma clang diagnostic push                                           //NSURLConnection
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
                               
                               [[UIApplication sharedApplication] endBackgroundTask:task];
                               
                               if (connectionError){
                                   return;
                               }
                               
                               if (!data){
                                   return;
                               }
                               
                               if (self.iTunesId){
                                   return;
                               }
                               
                               NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data
                                                                                    options:0
                                                                                      error:NULL];
                               if (!dict){
                                   return;
                               }
                               
                               NSArray* results = [dict objectForKey:@"results"];
                               if (![results isKindOfClass:[NSArray class]]){
                                   return;
                               }
                               
                               [results enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                   if (![obj isKindOfClass:[NSDictionary class]]){
                                       return;
                                   }
                                   
                                   NSString* trackId = [obj objectForKey:@"trackId"];
                                   if (![trackId isKindOfClass:[NSString class]]){
                                       return;
                                   }
                                   
                                   self.iTunesId = trackId;
                               }];
                           }];
#pragma clang diagnostic pop                                        //NSURLConnection
}

+ (void)load
{
    sn_swizzleInstanceMethod([UIApplication class], @selector(setStatusBarHidden:animated:),@selector(iSmartNews_setStatusBarHidden:animated:));
    sn_swizzleInstanceMethod([UIApplication class], @selector(setStatusBarHidden:withAnimation:),@selector(iSmartNews_setStatusBarHidden:withAnimation:));
    sn_swizzleInstanceMethod([UIApplication class], @selector(isStatusBarHidden),@selector(iSmartNews_isStatusBarHidden));
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews]          UIApplicationDidEnterBackgroundNotification];
                                                      [[iSmartNews sharedAdvertising]   UIApplicationDidEnterBackgroundNotification];
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews]          UIApplicationDidFinishLaunchingNotification];
                                                      [[iSmartNews sharedAdvertising]   UIApplicationDidFinishLaunchingNotification];
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews]          UIApplicationWillEnterForegroundNotification];
                                                      [[iSmartNews sharedAdvertising]   UIApplicationWillEnterForegroundNotification];
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews]          UIApplicationWillResignActiveNotification];
                                                      
                                                      //Don't uncomment - set flag for sharedNews, not for advertising
                                                      //[[iSmartNews sharedAdvertising]   UIApplicationWillResignActiveNotification];
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification* notification){
                                                      [[iSmartNews sharedNews]          UIApplicationDidBecomeActiveNotification];
                                                      [[iSmartNews sharedAdvertising]   UIApplicationDidBecomeActiveNotification];
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
