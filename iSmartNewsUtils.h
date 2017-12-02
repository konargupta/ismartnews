//
//  iSmartNewsUtils.h
//  iSmartNewsDemo
//
//

#import <UIKit/UIKit.h>
#import "iSmartNewsPublic.h"

@interface UIScrollView(ex)
@property (nonatomic, assign) BOOL verticalScrollDisable;
@property (nonatomic, assign) BOOL horizontalScrollDisable;
@end

@interface NSArray(SmartNews)
- (NSString*_Nonnull)sn_join:(NSString*_Nonnull)sep;
- (BOOL)sn_isStrings;
- (BOOL)sn_isDates;
@end

@interface UIView (iSmartNewsFindFirstResponder)
- (id _Nullable)iSmartNewsFindFirstResponder_findFirstResponder;
@end

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES BOOL sn_allowUpdate();

id _Nullable getMessageKey(NSDictionary* _Nullable _dict, NSString* _Nonnull _key);
void extractSmartNewsMessage(NSDictionary* _Nonnull desc, NSMutableDictionary* _Nonnull message);
void clearNewsLang();

NSString* _Nonnull smartNewsAlertDomain();
NSString* _Nullable RemoveAdsString();

NSSet* _Nonnull sn_protectedItems();

@interface NSDate(iSmartNews)
- (NSUInteger)iSmartNews_calendarIntervalSinceDate:(NSDate* _Nullable)sinceDate;
@end

NSString* _Nonnull stringFromNSURLComponents(NSURLComponents* _Nonnull components);

@interface NSDictionary (iSmartNewsLowercaseKeys)

/*
 Recursive algorithm to find all nested dictionary keys and create an NSMutableDictionary copy with all keys converted to lowercase.
 Returns an NSMutableDictionary with all keys and nested keys converted to lowercase.
 */
+ (NSMutableDictionary* _Nonnull)iSmartNews_dictionaryWithLowercaseKeysFromDictionary:(NSDictionary* _Nonnull)dictionary;

/*
 Convienience method to create a new lowercase dictionary object an existing NSDictionary instance
 Returns an NSMutableDictionary with all keys and nested keys converted to lowercase.
 */
- (NSMutableDictionary* _Nonnull)iSmartNews_dictionaryWithLowercaseKeys;

- (id _Nullable )iSmartNews_objectForKey:(id _Nonnull)key;

@end

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES void sn_cleanMessageKeysCache();

EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSString* _Nonnull sn_md5ForArray(NSArray* _Nullable _array);
EXTERN_OR_STATIC INTERNAL_ATTRIBUTES NSString* _Nonnull sn_md5ForDictionary(NSDictionary* _Nullable _dict);

@interface NSString (iSmartNews)
- (NSString* _Nullable)sn_stringByAddingPercentEncodingForRFC3986;
@end


@interface SNUUID : NSObject
+(NSString*_Nonnull) shortIUID;
@end
