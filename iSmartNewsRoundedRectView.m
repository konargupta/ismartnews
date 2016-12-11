//
//  iSmartNewsRoundedRectView.m
//  iSmartNewsDemo
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsRoundedRectView.h"

@implementation iSmartNewsRoundedRectView

@synthesize radius;

+ (Class)layerClass {
    return [CAGradientLayer class];
}
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        
        colorComponents = NSZoneMalloc(NSDefaultMallocZone(), 8*sizeof(CGFloat));
        for (int i = 0; i < 8; i++) {
            colorComponents[i] = 1.0;
        }
    }
    return self;
}

- (void)setColors:(CGFloat *)components {
    for (int i = 0; i < 8; i++) {
        colorComponents[i] = components[i];
    }
    
    CAGradientLayer *gradientLayer = (CAGradientLayer *)self.layer;
    gradientLayer.colors =
    [NSArray arrayWithObjects:
     (id)[UIColor colorWithRed:colorComponents[0] green:colorComponents[1] blue:colorComponents[2] alpha:colorComponents[3]].CGColor,
     (id)[UIColor colorWithRed:colorComponents[4] green:colorComponents[5] blue:colorComponents[6] alpha:colorComponents[7]].CGColor,
     nil];
    
}

- (void)setRadius:(NSInteger)rad {
    radius = rad;
    CAGradientLayer *gradientLayer = (CAGradientLayer *)self.layer;
    gradientLayer.cornerRadius = rad*1.0f;
}

- (void)dealloc {
    NSZoneFree(NSDefaultMallocZone(), colorComponents);
}


@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
