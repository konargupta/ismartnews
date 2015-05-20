# Purpose
Library contains code that helps to integrate support of downloading of some news into iOS applications. 
News are downloaded from specified addresses and then presented to user. Message can be presented only once or many times. 
Message can contain title, text, link to open, and one or two buttons.

# Intergation with application

```objc
#import "iSmartNews.h"
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    ...
    [[iSmartNews sharedNews] setUrl:[NSURL URLWithString:@"http://www.news.com/news.plist"]];
    [[iSmartNews sharedNews] setITunesId:APPSTORE_APP_ID];
    ...
}
```

# Configuaration examples and events

## Structure of PLIST news file
Smart news file should be an array in OS X plist/XML format. Each item of array describes news item or special configurations.

## Events
By default news are activated after application becomes active. But framework makes possible to set some other events to be used as activation point for news. All suppored event are defined by programmer while application development. Default 'app:activate' event is embedded into smart news code. Events can be divided into two groups:

global - used for all news item which do not contain own event.
local - used for concrete news item.

Global events are described by dictionary placed as item of root array in file. This dictionary must have 'event' key containing dictionary, where key is name of event and value is pattern of event. Pattern is special entity used to define how events will be processed and treated. Let us see an example: we have pattern 'ON=2|OFF=4', it means that two times in sequence event will show news, then four times in sequence event will be ignore, and so on... You can set description of any complexity, for example: 'ON=1|OFF=4|ON=5|OFF=3'.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>event</key>
        <dict>
            <key>name</key>
            <string>app:activate</string>
            <key>pattern</key>
            <string>ON=2|OFF=4</string>
        </dict>
    </dict>
    <dict>
        <key>meta</key>
        <dict>
            <key>uuid</key>
            <string>test2</string>
            <key>urls</key>
            <array>
                <string>http://127.0.0.1:8011/banner-003.html</string>
                <string>http://127.0.0.1:8011/banner-004.html</string>
            </array>
        </dict>
    </dict>
</array>
</plist>
```

Example below shows how local events can be described. Local events have meaning only for news item containing these events. Global events for such news are ignored.
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>meta</key>
        <dict>
            <key>events</key>
            <dict>
                <key>event2</key>
                <string>ON=3|OFF=1</string>
                <key>event3</key>
                <string>ON=3|OFF=1</string>
            </dict>
            <key>uuid</key>
            <string>test3</string>
            <key>urls</key>
            <array>
                <string>http://127.0.0.1:8011/banner-004.html</string>
            </array>
        </dict>
    </dict>
</array>
</plist>
```