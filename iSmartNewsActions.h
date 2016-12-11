//
//  iSmartNewsActions.h
//  SmartNewsEmbeded
//
//

#import <Foundation/Foundation.h>
#import "iSmartNewsInternal.h"

typedef void(^iSmartNewsActionCompletionHandler)(NSString* action, NSDictionary* additionalInfo, BOOL success);

extern NSString* const iSmartNewsActionReviewOpen;

@interface iSmartNewsActions : NSObject

@property (nonatomic, copy) NSString* iTunesId;

+(instancetype) sharedInstance;

-(BOOL) performAction:(NSString*) action item:(NSObject*) item additionalInfo:(NSDictionary*) additionalInfo completionHandler:(iSmartNewsActionCompletionHandler) completionHandler;

@end
