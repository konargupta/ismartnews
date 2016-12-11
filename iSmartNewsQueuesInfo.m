//
//  iSmartNewsQueuesInfo.m
//  SmartNewsEmbeded
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsQueuesInfo.h"
#import "iSmartNewsInternal.h"

@interface iSmartNewsQueuesInfo ()
@property (nonatomic, strong, readwrite) NSString* service;
@end

@implementation iSmartNewsQueuesInfo
{
    NSMutableDictionary* queuesInfo_;
    NSURL* _url;
}

+(instancetype) queuesInfoForService:(NSString*) service
{
    static NSMutableDictionary* _instances = nil;
    
    if (_instances == nil)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            
            _instances = [NSMutableDictionary new];
        });
    }
    
    iSmartNewsQueuesInfo* instance = nil;
    BOOL newInstance = NO;
    
    @synchronized (self)
    {
        instance = [_instances objectForKey:service];
        if (instance == nil)
        {
            instance = [iSmartNewsQueuesInfo new];
            [_instances setObject:instance forKey:service];
            instance.service = service;
            newInstance = YES;
        }
    }
    
    if (newInstance)
    {
        [instance loadQueuesInfo];
    }
    
    return instance;
}

-(NSMutableDictionary *)data
{
    return queuesInfo_;
}

-(void) setURL:(NSURL*) url
{
    _url = url;
    
    NSString* urlsMD5 = [queuesInfo_ objectForKey:@"URLS"];
    NSString* currentMd5 = sn_md5ForArray(_url?@[[_url absoluteString]]:nil);
    
    if (![urlsMD5 isEqualToString:currentMd5])
    {
        NSString* path = [self queuesInfoSavePath];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
            queuesInfo_ = [NSMutableDictionary new];
        }
    }
    
    [queuesInfo_ setObject:sn_md5ForArray(_url?@[[_url absoluteString]]:nil) forKey:@"URLS"];
    [self saveQueuesInfo];
}

#pragma warning EncryptMe
- (NSString*)queuesInfoSavePath
{
    if ([self.service isEqualToString:@"news"])
    {
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:@"iSmartNewsQueuesSettings.plist"];
    }
    else
    {
        return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
                 objectAtIndex:0]
                stringByAppendingPathComponent:[@"iSmartNewsQueuesSettings" stringByAppendingFormat:@"_%@.plist",self.service]];
    }
}

- (void)loadQueuesInfo
{
    NSString* path = [self queuesInfoSavePath];
    queuesInfo_ = [[NSDictionary dictionaryWithContentsOfFile:path] mutableCopy];
    
    //Validate queuesInfo and remove if not actual
    if (!queuesInfo_ || ![[queuesInfo_ objectForKey:@"URLS"] isKindOfClass:[NSString class]])
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        }
        
        queuesInfo_ = [NSMutableDictionary new];
    }
    else
    {
        NSString* urlsMD5 = [queuesInfo_ objectForKey:@"URLS"];
        NSString* currentMd5 = sn_md5ForArray( _url?@[[_url absoluteString]]:nil);
        
        if (![urlsMD5 isEqualToString:currentMd5])
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
            }
            queuesInfo_ = [NSMutableDictionary new];
        }
    }
}

- (void)saveQueuesInfo
{
    if (!_url)
        return;
    
    NSString* path = [self queuesInfoSavePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    
    [queuesInfo_ writeToFile:path atomically:YES];
}

@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
