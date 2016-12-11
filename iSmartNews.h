/*!
 @file       iSmartNews.h
 @version    3.5.11
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "iSmartNewsPublic.h"

#define ISMART_NEWS_MAKE_VERSION(MAJOR,MINOR,PATCH)       ((MAJOR*1000*1000) + (MINOR*1000) + PATCH)

#define ISMART_NEWS_VERSION_3_5_11      ISMART_NEWS_MAKE_VERSION(3,5,11)

#define ISMART_NEWS_CURRENT_VERSION     ISMART_NEWS_VERSION_3_5_11

#define iSmartNewsVersion               @"3.5.11"

extern NSString* const iSmartNewsUserDidOpenReviewNotification;
extern NSString* const iSmartNewsDidOpenCallbackNotification;

extern NSString* const iSmartNewsDidShowNewsItemNotification;
extern NSString* const iSmartNewsDidCloseNewsItemNotification;

@class iSmartNews;

typedef BOOL (^iSmartNewsAllowBlock)(iSmartNews* smartNews);

/*!
 @class  iSmartNews
 @brief  Class helps to integrate some quick news
        functionality into iPhone/iPad application.
 @note
    Class is NOT thread safe.
 */
@interface iSmartNews : NSObject 

/*!
 @brief
  List of URLs to checked while news downloading.
 */
@property (nonatomic,copy)                    NSURL*                url;

// if iTunesId is not by developer, then module will try to lookup it using iTunes Lookup API.
@property (nonatomic,copy)                    NSString*             iTunesId;

/*!
 @brief
  Returns shared instance of news downloader.
  If you want, then you can create your own instance.
 
 @note
  Method should be called only from main thread.
 */
+ (iSmartNews*)sharedNews;

/*!
 @brief
 Returns shared instance of advertising downloader.
 If you want, then you can create your own instance.
 
 @note
 Method should be called only from main thread.
 */
+ (iSmartNews*)sharedAdvertising;

/*!
    @brief
        Sets handler that can be called to prevent news alert view from showing right now.
        If handler returns YES, then popup will be shown, in another case popup will be shown later.
 */
+ (void)setCanIShowAlertViewRightNowHandler:(iSmartNewsAllowBlock)CanIShowAlertViewRightNow;

/*!
    @brief
        Set handler controlling fetching news file from server
 */
+ (void)setAllowFetchHandler:(iSmartNewsAllowBlock)fetchHandler;


- (void)setRemoveAdsActionBlock:(void(^)())block;

+ (iSmartNews*)newsForService:(NSString*)name;

-(UIView<iSmartNewsPanelProtocol>*) getEmbeddedPanelForEvents:(NSArray*) events error:(NSError**) error;
-(BOOL) kickEmbeddedPanelWithUUID:(NSString*) uuid;

// Clear cache, meta news, settings
- (void)resetAll;
- (void)resetLoadedDataBuffer;

- (void)resetUpgradeInfo;
- (void)updateUpgradeInfo;

// Get app launch date, if not exists then it is created
- (NSDate*)launchDate;
- (void)resetLaunchDate;

// Force update news
- (void)forceUpdate;

/**!
    Manually show the review right now if possible.
 */
- (void)sendSpecialEventForShowReviewItem;
- (void)openReview    __deprecated_msg("Use sendSpecialEventForShowReviewItem instead");

- (void)openReviewUrl __deprecated_msg("Use openReviewWithType instead");
- (void)openReviewWithType:(NSString*) type;

/**!
    Mark review item as show.
 */
- (void)markReviewAsShown;

@end


#define iSmartNews_SetRemoveAdsAction(block)                                    \
    [[iSmartNews sharedNews] setRemoveAdsActionBlock:block];

/*!
 @}
 */

/* - ++ -- */
