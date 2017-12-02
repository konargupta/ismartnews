//
//  iSmartNews+UIApplication.m
//  iSmartNewsDemo
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNews+UIApplication.h"
#import "iSmartNewsInternal.h"

@implementation UIApplication(iSmartNews)

- (BOOL)original_isStatusBarHidden
{
    NSNumber* num = objc_getAssociatedObject(self, &iSmartNews_hideStatusbar_originalKey);
    if (num == nil)
    {
        num = @([self iSmartNews_isStatusBarHidden]);
        objc_setAssociatedObject(self, &iSmartNews_hideStatusbar_originalKey, num, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return [num boolValue];
}

- (void)iSmartNews_hideStatusbar:(BOOL)iSmartNews_hideStatusbar animated:(BOOL)animated
{
    if ([objc_getAssociatedObject(self, &iSmartNews_hideStatusbarKey) boolValue] == iSmartNews_hideStatusbar)
        return;
    
    objc_setAssociatedObject(self, &iSmartNews_hideStatusbarKey, @(iSmartNews_hideStatusbar), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (iSmartNews_hideStatusbar)
    {
        objc_setAssociatedObject(self, &iSmartNews_hideStatusbar_originalKey, @([self iSmartNews_isStatusBarHidden]), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [self iSmartNews_updateStatusbarVisibility:animated];
}

- (void)iSmartNews_updateStatusbarVisibility:(BOOL)animated
{
    NSString* _key = [NSString stringWithFormat:@"%@Hooked", _str_i_smrt_news()];
#if DEBUG
    assert([@"iSmartNewsHooked" isEqualToString:_key]);
#endif
    
    if ([objc_getAssociatedObject(self, &iSmartNews_hideStatusbarKey) boolValue])
    {
        [[[NSThread currentThread] threadDictionary] setObject:@(YES) forKey:_key];
        [self iSmartNews_setStatusBarHidden:YES animated:animated];
        [[[NSThread currentThread] threadDictionary] removeObjectForKey:_key];
    }
    else
    {
        [[[NSThread currentThread] threadDictionary] setObject:@(YES) forKey:_key];
        [self iSmartNews_setStatusBarHidden:[self original_isStatusBarHidden] animated:animated];
        [[[NSThread currentThread] threadDictionary] removeObjectForKey:_key];
    }
}

- (void)iSmartNews_updateStatusbarVisibilityWithAnimation:(UIStatusBarAnimation)animation
{
    NSString* _key = [NSString stringWithFormat:@"%@Hooked", _str_i_smrt_news()];
#if DEBUG
    assert([@"iSmartNewsHooked" isEqualToString:_key]);
#endif
    
    if ([objc_getAssociatedObject(self, &iSmartNews_hideStatusbarKey) boolValue])
    {
        [[[NSThread currentThread] threadDictionary] setObject:@(YES) forKey:_key];
        [self iSmartNews_setStatusBarHidden:YES withAnimation:animation];
        [[[NSThread currentThread] threadDictionary] removeObjectForKey:_key];
    }
    else
    {
        [[[NSThread currentThread] threadDictionary] setObject:@(YES) forKey:_key];
        [self iSmartNews_setStatusBarHidden:[self original_isStatusBarHidden] withAnimation:animation];
        [[[NSThread currentThread] threadDictionary] removeObjectForKey:_key];
    }
}

- (void)iSmartNews_setStatusBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    NSString* _key = [NSString stringWithFormat:@"%@Hooked", _str_i_smrt_news()];
#if DEBUG
    assert([@"iSmartNewsHooked" isEqualToString:_key]);
#endif
    
    if ([objc_getAssociatedObject(self, &iSmartNews_hideStatusbarKey) boolValue] == NO ||
        [[[NSThread currentThread] threadDictionary] objectForKey:_key])
    {
        [self iSmartNews_setStatusBarHidden:hidden animated:animated];
        return;
    }
    
    objc_setAssociatedObject(self, &iSmartNews_hideStatusbar_originalKey, @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self iSmartNews_updateStatusbarVisibility:animated];
}

- (void)iSmartNews_setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation
{
    NSString* _key = [NSString stringWithFormat:@"%@Hooked", _str_i_smrt_news()];
#if DEBUG
    assert([@"iSmartNewsHooked" isEqualToString:_key]);
#endif
    if ([objc_getAssociatedObject(self, &iSmartNews_hideStatusbarKey) boolValue] == NO ||
        [[[NSThread currentThread] threadDictionary] objectForKey:_key])
    {
        [self iSmartNews_setStatusBarHidden:hidden withAnimation:animation];
        return;
    }
    
    objc_setAssociatedObject(self, &iSmartNews_hideStatusbar_originalKey, @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self iSmartNews_updateStatusbarVisibilityWithAnimation:animation];
}

- (BOOL)iSmartNews_isStatusBarHidden
{
    if ([objc_getAssociatedObject(self, &iSmartNews_hideStatusbarKey) boolValue] == NO)
    {
        return [self iSmartNews_isStatusBarHidden];
    }
    
    return [self original_isStatusBarHidden];
}

@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
