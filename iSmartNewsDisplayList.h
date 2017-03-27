//
//  iSmartNewsDisplayQueue.h
//  SmartNewsEmbeded
//
//

#import <Foundation/Foundation.h>
#import "iSmartNewsInternal.h"

extern NSString* const envQueuesTimeoutsKey;
extern NSString* const envGateKey;

@class iSmartNewsDisplayList;

@protocol iSmartNewsDisplayListDelegate <NSObject>

@required
//Integration and actions
-(void) displayList:(iSmartNewsDisplayList*) displayList performAction:(iSmartNewsDisplayAction) action item:(NSObject*) item;

@optional
-(void) displayListWasEnded:(iSmartNewsDisplayList*) displayList;

-(void) displayListWasAssignedNewMessages:(iSmartNewsDisplayList*) displayList;
-(void) displayListNotNewMessagesForAssignment:(iSmartNewsDisplayList*) displayList;

-(void) displayListFailedToShowMessage:(iSmartNewsDisplayList*) displayList;
-(void) displayListFailedToShowNextMessage:(iSmartNewsDisplayList*) displayList;

-(BOOL) displayListShouldToReloadCurrentMessage:(iSmartNewsDisplayList*) displayList;

@required
//Shown logic
-(iSmartNewsSaveLastShowResult) displayList:(iSmartNewsDisplayList*) displayList markItemIsShown:(NSDictionary*) item info:(NSDictionary*) info;

//Extended environment info
-(BOOL)     displayListCanShowAlertView:(iSmartNewsDisplayList*)  displayList;
-(UInt64)   displayListGetCounterValue:(iSmartNewsDisplayList*)   displayList;
@end


@interface iSmartNewsDisplayList : NSObject

@property (nonatomic, weak)   NSObject<iSmartNewsDisplayListDelegate>*  delegate;

@property (nonatomic, strong) NSString*  service;
@property (nonatomic, assign) iSmartNewsVisualizerAppearance   visualizerAppearance;

@property (nonatomic, weak) NSObject<iSmartNewsVisualizerStateNotificationReceiver>* visualizerStateNotificationReceiver;

@property (nonatomic, strong, readonly) iSmartNewsVisualizer*  visualizer;
@property (nonatomic, weak)   iSmartNewsEmbeddedPanel*   visualizerEmbeddedPanel;

@property (nonatomic, strong, readonly) NSDictionary* currentNewsMessage;
@property (nonatomic, assign, readonly) NSUInteger remainNewsMessagesCount;

- (void)assignNews:(NSArray*) news enveronment:(NSDictionary*) enveronment;

- (void)resetEndedFlag;
- (void)hideForceAndClear;

- (void)showNextMessage;
- (void)setAllowMultipleAsyncVisualizers;

@end
