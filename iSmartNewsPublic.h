//
//  iSmartNewsPublic.h
//
//

#if !defined(SMARTNEWS_COMPILE_PUBLIC_HEADER)
#define SMARTNEWS_COMPILE_PUBLIC_HEADER  1

#if !defined(EXTERN_C)
#   if __cplusplus
#       define EXTERN_C extern "C"
#   else
#       define EXTERN_C
#   endif
#endif

#if !defined(SMARTNEWS_DEBUG_TOOLS)
#   if (DEBUG || ADHOC) && !NO_SMARTNEWS_LOGS
#       define SMARTNEWS_DEBUG_TOOLS    1
#   else
#       define SMARTNEWS_DEBUG_TOOLS    0
#   endif
#endif

#if defined(INLINE_INTERNAL_ATTRIBUTES)
#   undef INLINE_INTERNAL_ATTRIBUTES
#endif

#if (DEBUG || SMARTNEWS_COMPILE_DEVELOP)
#   define INLINE_INTERNAL_ATTRIBUTES
#   define INTERNAL_ATTRIBUTES
#   define EXTERN_OR_STATIC                 EXTERN_C
#else
#   define INLINE_INTERNAL_ATTRIBUTES       __inline__ __attribute__((always_inline)) __attribute__((visibility ("hidden")))
#   define INTERNAL_ATTRIBUTES              __attribute__((visibility ("hidden")))
#   define EXTERN_OR_STATIC                 static
#endif

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, iSmartNewsPanelCloseType)
{
    iSmartNewsPanelCloseSimple,
    iSmartNewsPanelCloseRemoveAds,
    iSmartNewsPanelCloseForced
};


typedef NS_ENUM(NSInteger, iSmartNewsDisplayAction)
{
    iSmartNewsDisplayActionUnknown                 = 0,
    iSmartNewsDisplayActionRemoveAdsBasic          = 1,
    iSmartNewsDisplayActionRemoveAdsApplication    = 2,
};

typedef NS_ENUM(NSInteger, iSmartNewsContentStatus)
{
    iSmartNewsContentLoading = 0,
    iSmartNewsContentReady   = 1,
};

@protocol iSmartNewsPanelDelegate;


@protocol iSmartNewsPanelProtocol <NSObject>

@property (nonatomic,weak) NSObject<iSmartNewsPanelDelegate>	*delegate;

@property (nonatomic, readonly) NSString*    uuid;
@property (nonatomic, readonly, assign) BOOL isReady;
@property (nonatomic, readonly, assign) BOOL isActive;

@property (nonatomic, readonly, assign) iSmartNewsContentStatus status;

-(void) placeContent:(UIView*) content;
-(void) placeContent:(UIView*) content status:(iSmartNewsContentStatus) status;
-(void) setActive:(BOOL) active;

@end

@protocol iSmartNewsPanelDelegate

@optional

- (void)panel:(UIView<iSmartNewsPanelProtocol>*)panel didCloseWithType:(iSmartNewsPanelCloseType)type;
- (void)panelDidChangeStatus:(UIView<iSmartNewsPanelProtocol>*)panel;

- (BOOL)shouldSendCallbackNotificationWithUserInfo:(NSDictionary*) userInfo;

@end

#endif //#if !defined(SMARTNEWS_COMPILE_PUBLIC_HEADER)
