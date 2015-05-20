//
//  iSmartNewsVisualizer.h
//  iSmartNewsDemo
//
//

#import <Foundation/Foundation.h>

@class iSmartNewsVisualizer;

@protocol iSmartNewsVisualizerDelegate <NSObject>
@required
- (void)visualizerDidClickOpenReview:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickCancelReview:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickRemindLaterReview:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickNothing:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickCancel:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickOk:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidClickRemoveAds:(iSmartNewsVisualizer*)visualizer;
- (void)visualizerDidFail:(iSmartNewsVisualizer*)visualizer;
@end

typedef void (^iSmartNewsVisualizerShownBlock)();

@interface iSmartNewsVisualizer : NSObject

@property (nonatomic,weak) id<iSmartNewsVisualizerDelegate> delegate;
@property (nonatomic,assign) BOOL allowAllIphoneOrientations;
@property (nonatomic,assign) UIInterfaceOrientationMask orientationMask;
@property (nonatomic,assign) NSRange delayRange;
@property (nonatomic,copy) NSString* metaUUID;
@property (nonatomic,copy)                    NSString*             iTunesId;
@property (nonatomic,copy) NSString* onShow;
@property (nonatomic,copy) iSmartNewsVisualizerShownBlock shownBlock;

- (NSURL*)url;

- (id)initAlertViewVisualizerWithTitle:(NSString*)title message:(NSString*)message cancel:(NSString*)cancel ok:(NSString*)ok review:(NSString*)review remind:(NSString*)remind;
- (id)initWebViewVisualizerWithURL:(NSURL*)url showRemoveAdsButton:(BOOL)showRemoveAdsButton;
- (void)show;
- (void)forceHide;

@end
