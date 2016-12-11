//
//  iSmartNewsEmbeddedPanel.h
//  SmartNewsEmbeded
//
//

#import <UIKit/UIKit.h>
#import "iSmartNewsPublic.h"

@class iSmartNewsEmbeddedPanel;

@protocol iSmartNewsEmbeddedPanelDelegate

- (void)panelDidCompleteShown:(iSmartNewsEmbeddedPanel*)panel;

@end

@class iSmartNewsDisplayList;

@interface iSmartNewsEmbeddedPanel : UIView<iSmartNewsPanelProtocol>

//Public
@property (nonatomic, readonly) NSString* uuid;
@property (nonatomic, readonly, assign) BOOL isReady;
@property (nonatomic, readonly, assign) BOOL isActive;

//For public
- (void) assignUUID:(NSString*) uuid;

//Internal connection
@property (nonatomic, weak) iSmartNews* parent;
@property (nonatomic, strong) iSmartNewsDisplayList* displayList;

@property (nonatomic, strong) NSString*  iTunesId;
@property (nonatomic, strong) NSString*  service;

//Internal
@property (nonatomic, weak) NSObject<iSmartNewsEmbeddedPanelDelegate>* internalDelegate;
@property (nonatomic, readonly) NSArray*  rotationEvents;
@property (nonatomic, readonly) NSString* currentEvent;

- (void) placeContent:(UIView *)content;

- (void) newItemsAvailable;
- (void) startRotationWithEvents:(NSArray*) events;

@end
