# Getting started

Add Ronalytic to your app and send your first event.

## Add the package

In Xcode choose File, Add Package Dependencies, paste the repository URL and
add the `Ronalytic` product to your app target. Also add `RonalyticFileStorage`
and `RonalyticHTTP` if you use the built-in storage and transport.

## Configure once at launch

Call configure as early as possible. Calls made before it are ignored.

```swift
import Ronalytic
import RonalyticFileStorage
import RonalyticHTTP

var config = RonalyticConfig.iOSDefaults(
    storage: FileQueueStorage(directory: queueFolder, writerID: "app"),
    transport: HTTPTransport(endpoint: url)
)
config.plugins = [ConsoleDestination()]
RonalyticSDK.configure(config)
```

## Track events

```swift
RonalyticSDK.track("purchase", properties: ["price": 9.99, "qty": 2])
RonalyticSDK.screen("Home")
RonalyticSDK.identify("user-42", traits: ["plan": "pro"])
```

These calls return immediately and never throw.

## Change vendors

Destinations are plugins. To add or swap one, edit the `plugins` list.
No call site changes.
