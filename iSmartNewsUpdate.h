//
//  iSmartNewsUpdate.h
//  SmartNewsEmbeded
//
//

#import <Foundation/Foundation.h>

@protocol iSmartNewsUpdaterDelegate <NSObject>

-(void) updaterDidFinishWithData:(NSData*) data  userInfo:(NSDictionary*) userInfo;
-(void) updaterDidFailWithError:(NSError*) error userInfo:(NSDictionary*) userInfo;

@end

@interface iSmartNewsUpdater : NSObject

@property (nonatomic, weak) NSObject<iSmartNewsUpdaterDelegate>* delegate;

-(void) beginUpdateWithURL:(NSURL*) url userInfo:(NSDictionary*) userInfo;
-(void) beginUpdateWithURLRequest:(NSURLRequest*) urlRequest userInfo:(NSDictionary*) userInfo;
-(void) cancel;
-(BOOL) isActive;

@end
