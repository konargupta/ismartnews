# Purpose
Library contains code that helps to integrate support of downloading of some news into iOS applications. 
News are downloaded from specified addresses and then presented to user. Message can be presented only once or many times. 
Message can contain title, text, link to open, and one or two buttons.

# Intergation with application

```objc
#import "iSmartEventsCenter.h"
#import "iSmartNews.h"
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    ...
    [[iSmartNews sharedNews] setUrl:[NSURL URLWithString:@"http://www.news.com/news.plist"]];
    [[iSmartNews sharedNews] setITunesId:APPSTORE_APP_ID];
    ...
}
```

# Embedded News
For managing embedded news used independent instance - sharedAdvertising. Embedded News is webpage based news like as interstitial (full screen) but showing in special views - Embedded Panels.
For create new Embedded Panel, send message "getEmbeddedPanelForEvents" to "sharedAdvertising" instance with event names. Application can create any number of such panels. Each created panel has unique identifier, which using for their releasing ("kick it"). Each panel should have one or more assigned events.
Activate panel for start rotation news. Which content of first news was loaded, panel change status to "ready" (with notification by delegate). When last news was closed, and new news not available, panel change status to "not Ready".
After using panel, application should release panel by sending message "kickEmbeddedPanelWithUUID" with its unique identifier (uuid). After panel was released, events assigned with it will become available for use in new panels.

### Note
Each event can be assigned to single panel only, but panel may has unlimited number of assigned events. Trying create new panel least with one used event will finished with failure.
Recomended deactivate panel when hide its, and activate it when showing again.

Example:
```objc
-(void)viewWillAppear:(BOOL)animated
{
    ...
    if (_panel)
    {
        [_panel setActive:YES]; //Activate panel for start loading and rotation news
    }
    ...
}
-(void)viewWillDisappear:(BOOL)animated
{
    ...
    if (_panel)
    {
        [_panel setActive:NO]; //Deactivate panel for stop rotation news
    }
    ...
}
-(void)makeEmbeddePanel
{
    NSError* error = nil;
    _panel = [[iSmartNews sharedAdvertising] getEmbeddedPanelForEvents:@[@"embedded:news:1", @"embedded:news:2"] error:&error];
    if ((error == nil) && (_panel != nil))
    {
        [_panel setDelegate:self];
        [_panel setActive:YES]; //Activate panel for start loading and rotation news
    }
}
-(void)panelDidChangeStatus:(UIView<iSmartNewsPanelProtocol> *)panel
{
    if ([_panel isReady])
    {
        //Show panel when ready
        [[self view] addSubview:_panel];
        [_panel setFrame:CGRectMake(0, 0, self.view.frame.size.width, 300)];
    }
    else
    {
        [_panel removeFromSuperview];
    }
}
-(void)dealloc
{
    if (_panel)
    {
        [[iSmartNews sharedAdvertising] kickEmbeddedPanelWithUUID:_panel.uuid]; //Kick the panel for the possibility of re-using the assigned events ("embedded: news: 1" and "embedded: news: 2").
        _panel = nil;
    }
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

## Style
News messages will shown only, after content was sucesfully loaded. Also, most news showing with "standard" animation, which does not always fit. To customize the appearance of the news display process, a new "style" key was added. For example see:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>meta</key>
        <dict>
            <key>uuid</key>
            <string>some_news</string>
            <key>style</key>
            <dict>
                 <key>show_loading</key>
                 <dict>
                     <key>animation</key>
                     <string>modal</string>
                     <key>indicator</key>
                     <string>ff0000</string>
                     <key>backround</key>
                     <string>ffff00</string>
                     <key>blur</key>
                     <string>regular</string>
                 </dict>
            </dict>
            <key>urls</key>
            <array>
                <string>http://my.server.com/banner_001.html</string>
                <string>http://my.server.com/banner_002.html</string>
            </array>
        </dict>
    </dict>
</array>
</plist>
```

Description of style is a dictionary with list of modes (as keys) and optional parameters (dictionary by corresponding key).