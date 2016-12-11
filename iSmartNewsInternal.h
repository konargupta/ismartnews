//
//  iSmartNewsInternal.h
//
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "iSmartNews.h"
#import "iSmartNewsPublic.h"

#import "iSmartEventsCenter.h"

#import "iSmartNewsCoreData.h"
#import "iSmartNewsUtils.h"
#import "iSmartNewsMeta.h"

typedef NS_ENUM(NSInteger, iSmartNewsSaveLastShowResult)
{
    iSmartNewsLastShowSavedSuccessfully    = 0,
    iSmartNewsLastShowItemNotFound         = 1,
    iSmartNewsLastShowConditionNotFound    = 2,
};


//#import "iSmartNewsPopupNavigationController.h"
#import "iSmartNews+UIApplication.h"
#import "iSmartNewsModalPanel.h"
#import "iSmartNewsRoundedRectView.h"
#import "iSmartNewsImages.h"
#import "iSmartNewsPopupViewController.h"
#import "iSmartNewsEmbeddedPanel.h"
#import "iSmartNewsWindow.h"
#import "iSmartNewsVisualizer.h"
#import "iSmartNewsZip.h"
#import "iSmartNewsEvents.h"
#import "iSmartNewsDate.h"
#import "iSmartNewsLocalization.h"
#import "iSmartNewsSegment.h"
#import "iSmartNewsDisplayList.h"
#import "iSmartNewsQueuesInfo.h"
#import "iSmartNewsUpdate.h"
#import "iSmartNewsActions.h"



#if DEBUG
#   if NO_SMARTNEWS_LOGS
#       define iSmartNewsLog(...)     ((void)0)
#   else
#       define iSmartNewsLog(...)     NSLog(@"iSmartNews: %@",[NSString stringWithFormat:__VA_ARGS__])
#   endif
#   define iSmartNewsMainThread       assert([NSThread isMainThread] && "Should be called from main thread only!")
#else//!DEBUG
#   define NSLog(...)                 ((void)0)

#   ifdef assert
#       undef assert
#   endif

#   define assert(...)                ((void)0)
#   define iSmartNewsMainThread       ((void)0)
#   define iSmartNewsLog(...)         ((void)0)
#endif

#ifndef STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO
#   define STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#endif


@interface iSmartNews()
@property (nonatomic,strong,readonly) NSString* service;
@property (nonatomic,strong,readonly) NSString* settingsPath;
@property (nonatomic,strong,readonly) NSString* cachePath;
@end


//Internal using
#if (DEBUG || SMARTNEWS_COMPILE_DEVELOP)

EXTERN_OR_STATIC INLINE_INTERNAL_ATTRIBUTES NSString* _str_i_smrt();
EXTERN_OR_STATIC INLINE_INTERNAL_ATTRIBUTES NSString* _str_i_smrt_news();

static const char iSmartNews_hideStatusbar_originalKey;
static const char iSmartNews_hideStatusbarKey;

extern NSString*  const  iSmartNewsMessageTitleKey;
extern NSString*  const  iSmartNewsMessageTextKey;
extern NSString*  const  iSmartNewsMessageCancelKey;
extern NSString*  const  iSmartNewsMessageActionKey;
extern NSString*  const  iSmartNewsMessageReviewKey;
extern NSString*  const  iSmartNewsMessageRemindKey;
extern NSString*  const  iSmartNewsMessageUrlKey;
extern NSString*  const  iSmartNewsMessageStartDateKey;
extern NSString*  const  iSmartNewsMessageEndDateKey;
extern NSString*  const  iSmartNewsMessageRepeatKey;
extern NSString*  const  iSmartNewsMessageAlwaysKey;
extern NSString*  const  iSmartNewsMessageCounterKey;
extern NSString*  const  iSmartNewsMessageQueueKey;

extern NSString*  const  iSmartNewsMessageTypeKey;
extern NSString*  const  iSmartNewsContentTypeWeb;


//iSmartNewsCoreData
static BOOL g_isUpgradeDetected;
static BOOL g_isUpgrade;
static BOOL g_AppUpgradeDone;

EXTERN_OR_STATIC void sn_detectUpgrade(BOOL force);

//iSmartNewsUtils
EXTERN_OR_STATIC INLINE_INTERNAL_ATTRIBUTES void sn_swizzleInstanceMethod(Class class, SEL old, SEL newSelector);


//iSmartNewsMeta
EXTERN_OR_STATIC INTERNAL_ATTRIBUTES void sn_evenShownNewsClearForService(NSString* service);
EXTERN_OR_STATIC INTERNAL_ATTRIBUTES void sn_removeOldMeta(NSString* serviceName, NSSet* _activeUuuids);

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSArray* sn_preprocessMeta(NSString* serviceName, NSArray* input, NSMutableSet* metaUuid);


EXTERN_OR_STATIC INTERNAL_ATTRIBUTES SmartNewsItem* sn_findMetaItem(NSString* serviceName, NSString* uuid);
EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSManagedObject* sn_findMetaRangeItem(NSString* serviceName, NSManagedObject* meta, NSString* uuid);

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES void sn_metaReset(NSString* serviceName);
EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSArray* sn_metaNews(NSString* serviceName, NSArray* events);
#endif
