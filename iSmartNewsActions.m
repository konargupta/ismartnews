//
//  iSmartNewsActions.m
//  SmartNewsEmbeded
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif


#import "iSmartNewsActions.h"
#import <UIKit/UIKit.h>

#import <StoreKit/StoreKit.h>

NSString* const iSmartNewsActionReviewOpen = @"review:open";

__attribute__((always_inline)) __attribute__((visibility("hidden"))) NSURL* _specialReviewURLFor(NSString* reviewType)
{
    NSURL* resultURL = nil;
    
    reviewType = [reviewType lowercaseString];
    if ([@[@"native", @"store_kit", @"native_review"] containsObject:reviewType])
    {
        resultURL = [NSURL URLWithString:@"review://storekit"];
    }
    else if ([@[@"action_write_review", @"appstore_writereview"] containsObject:reviewType])
    {
        resultURL = [NSURL URLWithString:@"review://action/write-review"];
    }
    else if (([reviewType length] > 0) && ([reviewType integerValue] > 0))
    {
        resultURL = [NSURL URLWithString:[NSString stringWithFormat:@"review://id/%@", reviewType]];
    }
    
    return resultURL;
}

@implementation iSmartNewsActions
{
    //NSOperationQueue* _actionsQueue;
}

+(instancetype)sharedInstance
{
    static iSmartNewsActions* sharedInstance;
    
    if (sharedInstance == nil)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            
            sharedInstance = [[iSmartNewsActions alloc] init];
        });
    }
    
    return sharedInstance;
}

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        //_actionsQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

-(BOOL) performAction:(NSString*) action item:(NSObject*) item additionalInfo:(NSDictionary*) additionalInfo completionHandler:(iSmartNewsActionCompletionHandler) completionHandler
{
    if ([action isEqualToString:iSmartNewsActionReviewOpen])
    {
        enum : NSInteger
        {
            skUndefinded,
            skNotAvailable,
            skUsed,
            
        } storeKitMethod = skUndefinded;
        
        NSString* reviewType = [additionalInfo objectForKey:@"reviewType"];
        NSURL* url = _specialReviewURLFor(reviewType);
        
        if ([[[url scheme] lowercaseString] isEqualToString:@"review"])
        {
            NSString* host = [[url host] lowercaseString];
            
            NSArray* pathComponents = [[url pathComponents] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                return ![evaluatedObject isEqualToString:@"/"];
            }]];
            
            if ([host isEqualToString:@"storekit"])
            {
                if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.3"))
                {
                    storeKitMethod = skUsed;
                }
                else
                {
                    storeKitMethod = skNotAvailable;
                }
            }
            
            
            if (storeKitMethod != skUsed)
            {
                if ((storeKitMethod == skNotAvailable) && STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0"))
                {
                    url = [self reviewURL:[self iTunesId] addAction:@"write-review"];
                }
                else if ([host isEqualToString:@"action"] && ([pathComponents count] > 0) && STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0"))
                {
                    url = [self reviewURL:[self iTunesId] addAction:[pathComponents lastObject]];
                }
                else if ([host isEqualToString:@"id"] && ([pathComponents count] > 0))
                {
                    url = [self reviewURL:[pathComponents lastObject] addAction:nil];
                }
                else //Default
                {
                    url = [self reviewURL:[self iTunesId] addAction:nil];
                }
            }
        }
        else
        {
            url = [self reviewURL:[self iTunesId] addAction:nil];
            
            if (url == nil)
                return NO;
        }
        
        if (url == nil)
            url = [self reviewURL:[self iTunesId] addAction:nil];
    
        NSTimeInterval delay = [[additionalInfo objectForKey:@"delay"] doubleValue];
        
        UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.3") && (storeKitMethod == skUsed))
            {
                [SKStoreReviewController requestReview];
                
                if (completionHandler)
                {
                    completionHandler(action, additionalInfo, YES);
                }
                
                [[UIApplication sharedApplication] endBackgroundTask:task];
            }
            else
            {
                if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0"))
                {
                    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                        
                        if (completionHandler)
                        {
                            completionHandler(action, additionalInfo, success);
                        }
                        
                        [[UIApplication sharedApplication] endBackgroundTask:task];
                    }];
                }
                else
                {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    BOOL preResult = (url != nil) && [[UIApplication sharedApplication] canOpenURL:url];
                    
                    if (preResult)
                    {
                        preResult = [[UIApplication sharedApplication] openURL:url];
                    }
#pragma clang diagnostic pop
                    
                    if (completionHandler)
                    {
                        completionHandler(action, additionalInfo, preResult);
                    }
                    
                    [[UIApplication sharedApplication] endBackgroundTask:task];
                }
            }
        });
        
        return YES;
    }
    
    return NO;
}

- (BOOL)openReviewUrl:(NSURL*) url
{
    //Make url and flags
    enum : NSInteger
    {
        skUndefinded,
        skNotAvailable,
        skUsed,
        
    } storeKitMethod = skUndefinded;
    
    if ([[[url scheme] lowercaseString] isEqualToString:@"review"])
    {
        NSString* host = [[url host] lowercaseString];
        
        NSArray* pathComponents = [[url pathComponents] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return ![evaluatedObject isEqualToString:@"/"];
        }]];
        
        if ([host isEqualToString:@"storekit"])
        {
            if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.3"))
            {
                storeKitMethod = skUsed;
            }
            else
            {
                storeKitMethod = skNotAvailable;
            }
        }
        
        if (storeKitMethod != skUsed)
        {
            if ((storeKitMethod == skNotAvailable) && STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0"))
            {
                url = [self reviewURL:[self iTunesId] addAction:@"write-review"];
            }
            else if ([host isEqualToString:@"action"] && ([pathComponents count] > 0) && STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0"))
            {
                url = [self reviewURL:[self iTunesId] addAction:[pathComponents lastObject]];
            }
            else if ([host isEqualToString:@"id"] && ([pathComponents count] > 0))
            {
                url = [self reviewURL:[pathComponents lastObject] addAction:nil];
            }
            else //Default
            {
                url = [self reviewURL:[self iTunesId] addAction:nil];
            }
        }
    }
    else
    {
        url = [self reviewURL:[self iTunesId] addAction:nil];
        
        if (url == nil)
            return NO;
    }
    
    //Do
    if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.3") && (storeKitMethod == skUsed))
    {
        [SKStoreReviewController requestReview];
        return YES;
    }
    else
    {
        if (url == nil)
            url = [self reviewURL:[self iTunesId] addAction:nil];
        
        if ((url == nil) || ([[UIApplication sharedApplication] canOpenURL:url] == NO))
            return NO;
        
        return [[UIApplication sharedApplication] openURL:url];
    }
}

- (NSURL*)reviewURL:(NSString*)iTunesId addAction:(NSString*) action
{
    if ([iTunesId length] == 0)
        return nil;
    
    if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0") && ([action length] > 0))
    {
        return [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@?action=%@",iTunesId,action]];
    }
    else if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0"))
    {
        return [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@&onlyLatestVersion=true&pageNumber=0&sortOrdering=1",iTunesId]];
    }
    else if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.1"))
    {
        return [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@",iTunesId]];
    }
    else if (STR_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))
    {
        return [NSURL URLWithString:[NSString stringWithFormat:@"http://itunes.apple.com/app/id%@",iTunesId]];
    }
    else
    {
        return [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@",iTunesId]];
    }
}

@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
