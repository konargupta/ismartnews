//
//  iSmartNewsModalPanel.m
//  iSmartNewsDemo
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsModalPanel.h"
#import "iSmartNewsInternal.h"

#define DEFAULT_MARGIN				20.0f
#define DEFAULT_BACKGROUND_COLOR	[UIColor colorWithWhite:0.0 alpha:0.5]
#define DEFAULT_CORNER_RADIUS		4.0f
#define DEFAULT_BORDER_WIDTH		1.5f
#define DEFAULT_BORDER_COLOR		[UIColor whiteColor]
#define DEFAULT_BOUNCE				YES

@implementation iSmartNewsModalPanel
{
    iSmartNewsContentStatus _status;
}

@synthesize roundedRect, closeButton, actionButton, delegate = _delegate, contentView, contentContainer, removeAdsButton;
@synthesize margin, padding, cornerRadius, borderWidth, borderColor, contentColor, shouldBounce;

@synthesize status = _status;

- (void)setShowRemoveAdsButton:(BOOL)showRemoveAdsButton{
    [[self removeAdsButton] setHidden:!showRemoveAdsButton];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        roundedRect = nil;
        closeButton = nil;
        actionButton = nil;
        contentView = nil;
        startEndPoint = CGPointZero;
        
        margin = UIEdgeInsetsMake(DEFAULT_MARGIN, DEFAULT_MARGIN, DEFAULT_MARGIN, DEFAULT_MARGIN);
        padding = UIEdgeInsetsMake(DEFAULT_MARGIN, DEFAULT_MARGIN, DEFAULT_MARGIN, DEFAULT_MARGIN);
        cornerRadius = DEFAULT_CORNER_RADIUS;
        borderWidth = DEFAULT_BORDER_WIDTH;
        borderColor = DEFAULT_BORDER_COLOR;
        contentColor = DEFAULT_BACKGROUND_COLOR;
        
        shouldBounce = DEFAULT_BOUNCE;
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.autoresizesSubviews = YES;
        
        self.contentContainer = [[UIView alloc] initWithFrame:self.bounds];
        self.contentContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.contentContainer.autoresizesSubviews = YES;
        [self addSubview:self.contentContainer];
        
        [self setBackgroundColor://[UIColor colorWithWhite:0.0 alpha:0.5]
         [UIColor clearColor]]; // Fixed value, the bacground mask.
        [self setAlpha:0.];
        
        [self.contentView setBackgroundColor:[UIColor clearColor]];
        self.delegate = nil;
        
        self.tag = (arc4random() % 32768);
        
    }
    return self;
}

- (void)dealloc {
    self.roundedRect = nil;
    self.removeAdsButton = nil;
    self.closeButton = nil;
    self.actionButton = nil;
    self.contentContainer = nil;
    self.borderColor = nil;
    self.contentColor = nil;
    self.delegate = nil;
}


#pragma mark - New

-(NSString *)uuid
{
    return @"popup_modal";
}

-(void) placeContent:(UIView*) content
{
    [self placeContent:content status:iSmartNewsContentReady];
}

-(void) placeContent:(UIView*) content status:(iSmartNewsContentStatus) status
{
    for (UIView* subview in [[self contentView] subviews])
    {
        if ([content isEqual:subview])
            continue;
        
        [subview removeFromSuperview];
    }
    
    if (content != nil)
    {
        _status = status;
        [[self contentView] addSubview:content];
        
        CGRect frame = [[self contentView] frame];
        frame.origin = CGPointZero;

        content.frame = frame;
        
        [content setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
    }
    //[content setBackgroundColor:[UIColor clearColor]];
}

-(void)setIsReady:(BOOL)isReady
{
    if (_isReady != isReady)
    {
        _isReady = isReady;
        
        if ([[self delegate] respondsToSelector:@selector(panelDidChangeStatus:)])
        {
            [[self delegate] panelDidChangeStatus:self];
        }
    }
}

-(BOOL)isActive
{
    return YES;
}

-(void)setActive:(BOOL)active
{
    //Not applicable for ModalPanel
    assert(active == YES);
}

#pragma mark - Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %ld>", [[self class] description], (long)self.tag];
}

#pragma mark - Accessors
- (void)setCornerRadius:(CGFloat)newRadius
{
    cornerRadius = newRadius;
    self.roundedRect.layer.cornerRadius = cornerRadius;
}

- (void)setBorderWidth:(CGFloat)newWidth
{
    borderWidth = newWidth;
    self.roundedRect.layer.borderWidth = borderWidth;
}

- (void)setBorderColor:(UIColor *)newColor
{
    borderColor = newColor;
    self.roundedRect.layer.borderColor = [borderColor CGColor];
}
- (void)setContentColor:(UIColor *)newColor
{
    contentColor = newColor;
    self.roundedRect.backgroundColor = contentColor;
}

- (UIView *)roundedRect
{
    if (!roundedRect)
    {
        self.roundedRect = [[UIView alloc] initWithFrame:CGRectZero];
        self.roundedRect.layer.masksToBounds = YES;
        self.roundedRect.backgroundColor = self.contentColor;
        self.roundedRect.layer.borderColor = [self.borderColor CGColor];
        self.roundedRect.layer.borderWidth = self.borderWidth;
        self.roundedRect.layer.cornerRadius = self.cornerRadius;
        
        [self.contentContainer insertSubview:self.roundedRect atIndex:0];
    }
    return roundedRect;
}

- (UIButton*)removeAdsButton
{
    if (!removeAdsButton) {
        self.removeAdsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.removeAdsButton.hidden = YES;
        
        [self.removeAdsButton setBackgroundColor:[UIColor blackColor]];
        [self.removeAdsButton.layer setBorderColor:[UIColor whiteColor].CGColor];
        [self.removeAdsButton.layer setBorderWidth:1.f];
        [self.removeAdsButton.layer setCornerRadius:3];
        [self.removeAdsButton.titleLabel setFont:[UIFont systemFontOfSize:12]];
        [self.removeAdsButton setTitle:RemoveAdsString() forState:UIControlStateNormal];
        [self.removeAdsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        const CGSize s = [[self.removeAdsButton.titleLabel text] sizeWithFont:self.removeAdsButton.titleLabel.font];
#pragma clang diagnostic pop
        
        [self.removeAdsButton setBounds:CGRectMake(0, 0, s.width + 10, s.height + 6)];
        
        self.removeAdsButton.layer.shadowColor   = [[UIColor blackColor] CGColor];
        self.removeAdsButton.layer.shadowOffset  = CGSizeMake(0,4);
        self.removeAdsButton.layer.shadowOpacity = 0.3;
        
#if DEBUG || ADHOC
        self.removeAdsButton.accessibilityIdentifier = @"iSNRemoveAds";
        self.removeAdsButton.accessibilityLabel      = @"iSNRemoveAds";
#endif
        
        [removeAdsButton addTarget:self action:@selector(removeAdsPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentContainer insertSubview:removeAdsButton aboveSubview:self.contentView];
    }
    return removeAdsButton;
}

- (UIButton*)closeButton
{
    if (!closeButton)
    {
        self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        
        NSData* data = ([[UIScreen mainScreen] scale] > 1.f)?close2_png_data():close_png_data();
        
        UIImage* image1 = [UIImage imageWithData:data];
        UIImage* image = [UIImage imageWithCGImage:image1.CGImage scale:[[UIScreen mainScreen] scale] orientation:image1.imageOrientation];
        
        [self.closeButton setImage:image forState:UIControlStateNormal];
        
        [self.closeButton setFrame:CGRectMake(0, 0, 44, 44)];
        self.closeButton.layer.shadowColor = [[UIColor blackColor] CGColor];
        self.closeButton.layer.shadowOffset = CGSizeMake(0,4);
        self.closeButton.layer.shadowOpacity = 0.3;
        
        [self.closeButton addTarget:self action:@selector(closePressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentContainer insertSubview:closeButton aboveSubview:self.contentView];
        
#if DEBUG || ADHOC
        self.closeButton.accessibilityIdentifier = @"iSNClose";
        self.closeButton.accessibilityLabel      = @"iSNClose";
#endif

    }
    return closeButton;
}

- (UIView *)contentView
{
    if (!contentView)
    {
        self.contentView = [[UIView alloc] initWithFrame:[self contentViewFrame]];
        self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.contentView.autoresizesSubviews = YES;
        [self.contentContainer insertSubview:contentView aboveSubview:self.roundedRect];
    }
    return contentView;
}

- (CGRect)roundedRectFrame
{
    
    return CGRectMake(self.margin.left + self.bounds.origin.x,
                      self.margin.top + self.bounds.origin.y,
                      self.bounds.size.width - self.margin.left - self.margin.right,
                      self.bounds.size.height - self.margin.top - self.margin.bottom);
}

- (CGRect)closeButtonFrame
{
    CGRect f = [self roundedRectFrame];
    if (self.closePosition && [self.closePosition isEqualToString:@"top-right"])
    {
        return CGRectMake(CGRectGetMaxX(f) - floor(closeButton.bounds.size.width),// - floor(closeButton.frame.size.width*0.5),
                          f.origin.y,
                          closeButton.frame.size.width,
                          closeButton.frame.size.height);
        
    }
    else if (self.closePosition && [self.closePosition isEqualToString:@"bottom-left"])
    {
        return CGRectMake(f.origin.x,// - floor(closeButton.frame.size.width*0.5),
                          CGRectGetMaxY(f) - floor(closeButton.bounds.size.height),
                          closeButton.frame.size.width,
                          closeButton.frame.size.height);

    }
    else if (self.closePosition && [self.closePosition isEqualToString:@"bottom-right"])
    {
        return CGRectMake(CGRectGetMaxX(f) - floor(closeButton.bounds.size.width),
                          CGRectGetMaxY(f) - floor(closeButton.bounds.size.height),
                          closeButton.frame.size.width,
                          closeButton.frame.size.height);
        
    }
    else
    {
        return CGRectMake(f.origin.x,// - floor(closeButton.frame.size.width*0.5),
                          f.origin.y,// - floor(closeButton.frame.size.height*0.5),
                          closeButton.frame.size.width,
                          closeButton.frame.size.height);
    }
}

- (CGRect)removeAdsButtonFrame
{
    CGRect f = [self roundedRectFrame];
    if (self.removeAdsPosition && [self.removeAdsPosition isEqualToString:@"bottom-left"])
    {
        return CGRectMake(10,
                          CGRectGetMaxY(f) - floor(removeAdsButton.bounds.size.height) - 10,// - floor(closeButton.frame.size.height*0.5),
                          removeAdsButton.frame.size.width,
                          removeAdsButton.frame.size.height);
    }
    else if (self.removeAdsPosition && [self.removeAdsPosition isEqualToString:@"bottom-right"])
    {
        return CGRectMake(CGRectGetMaxX(f) - floor(removeAdsButton.bounds.size.width) - 10,
                          CGRectGetMaxY(f) - floor(removeAdsButton.bounds.size.height) - 10,// - floor(closeButton.frame.size.height*0.5),
                          removeAdsButton.frame.size.width,
                          removeAdsButton.frame.size.height);
    }
    else if (self.removeAdsPosition && [self.removeAdsPosition isEqualToString:@"top-left"])
    {
        return CGRectMake(10,
                          (44.f - removeAdsButton.bounds.size.height)/2,// - floor(closeButton.frame.size.height*0.5),
                          removeAdsButton.frame.size.width,
                          removeAdsButton.frame.size.height);
    }
    else
    {
        return CGRectMake(CGRectGetMaxX(f) - floor(removeAdsButton.bounds.size.width) - 10,
                          (44.f - removeAdsButton.bounds.size.height)/2,// - floor(closeButton.frame.size.height*0.5),
                          removeAdsButton.frame.size.width,
                          removeAdsButton.frame.size.height);
    }
}

- (CGRect)actionButtonFrame
{
    if (![[self.actionButton titleForState:UIControlStateNormal] length])
        return CGRectZero;
    
    [self.actionButton sizeToFit];
    CGRect f = [self roundedRectFrame];
    return CGRectMake(f.origin.x + f.size.width - self.actionButton.frame.size.width + 11,
                      f.origin.y - floor(actionButton.frame.size.height*0.5),
                      self.actionButton.frame.size.width,
                      self.actionButton.frame.size.height);
}

- (CGRect)contentViewFrame
{
    CGRect roundedRectFrame = [self roundedRectFrame];
    return CGRectMake(self.padding.left + roundedRectFrame.origin.x,
                      self.padding.top + roundedRectFrame.origin.y,
                      roundedRectFrame.size.width - self.padding.left - self.padding.right,
                      roundedRectFrame.size.height - self.padding.top - self.padding.bottom);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.roundedRect.frame	= [self roundedRectFrame];
    self.closeButton.frame	= [self closeButtonFrame];
    self.removeAdsButton.frame	= [self removeAdsButtonFrame];
    self.actionButton.frame	= [self actionButtonFrame];
    self.contentView.frame	= [self contentViewFrame];
    
    if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
    {
        CGRect frame = [[self contentView] frame];
        frame.origin = CGPointZero;
        
        for (UIView* subview in [[self contentView] subviews])
        {
            [subview setFrame:frame];
        }
    }
}

#pragma mark - Actions

- (void)removeAdsPressed:(id)sender
{
    [self hide:iSmartNewsPanelCloseRemoveAds];
}

- (void)closePressed:(id)sender
{
    [self hide:iSmartNewsPanelCloseSimple];
}

#pragma mark - Show

- (void)showAnimationStarting {};		//subclasses override
- (void)showAnimationPart1Finished {};	//subclasses override
- (void)showAnimationPart2Finished {};	//subclasses override
- (void)showAnimationPart3Finished {};	//subclasses override
- (void)showAnimationFinished {};		//subclasses override

- (void)show
{
    [self showAnimationStarting];
    self.alpha = 0.0;
    
    if ([self.customAnimation isEqualToString:@"fade"])
    {
        self.contentContainer.transform = CGAffineTransformIdentity;
        
        // Show the view right away
        [UIView animateWithDuration:0.3f
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             self.alpha = 1.0;
                         }
                         completion:^(BOOL finished) {
            [self showAnimationFinished];
        }];
    }
    else if ([self.customAnimation isEqualToString:@"modal"])
    {
        self.contentContainer.transform = CGAffineTransformIdentity;
        self.contentContainer.center    = CGPointMake(self.center.x, self.center.y + self.frame.size.height);
        
        // Show the view right away
        [UIView animateWithDuration:0.3
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             
                             self.contentContainer.center = self.center;
                             self.alpha = 1.0;
                         }
                         completion:^(BOOL finished) {
                             [self showAnimationFinished];
                         }];
    }
    else
    {
        self.contentContainer.transform = CGAffineTransformMakeScale(0.00001, 0.00001);
        
        void (^animationBlock)(BOOL) = ^(BOOL finished) {
            [self showAnimationPart1Finished];
            // Wait one second and then fade in the view
            [UIView animateWithDuration:0.1
                             animations:^{
                                 self.contentContainer.transform = CGAffineTransformMakeScale(0.95, 0.95);
                             }
                             completion:^(BOOL finished){
                                 
                                 [self showAnimationPart2Finished];
                                 // Wait one second and then fade in the view
                                 [UIView animateWithDuration:0.1
                                                  animations:^{
                                                      self.contentContainer.transform = CGAffineTransformMakeScale(1.02, 1.02);
                                                  }
                                                  completion:^(BOOL finished){
                                                      
                                                      [self showAnimationPart3Finished];
                                                      // Wait one second and then fade in the view
                                                      [UIView animateWithDuration:0.1
                                                                       animations:^{
                                                                           self.contentContainer.transform = CGAffineTransformIdentity;
                                                                       }
                                                                       completion:^(BOOL finished){
                                                                           [self showAnimationFinished];
                                                                       }];
                                                  }];
                             }];
        };
        
        // Show the view right away
        [UIView animateWithDuration:0.3
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             self.alpha = 1.0;
                             self.contentContainer.center = self.center;
                             self.contentContainer.transform = CGAffineTransformMakeScale((shouldBounce ? 1.05 : 1.0), (shouldBounce ? 1.05 : 1.0));
                         }
                         completion:(shouldBounce ? animationBlock : ^(BOOL finished) {
            [self showAnimationFinished];
        })];

    }
}

- (void)showImmediately
{
    self.contentContainer.center = self.center;
    self.contentContainer.transform = CGAffineTransformIdentity;
    self.alpha = 1.0;
    
    [self showAnimationFinished];
}

- (void)showFromPoint:(CGPoint)point{
    
    startEndPoint = point;
    self.contentContainer.center = point;
    [self show];
}

- (void)hide:(iSmartNewsPanelCloseType)type
{
    NSObject<iSmartNewsPanelDelegate>* delegate = self.delegate;
    
    dispatch_block_t removeFromSuperViewAndCallDelegate = [^{
        
        [self removeFromSuperview];
        
        if ([delegate respondsToSelector:@selector(panel:didCloseWithType:)])
        {
            [delegate panel:self didCloseWithType:type];
        }
        
    } copy];
    
    if (self.disableBuiltinAnimations)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), removeFromSuperViewAndCallDelegate);
    }
    else
    {
        if (self.hideAnimationTarget)
        {
            [[self hideAnimationTarget] performSelector:self.hideAnimationAction withObject:self];
        }
        
        if ([self.customAnimation isEqualToString:@"fade"])
        {
            // Hide the view right away
            [UIView animateWithDuration:0.3
                             animations:^{
                                 self.alpha = 0;
                             }
                             completion:^(BOOL finished){
                                 
                                 removeFromSuperViewAndCallDelegate();
                             }];
        }
        else if ([self.customAnimation isEqualToString:@"modal"])
        {
            // Hide the view right away
            [UIView animateWithDuration:0.3
                             animations:^{
                                 
                                 self.contentContainer.center = CGPointMake(self.center.x, self.center.y + self.frame.size.height);
                                 self.alpha = 0;
                             }
                             completion:^(BOOL finished){
                                 
                                 removeFromSuperViewAndCallDelegate();
                             }];
        }
        else
        {
            // Hide the view right away
            [UIView animateWithDuration:0.3
                             animations:^{
                                 self.alpha = 0;
                                 if (startEndPoint.x != CGPointZero.x || startEndPoint.y != CGPointZero.y)
                                 {
                                     self.contentContainer.center = startEndPoint;
                                 }
                                 self.contentContainer.transform = CGAffineTransformMakeScale(0.0001, 0.0001);
                             }
                             completion:^(BOOL finished){
                                 
                                 removeFromSuperViewAndCallDelegate();
                             }];
        }
    }
}

@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
