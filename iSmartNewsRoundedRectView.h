//
//  iSmartNewsRoundedRectView.h
//  iSmartNewsDemo
//
//

#import <UIKit/UIKit.h>
#import "iSmartNewsPublic.h"

@interface iSmartNewsRoundedRectView : UIView {
    NSInteger	radius;
    CGFloat		*colorComponents;
}

@property (nonatomic, assign) NSInteger	radius;

- (void)setColors:(CGFloat *)components;

@end
