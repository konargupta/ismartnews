//
//  iSmartNewsUtils.h
//  iSmartNewsDemo
//
//

#import <UIKit/UIKit.h>

@interface NSArray(SmartNews)
- (NSString*)sn_join:(NSString*)sep;
- (BOOL)sn_isStrings;
- (BOOL)sn_isDates;
@end

@interface UIView (iSmartNewsFindFirstResponder)
- (id)iSmartNewsFindFirstResponder_findFirstResponder;
@end

id getMessageKey(NSDictionary* _dict, NSString* _key);
void extractSmartNewsMessage(NSDictionary* desc, NSMutableDictionary* message);
void clearNewsLang();

NSString* smartNewsAlertDomain();
NSString* RemoveAdsString();

NSSet* sn_protectedItems();

@interface NSDate(iSmartNews)
- (NSUInteger)iSmartNews_calendarIntervalSinceDate:(NSDate*)sinceDate;
@end

NSString* stringFromNSURLComponents(NSURLComponents* components);

@interface NSDictionary (iSmartNewsLowercaseKeys)

/*
 Recursive algorithm to find all nested dictionary keys and create an NSMutableDictionary copy with all keys converted to lowercase.
 Returns an NSMutableDictionary with all keys and nested keys converted to lowercase.
 */
+ (NSMutableDictionary *)iSmartNews_dictionaryWithLowercaseKeysFromDictionary:(NSDictionary *)dictionary;

/*
 Convienience method to create a new lowercase dictionary object an existing NSDictionary instance
 Returns an NSMutableDictionary with all keys and nested keys converted to lowercase.
 */
- (NSMutableDictionary *)iSmartNews_dictionaryWithLowercaseKeys;

- (id)iSmartNews_objectForKey:(id)key;

@end

NSString* news_md5ForDictionary(NSDictionary* _dict);

@interface NSString (iSmartNews)
- (nullable NSString *)sn_stringByAddingPercentEncodingForRFC3986;
@end
