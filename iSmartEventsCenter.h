//
//  iSmartEventsCenter.h
//  iSmartEventsCenterDemo
//
//

#import <Foundation/Foundation.h>

#define ISMART_EVENT_CENTER_MAKE_VERSION(MAJOR,MINOR,PATCH)       ((MAJOR*1000*1000) + (MINOR*1000) + PATCH)

#define ISMART_EVENT_CENTER_VERSION_1_0_0   ISMART_EVENT_CENTER_MAKE_VERSION(1,0,0)
#define ISMART_EVENT_CENTER_VERSION_1_1_0   ISMART_EVENT_CENTER_MAKE_VERSION(1,1,0)
#define ISMART_EVENT_CENTER_VERSION_1_1_1   ISMART_EVENT_CENTER_MAKE_VERSION(1,1,1)
#define ISMART_EVENT_CENTER_VERSION_1_1_2   ISMART_EVENT_CENTER_MAKE_VERSION(1,1,2)
#define ISMART_EVENT_CENTER_VERSION_1_1_3   ISMART_EVENT_CENTER_MAKE_VERSION(1,1,3)
#define ISMART_EVENT_CENTER_VERSION_1_1_4   ISMART_EVENT_CENTER_MAKE_VERSION(1,1,4)

#define ISMART_EVENT_CENTER_VERSION         ISMART_EVENT_CENTER_VERSION_1_1_4

typedef NS_ENUM(NSInteger, iSmartEventsCenterCallbackStatus) {
    iSmartEventsCenterCallbackContinue = 0,
    iSmartEventsCenterCallbackBreakForThisEvent = 1,
    iSmartEventsCenterCallbackBreakForTheSameEvents = 1,
    iSmartEventsCenterCallbackBreakForAllEvents = 2,
};

extern NSString* const iSmartEventsCenterBeforeAnyEvent;
extern NSString* const iSmartEventsCenterAfterAnyEvent;
extern NSString* const iSmartEventsCenterAppActivateEvent;
extern NSString* const iSmartEventsCenterAppDidFinishLaunchingEvent;
extern NSString* const iSmartEventsCenterAppDidFinishLaunchingAfterUpgradeEvent;

typedef void (^iSmartEventsCenterCallbackCompletion)(iSmartEventsCenterCallbackStatus status, NSArray* sessionBlockedServices);
typedef void (^iSmartEventsCenterCallback)(NSString* event, iSmartEventsCenterCallbackCompletion completion);

@interface iSmartEventsCenter : NSObject

+ (instancetype)sharedCenter;

- (void)registerService:(NSString*)name callback:(iSmartEventsCenterCallback)callback forEvents:(NSArray*)events;
- (void)registerService:(NSString*)name callback:(iSmartEventsCenterCallback)callback forEvents:(NSArray*)events withPriority:(float)priority;

- (void)postEvent:(NSString*)event;
- (void)postEvent:(NSString *)event tryToDeferDeliveryInsteadOfSkipping:(BOOL) tryToDefer;

@end
