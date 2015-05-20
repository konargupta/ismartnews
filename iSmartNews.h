/*!
 @file       iSmartNews.h
 @version    2.0
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define iSmartNewsVersion       @"2.0.1"

extern NSString* const iSmartNewsUserDidOpenReviewNotification;

@class iSmartNews;

typedef BOOL (^CanIShowAlertViewRightNowHandler)(iSmartNews* smartNews);

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
+ (void)setCanIShowAlertViewRightNowHandler:(CanIShowAlertViewRightNowHandler)CanIShowAlertViewRightNow;


- (void)setRemoveAdsActionBlock:(void(^)())block;

+ (iSmartNews*)newsForService:(NSString*)name;

// Clear cache, meta news, settings
- (void)resetAll;
- (void)resetLoadedDataBuffer;

- (void)resetUpgradeInfo;
- (void)updateUpgradeInfo;

// Get app launch date, if not exists then it is created
- (NSDate*)launchDate;
- (void)resetLaunchDate;

@end


#define iSmartNews_SetRemoveAdsAction(block)                                    \
    [[iSmartNews sharedNews] setRemoveAdsActionBlock:block];

/*!
 @}
 */

/* - ++ -- */
