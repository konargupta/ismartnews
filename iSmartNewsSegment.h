//
//  iSmartNewsSegment.h
//  iSmartNewsDemo
//
//

#import <Foundation/Foundation.h>
#import "iSmartNewsPublic.h"

@interface iSmartNewsSegment : NSObject
+ (instancetype)sharedSegment;
@property (nonatomic, copy) NSString* apiKey;
@property (nonatomic, copy) NSString* defaultSourceURLTemplate;
- (BOOL)matches:(NSString*)segment;
- (void)reset;
- (void)preprocess:(NSArray*)items;
@end
