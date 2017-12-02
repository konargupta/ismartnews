//
//  iSmartNewsVisualizer.h
//  iSmartNewsDemo
//
//

#import <Foundation/Foundation.h>
#import "iSmartNewsPublic.h"

@class iSmartNewsEmbeddedPanel;
@class iSmartNewsVisualizer;

@protocol iSmartNewsVisualizerDelegate <NSObject>
@required
- (void)visualizerDidClickOpenReview:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickCancelReview:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickRemindLaterReview:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickNothing:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickLink:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickCallback:(iSmartNewsVisualizer*)visualizer userInfo:(NSDictionary*) userInfo;
- (void)visualizerDidClickCancel:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickOk:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickRemoveAds:(iSmartNewsVisualizer*)visualizer;

- (void)visualizerDidFail:(iSmartNewsVisualizer*)visualizer;

#pragma mark - FixMe!
- (NSString*)     isCallBackURL:(NSURL*) url;
- (NSDictionary*) makeUserInfoForCallBackURL:(NSURL*) url callType:(NSString*) callType uuid:(NSString*) uuid;
@end

@protocol iSmartNewsVisualizerStateNotificationReceiver <NSObject>

- (void)visualizerWillShowMessage:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerFinishedShowingMessage:(iSmartNewsVisualizer*)visualizer;
@end

typedef enum : NSInteger
{
    isnVisualizerAppearancePopup    = 0,
    isnVisualizerAppearanceEmbedded = 1,
    
} iSmartNewsVisualizerAppearance;

typedef void (^iSmartNewsVisualizerShownBlock)();

@interface iSmartNewsVisualizer : NSObject

@property (nonatomic,assign,readonly) BOOL isPresented;

@property (nonatomic,copy) NSString* metaUUID;

@property (nonatomic,assign) BOOL                       allowAllIphoneOrientations;
@property (nonatomic,assign) UIInterfaceOrientationMask orientationMask;

@property (nonatomic,copy) NSString* onShow;
@property (nonatomic,copy) iSmartNewsVisualizerShownBlock shownBlock;

@property (nonatomic,weak) iSmartNews* owner;

@property (nonatomic,weak) id<iSmartNewsVisualizerDelegate> delegate;
@property (nonatomic,weak) id<iSmartNewsVisualizerStateNotificationReceiver> stateNotificationReceiver;

@property (nonatomic,copy) NSDictionary* appearanceStyle;

- (NSURL*)url;

//- (id)initAlertViewVisualizerWithTitle:(NSString*)title message:(NSString*)message cancel:(NSString*)cancel ok:(NSString*)ok review:(NSString*)review remind:(NSString*)remind;

- (id)initAlertViewVisualizerWithDescription:(NSDictionary*) description;
- (id)initWebViewVisualizerWithURL:(NSURL*)url showRemoveAdsButton:(BOOL)showRemoveAdsButton;

- (id)initDirectActionVisualizerWithURL:(NSURL*)url;

- (void)showWithDelayRange:(NSRange) delayRange;
- (void)forceHide;


//Embedded
@property (nonatomic,weak) iSmartNewsEmbeddedPanel*            embeddedPanel;

@end
