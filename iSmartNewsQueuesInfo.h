//
//  iSmartNewsQueuesInfo.h
//  SmartNewsEmbeded
//
//

#import <Foundation/Foundation.h>

@interface iSmartNewsQueuesInfo : NSObject

+(instancetype) queuesInfoForService:(NSString*) service;

@property (nonatomic, strong, readonly) NSString* service;
@property (nonatomic, strong, readonly) NSMutableDictionary* data;

- (void) setURL:(NSURL*) url;

- (void)loadQueuesInfo;
- (void)saveQueuesInfo;


@end
