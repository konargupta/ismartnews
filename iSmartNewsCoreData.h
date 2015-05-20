//
//  iSmartNewsCoreData.h
//  iSmartNewsDemo
//
//

#import <CoreData/CoreData.h>

enum {
    SMARTNEWS_PER_WEEK_YEAR   = 2010,//1970,
    SMARTNEWS_PER_MONTH_YEAR  = 2011,//1971,
    SMARTNEWS_PER_CONST_MONTH = 5
};

NSManagedObjectContext* managedObjectContext(NSString* serviceName);
void saveContext(NSString* serviceName);

@class SmartNewsEvent;
@class SmartNewsTimeRange;

extern BOOL sn_AppUpgradeDone();

@interface SmartNewsItem : NSManagedObject
@property (nullable, nonatomic, retain) NSNumber *completed;
@property (nullable, nonatomic, retain) NSDate *end;
@property (nullable, nonatomic, retain) NSNumber *maxDelay;
@property (nullable, nonatomic, retain) NSNumber *minDelay;
@property (nullable, nonatomic, retain) NSString *queue;
@property (nullable, nonatomic, retain) NSNumber *randomize;
@property (nullable, nonatomic, retain) NSString *removeAdsAction;
@property (nullable, nonatomic, retain) NSString *sequence;
@property (nullable, nonatomic, retain) NSString *sequenceSrc;
@property (nullable, nonatomic, retain) NSDate *start;
@property (nullable, nonatomic, retain) NSNumber *urlIndex;
@property (nullable, nonatomic, retain) NSString *urls;
@property (nullable, nonatomic, retain) NSString *urlsSrc;
@property (nullable, nonatomic, retain) NSString *uuid;
@property (nullable, nonatomic, retain) NSSet<SmartNewsTimeRange *> *timeRanges;
@property (nullable, nonatomic, retain) NSSet<SmartNewsEvent *> *events;
@property (nullable, nonatomic, retain) NSString *minShowInterval;
@property (nullable, nonatomic, retain) NSDate *lastShown;
@property (nullable, nonatomic, retain) NSString *shownInVersion;
@property (nullable, nonatomic, retain) NSNumber *oncePerVersion;
@property (nullable, nonatomic, retain) NSString *oncePerVersionCondition;
@property (nullable, nonatomic, retain) NSString *orientations;
@property (nullable, nonatomic, retain) NSString *onShow;
@property (nullable, nonatomic, retain) NSNumber *priority;
@property (nullable, nonatomic, retain) NSNumber *showOnlyIfUpgrade;
- (void)randomizeUrlsAndSequence;
- (BOOL)checkMinShowInterval;
- (BOOL)checkAllowedForVersion;
@end

@interface SmartNewsTimeRange : NSManagedObject
@end

@interface SmartNewsEvent : NSManagedObject
@property (nullable, nonatomic, retain) NSString *currentPattern;
@property (nullable, nonatomic, retain) NSString *initialPattern;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) SmartNewsItem *newsItem;
@end

