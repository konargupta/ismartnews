//
//  NSObject+iSmartNewsLocalization.m
//  iSmartNewsDemo
//
//

#import "iSmartNewsLocalization.h"

#if SMARTNEWS_COMPILE

#if !__has_feature(objc_arc)
# error File should be compiled with ARC support (use '-fobjc-arc' flag)!
#endif

static NSString* news_lc(){
    static NSString* mk_lang;
    if (!mk_lang){
        NSArray*  preferredLanguages   = [NSLocale preferredLanguages];
        mk_lang    = [preferredLanguages count] ? [[preferredLanguages objectAtIndex:0] lowercaseString] : [[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] lowercaseString];
        NSArray* components = [mk_lang componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_-"]];
        if ([components count] >= 2){
            if ([[components objectAtIndex:0] isEqualToString:@"zh"]
                && ([[components objectAtIndex:1] isEqualToString:@"hans"] || [[components objectAtIndex:1] isEqualToString:@"hant"])){
                mk_lang = [[components objectAtIndex:0] stringByAppendingFormat:@"_%@",[components objectAtIndex:1]];
            }
            else {
                mk_lang = [components objectAtIndex:0];// special fix for iOS9, sometimes it return language + country: ru_BY
            }
        }
        else{
            mk_lang = [components objectAtIndex:0];// special fix for iOS9, sometimes it return language + country: ru_BY
        }
    }
    return mk_lang;
}

static NSDictionary* newsLocalizedStrings() {
    static NSDictionary* v;
    if (!v){
        v = @{
            @"en" : @{
                @"Like this app?" : @"Like this app?",
                @"Please rate it on the App Store!" : @"Please rate it on the App Store!",
                @"Later" : @"Later",
                @"Rate it!" : @"Rate it!",
            },
            @"ar" : @{
                @"Like this app?" : @"هل أعجبك هذا التطبيق؟",
                @"Please rate it on the App Store!" : @"قم من فضلك بتقييمه في متجر التطبيقات!",
                @"Later" : @"لاحقا",
                @"Rate it!" : @"قيمه!"
            },
            @"de" : @{
                @"Like this app?" : @"Gefällt dir diese App?",
                @"Please rate it on the App Store!" : @"Bitte bewerte sie im App Store!",
                @"Later" : @"Später",
                @"Rate it!" : @"Bewerten!"
            },
            @"es" : @{
                    @"Like this app?" : @"¿Te gusta esta aplicación?",
                @"Please rate it on the App Store!" : @"¡Haz tu valoración en la App Store!",
                @"Later" : @"Más tarde",
                @"Rate it!" : @"¡Puntúalo!",
            },
            @"fr": @{
                @"Like this app?" : @"Vous aimez cette app ?",
                @"Please rate it on the App Store!" : @"Veuillez la noter sur l'Appstore !",
                @"Later" : @"Plus tard",
                @"Rate it!" : @"Notez la !",
            },
            @"it":@{
                @"Like this app?" : @"Ti piace questa app?",
                @"Please rate it on the App Store!" : @"Scrivi una recensione sull'App Store!",
                @"Later" : @"Più tardi",
                @"Rate it!" : @"Scrivi una recensione!",
            },
            @"ja":@{
                @"Like this app?" : @"このアプリが好きですか?",
                @"Please rate it on the App Store!" : @"App Storeで評価してください！",
                @"Later" : @"後で",
                @"Rate it!" : @"今すぐ評価!",

            },
            @"ko":@{
                @"Like this app?" : @"이 앱이 마음에 드세요?",
                @"Please rate it on the App Store!" : @"App Store에서 평가해주세요!",
                @"Later" : @"나중에",
                @"Rate it!" : @"평가하기!",
            },
            @"nl":@{
                @"Like this app?" : @"Vind je deze app leuk?",
                @"Please rate it on the App Store!" : @"Geef je oordeel in de App Winkel!",
                @"Later" : @"Later",
                @"Rate it!" : @"Beoordeel ons!",
            },
            @"pt":@{
                @"Like this app?" : @"Gosta Deste App?",
                @"Please rate it on the App Store!" : @"Por favor, avalie-o na App Store!",
                @"Later" : @"Mais Tarde",
                @"Rate it!" : @"Avalie!",
            },
            @"ru":@{
                @"Like this app?" : @"Понравилось приложение?",
                @"Please rate it on the App Store!" : @"Пожалуйста, оцените нас на App Store!",
                @"Later" : @"Позже",
                @"Rate it!" : @"Оценить!",
            },
            @"sv":@{
                @"Like this app?" : @"Gillar du denna app?",
                @"Please rate it on the App Store!" : @"Betygsätt den i App Store!",
                @"Later" : @"Senare",
                @"Rate it!" : @"Betygsätt den!",
            },
            @"zh-hans":@{
                @"Like this app?" : @"喜歡此應用程式?",
                @"Please rate it on the App Store!" : @"請在App Store給它評分!",
                @"Later" : @"以後提醒",
                @"Rate it!" : @"給它評分!",
            },
            @"zh-hant":@{
                @"Like this app?" : @"喜歡此應用程式?",
                @"Please rate it on the App Store!" : @"請在App Store給它評分!",
                @"Later" : @"以後提醒",
                @"Rate it!" : @"給它評分!",
            }
            };
    }
    NSDictionary* d = [v objectForKey:news_lc()];
    if (!d){
        d = [v objectForKey:@"en"];
    }
    return d;
}

NSString* news_reviewTitle()
{
    return [newsLocalizedStrings() objectForKey:@"Like this app?"];
}

NSString* news_reviewMessage()
{
    return [newsLocalizedStrings() objectForKey:@"Please rate it on the App Store!"];
}

NSString* news_reviewRate()
{
    return [newsLocalizedStrings() objectForKey:@"Rate it!"];
}

NSString* news_reviewLater()
{
    return [newsLocalizedStrings() objectForKey:@"Later"];
}

#endif//#if SMARTNEWS_COMPILE
