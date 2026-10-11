# Ronalytic

[![CI](https://github.com/enjelhutasoit-com/ronalytic-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/enjelhutasoit-com/ronalytic-sdk/actions/workflows/ci.yml)
[![Docs](https://github.com/enjelhutasoit-com/ronalytic-sdk/actions/workflows/docs.yml/badge.svg)](https://enjelhutasoit-com.github.io/ronalytic-sdk/documentation/ronalyticcore/)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![iOS 16+](https://img.shields.io/badge/iOS-16%2B-blue)
![License MIT](https://img.shields.io/badge/license-MIT-green)

A small, modular analytics SDK for iOS. Track once, send to any destination,
and swap vendors by changing one line. Zero third-party dependencies.

```swift
import Ronalytic
import RonalyticFileStorage
import RonalyticHTTP

var config = RonalyticConfig.iOSDefaults(
    storage: FileQueueStorage(directory: queueFolder, writerID: "app"),
    transport: HTTPTransport(endpoint: url)
)
config.plugins = [ConsoleDestination()]   // swap or add vendors here
RonalyticSDK.configure(config)

RonalyticSDK.track("purchase", properties: ["price": 9.99, "qty": 2])
```

Call sites never block and never throw.

## Installation

Swift Package Manager:

```swift
.package(url: "https://github.com/enjelhutasoit-com/ronalytic-sdk", from: "1.0.0")
```

| Product | Use it for |
|---|---|
| `Ronalytic` | The main app. Core plus lifecycle, with `iOSDefaults`. |
| `RonalyticCore` | App extensions and widgets. No UIKit. |
| `RonalyticFileStorage` | Persistent queue on disk, App Group support. |
| `RonalyticHTTP` | Batch upload over HTTP. |
| `RonalyticTestSupport` | Fakes and stubs for your own tests. Test targets only. |

## Features

- Typed, versioned event model with stable event IDs
- Plugin pipeline: enrichers, filters and destinations run in order
- Persistent, ordered, bounded queue with a drop policy
- Batching by size and interval, retry with exponential backoff and jitter
- At-least-once delivery with per-event partial failure handling
- Context (device, app, OS, locale, network) and session tracking
- Consent gate, opt-out and PII redaction rules
- Console destination and verbose debug logging
- Flush on background, inside a background task
- App Group queue shared with extensions and widgets
- Read-only diagnostics: drops, retries, failures, flush time

## Design decisions

**Protocols for everything external.** Storage, transport, clock, ID generator,
lifecycle, consent and network state are protocols passed in at init.
*Why:* tests control time, IDs and failures, so retry and crash tests run
instantly and never flake. *Cost:* more types, and one extra step to wire them.

**Core never imports UIKit.** Lifecycle and background tasks live in a separate
module, and `Ronalytic` combines them.
*Why:* app extensions cannot use `UIApplication.shared`, and pure Foundation code
tests in seconds on macOS. *Cost:* an extra module and an umbrella.

**At-least-once, not exactly-once.** Events are peeked, sent, and removed only
after confirmation. Every event has a stable ID.
*Why:* a client cannot know whether the server received a batch when the
connection drops, so losing data is the only unacceptable outcome. The server can
drop duplicates by ID. *Cost:* duplicates are possible. See the delivery
guarantees article in the documentation.

**Per-event results, not per-batch.** `Transport` returns delivered, retryable
and rejected groups. Events the server does not mention are retried.
*Why:* one bad event must not cause 49 good ones to be resent or lost.
*Cost:* the backend should answer per event to benefit. Without a body, a 2xx
means everything was delivered.

**Append-only JSON Lines, one file per writer.** Removal is recorded in a
tombstone file, and each writer only cleans its own files.
*Why:* a crash can only damage the last line, and the app and its extensions
never write to the same file, so no cross-process locks are needed.
*Cost:* reads merge several files, and cleanup is deferred. This is fine for a
queue capped at about a thousand events.

**Extensions only write.** `RonalyticExtension` has no transport, timer or retry.
*Why:* extensions are short-lived and may be killed at any moment, so uploading
from there is unreliable. *Cost:* extension events are sent when the main app
runs next.

**Synchronous front door, serialized back end.** `track()` stamps the ID, time
and session on the caller's thread, then pushes a message into an `AsyncStream`.
One actor handles messages in order.
*Why:* no blocking, no throwing, and event order equals call order.
*Cost:* a few small locks exist where an actor would force `await`.

**Small public API, checked in CI.** Only what developers need is `public`. A
baseline of public symbols is committed and CI fails when it changes by accident.
*Why:* after 1.0, changing public API needs a major version.
*Cost:* intended changes need a baseline update in the same pull request.

**Privacy by default.** Unknown consent drops events, redaction runs before
storage and before any destination, and no advertising ID or location is read.
*Why:* data that never reaches the disk cannot leak. *Cost:* developers must
opt in to redaction rules and to tracking while consent is unknown.

## Known limitations

- Delivery is at-least-once. Server-side dedup by event ID is needed for
  exactly-once effects.
- Extensions write only. They do not upload.
- Two processes using the same writer ID at once can interleave lines. Use a
  different fixed writer ID per process.
- PII redaction is regex based. It does not detect names or addresses.
- Metrics live in memory and reset when the app restarts.
- Background time can run out while a retry is waiting. Events stay on disk and
  are sent later.
- UIKit-only API is not covered by the automated API check, because it runs on
  macOS: `RonalyticConfig.iOSDefaults`, `NotificationLifecycleObserver.Names.uiKit`
  and `UIApplicationBackgroundTaskAPI`.

## Roadmap

1.1 schema versioning and queue migration, 1.2 remote config and kill switch,
1.3 privacy extras, 1.4 typed events, 1.5 API diff in CI, 1.6 SQLite storage.
Firebase and Amplitude destinations will ship as separate packages.

## Documentation

API reference and articles: https://enjelhutasoit-com.github.io/ronalytic-sdk/documentation/ronalyticcore/

## License

MIT
