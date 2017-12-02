//
//  iSmartNewsModalPanel.h
//  iSmartNewsDemo
//
//

#import <UIKit/UIKit.h>
#import "iSmartNewsPublic.h"

@class iSmartNewsModalPanel;

typedef void (^iSmartNewsUAModalDisplayPanelEvent)(iSmartNewsModalPanel* panel);
typedef void (^iSmartNewsUAModalDisplayPanelAnimationComplete)(BOOL finished);

@interface iSmartNewsModalPanel : UIView<iSmartNewsPanelProtocol>
{
    
    UIView			*contentContainer;
    UIView			*roundedRect;
    UIButton		*closeButton;
    UIButton		*actionButton;
    UIView			*contentView;
    
    CGPoint			startEndPoint;
    
    UIEdgeInsets	margin;
    UIEdgeInsets	padding;
    
    UIColor			*borderColor;
    CGFloat			borderWidth;
    CGFloat			cornerRadius;
    UIColor			*contentColor;
    BOOL			shouldBounce;
    
}

@property (nonatomic,weak) NSObject<iSmartNewsPanelDelegate>	*delegate;

@property (nonatomic, readonly) NSString* uuid;
@property (nonatomic, readwrite, assign) BOOL isReady;

-(void) placeContent:(UIView*) content;

@property (nonatomic, retain) UIView		*contentContainer;
@property (nonatomic, retain) UIView		*roundedRect;
@property (nonatomic, retain) UIButton		*closeButton;
@property (nonatomic, retain) UIButton		*removeAdsButton;
@property (nonatomic, retain) UIButton		*actionButton;
@property (nonatomic, retain) UIView		*contentView;
@property (nonatomic, copy)   NSString*     customAnimation;
@property (nonatomic, assign) BOOL          disableBuiltinAnimations;

@property (nonatomic,copy) NSString* closePosition;
@property (nonatomic,copy) NSString* removeAdsPosition;

// Margin between edge of container frame and panel. Default = {20.0, 20.0, 20.0, 20.0}
@property (nonatomic, assign) UIEdgeInsets	margin;
// Padding between edge of panel and the content area. Default = {20.0, 20.0, 20.0, 20.0}
@property (nonatomic, assign) UIEdgeInsets	padding;
// Border color of the panel. Default = [UIColor whiteColor]
@property (nonatomic, retain) UIColor		*borderColor;
// Border width of the panel. Default = 1.5f
@property (nonatomic, assign) CGFloat		borderWidth;
// Corner radius of the panel. Default = 4.0f
@property (nonatomic, assign) CGFloat		cornerRadius;
// Color of the panel itself. Default = [UIColor colorWithWhite:0.0 alpha:0.8]
@property (nonatomic, retain) UIColor		*contentColor;
// Shows the bounce animation. Default = YES
@property (nonatomic, assign) BOOL			shouldBounce;

@property (nonatomic, assign) BOOL          showRemoveAdsButton;

@property (nonatomic, weak)   id            hideAnimationTarget;
@property (nonatomic, assign) SEL           hideAnimationAction;

- (void)show;
- (void)showFromPoint:(CGPoint)point;
//- (void)hide:(iSmartNewsPanelCloseType)type;

- (CGRect)roundedRectFrame;
- (CGRect)closeButtonFrame;
- (CGRect)removeAdsButtonFrame;
- (CGRect)contentViewFrame;
- (void)showImmediately;
@end

