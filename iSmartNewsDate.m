//
//  NSObject+iSmartNewsDate.m
//  iSmartNewsDemo
//
//

#if SMARTNEWS_COMPILE

#import "iSmartNewsDate.h"

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

@implementation NSDate (iSmartNewsDate)

+ (NSDate*)ism_date
{
    return [self date];
}

@end

#endif//#if SMARTNEWS_COMPILE
