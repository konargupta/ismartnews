//
//  iSmartNewsRoundedRectView.h
//  iSmartNewsDemo
//
//

#if SMARTNEWS_COMPILE

#import <UIKit/UIKit.h>

@interface iSmartNewsRoundedRectView : UIView {
    NSInteger	radius;
    CGFloat		*colorComponents;
}

@property (nonatomic, assign) NSInteger	radius;

- (void)setColors:(CGFloat *)components;

@end

#endif//#if SMARTNEWS_COMPILE
