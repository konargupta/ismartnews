//
//  iSmartNewsUpdate.m
//  SmartNewsEmbeded
//
//

#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

#import "iSmartNewsUpdate.h"
#import <UIKit/UIKit.h>

@interface iSmartNewsUpdater ()<NSURLConnectionDelegate>

@end

@implementation iSmartNewsUpdater
{
    UIBackgroundTaskIdentifier  _updateBgTaskId;
    NSURLConnection* _connection;
    NSDictionary*    _userInfo;
    
    NSMutableData*   _data;
    
    BOOL _finished;
}

-(void)beginUpdateWithURL:(NSURL *)url userInfo:(NSDictionary *)userInfo
{
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    
    [self beginUpdateWithURLRequest:request userInfo:userInfo];
}

-(void) beginUpdateWithURLRequest:(NSURLRequest*) urlRequest userInfo:(NSDictionary*) userInfo
{
    [self cancel];
    
    _data = [NSMutableData new];
    _userInfo = userInfo;
    _finished = NO;
    
#pragma warning repleace deprecated NSURLConnection
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _connection = [NSURLConnection connectionWithRequest:urlRequest delegate:self];
#pragma clang diagnostic pop
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
    {
        if (_updateBgTaskId == UIBackgroundTaskInvalid)
        {
            _updateBgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                
                [[UIApplication sharedApplication] endBackgroundTask:_updateBgTaskId];
                _updateBgTaskId = UIBackgroundTaskInvalid;
                
                [self cancel];
            }];
        }
    }
}

-(void)cancel
{
    if (_connection)
    {
        [_connection cancel];
        _connection = nil;
        _data = nil;
        
        if ([self delegate] && (!_finished))
        {
            [[self delegate] updaterDidFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:500 userInfo:nil] userInfo:_userInfo];
        }
        _userInfo = nil;
    }
    
    [self endBackroundTask];
}

-(BOOL) isActive
{
    return (_connection != nil);
}

#pragma mark - Task
- (void) endBackroundTask
{
    if (_updateBgTaskId != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:_updateBgTaskId];
        _updateBgTaskId = UIBackgroundTaskInvalid;
    }
}

#pragma mark - Delegate

- (BOOL)connection:(NSURLConnection* )connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace* )protectionSpace
{
    if (connection != _connection)
    {
        return NO;
    }
    
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection* )connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge* )challenge
{
    if (connection != _connection)
    {
        return;
    }
    
    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (connection != _connection)
    {
        return;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (connection != _connection)
    {
        return;
    }
    
    [_data appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (connection != _connection)
    {
        return;
    }

    
    if (_updateBgTaskId != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:_updateBgTaskId];
        _updateBgTaskId = UIBackgroundTaskInvalid;
    }
    
    [[self delegate] updaterDidFailWithError:error userInfo:_userInfo];
    
    _finished   = YES;
    _data       = nil;
    _connection = nil;
    _userInfo   = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (connection != _connection){
        return;
    }
    
    [[self delegate] updaterDidFinishWithData:_data userInfo:_userInfo];
    
    _finished   = YES;
    
    NSURLConnection* currentConnection = _connection;
    dispatch_async(dispatch_get_main_queue(), ^{
       
        if (self->_connection == currentConnection)
        {
            [self cancel];
        }
    });
    
    if (_updateBgTaskId != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:_updateBgTaskId];
        _updateBgTaskId = UIBackgroundTaskInvalid;
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    //iSmartNewsLog(@"willCacheResponse: return nil");
    return nil;
}

@end

#endif//#if (SMARTNEWS_COMPILE || SMARTNEWS_COMPILE_DEVELOP)
