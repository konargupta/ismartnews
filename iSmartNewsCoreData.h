//
//  iSmartNewsCoreData.h
//  iSmartNewsDemo
//
//

#import <CoreData/CoreData.h>
#import "iSmartNewsPublic.h"

enum {
    SMARTNEWS_PER_WEEK_YEAR   = 2010,//1970,
    SMARTNEWS_PER_MONTH_YEAR  = 2011,//1971,
    SMARTNEWS_PER_CONST_MONTH = 5
};

NSManagedObjectContext* _Nullable managedObjectContext(NSString* _Nonnull serviceName);
void saveContext(NSString* _Nonnull serviceName);

@class SmartNewsEvent;
@class SmartNewsTimeRange;

extern BOOL sn_AppUpgradeDone();

@interface SmartNewsItem : NSManagedObject
@property (nullable, nonatomic, retain) NSString *uuid;
@property (nullable, nonatomic, retain) NSString *orientations;

@property (nullable, nonatomic, retain) NSNumber *completed;
@property (nullable, nonatomic, retain) NSDate *start;
@property (nullable, nonatomic, retain) NSDate *end;
@property (nullable, nonatomic, retain) NSNumber *maxDelay;
@property (nullable, nonatomic, retain) NSNumber *minDelay;

@property (nullable, nonatomic, retain) NSString *minShowInterval;
@property (nullable, nonatomic, retain) NSNumber *priority;

@property (nullable, nonatomic, retain) NSDate *lastShown;
@property (nullable, nonatomic, retain) NSSet<SmartNewsTimeRange*>* timeRanges;
@property (nullable, nonatomic, retain) NSSet<SmartNewsEvent*> *events;

@property (nullable, nonatomic, retain) NSString *queue;
@property (nullable, nonatomic, retain) NSNumber *randomize;
@property (nullable, nonatomic, retain) NSString *sequence;
@property (nullable, nonatomic, retain) NSString *sequenceSrc;

@property (nullable, nonatomic, retain) NSString *urlFixed;
@property (nullable, nonatomic, retain) NSNumber *urlIndex; //url index for show
@property (nullable, nonatomic, retain) NSString *urls;
@property (nullable, nonatomic, retain) NSString *urlsSrc;

@property (nullable, nonatomic, retain) NSString *shownInVersion;
@property (nullable, nonatomic, retain) NSString *shownInVersionCondition;
@property (nullable, nonatomic, retain) NSNumber *oncePerVersion;
@property (nullable, nonatomic, retain) NSString *oncePerVersionCondition;

@property (nullable, nonatomic, retain) NSNumber *showOnlyIfUpgrade;

@property (nullable, nonatomic, retain) NSString* removeAdsAction; //Action URL
@property (nullable, nonatomic, retain) NSString* onShow;          //Notice URL

// Since v4.2.1
@property (nullable, nonatomic, retain) NSNumber *oncePerInstall;
@property (nullable, nonatomic, retain) NSString *oncePerInstallCondition;
@property (nullable, nonatomic, retain) NSNumber *oncePerInstallShown;

// Since v4.4.1
@property (nullable, nonatomic, retain) NSString *segment;

// Since v4.7 alpha
@property (nullable, nonatomic, retain) NSNumber *autoHideInterval;
@property (nullable, nonatomic, retain) NSNumber *notPresented;

// Since v4.8.4
@property (nullable, nonatomic, retain) NSString *cond_skip;
@property (nullable, nonatomic, retain) NSString *cond_show;

- (void)randomizeUrlsAndSequence;
- (void)gotoNextUrl;
- (nullable NSString*)getCurrentURLString;

- (BOOL)checkMinShowInterval;
- (BOOL)checkAllowedForInstall;
- (BOOL)checkAllowedForVersion;
- (BOOL)checkAllowedForAnotherConditions;
@end

@interface SmartNewsTimeRange : NSManagedObject
@property (nullable, nonatomic, retain) NSString *uuid;
@property (nullable, nonatomic, retain) NSDate *start;
@property (nullable, nonatomic, retain) NSDate *end;

@property (nullable, nonatomic, retain) NSNumber *shown;
@property (nullable, nonatomic, retain) NSNumber *shownLimit;

@property (nullable, nonatomic, retain) NSString *probability;
@end

@interface SmartNewsEvent : NSManagedObject
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) SmartNewsItem *newsItem;

@property (nullable, nonatomic, retain) NSString *initialPattern;
@property (nullable, nonatomic, retain) NSString *currentPattern;
@end

