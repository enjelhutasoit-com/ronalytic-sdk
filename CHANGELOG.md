# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com), and versions follow
[Semantic Versioning](https://semver.org).

## [Unreleased]

## [1.0.1] - 2026-11-25

### Fixed

- Retain HTTP batches when structured acknowledgements are malformed or the
  server responds with 401, 403 or 413, instead of permanently removing events.
- Treat invalid UTF-8 acknowledgements as retryable.
- Count only successfully appended events in `eventsStored`; subsequent queue
  evictions remain separately counted. Update logs to distinguish writes and drops.
- Repair CI workflow syntax, coverage validation, simulator provisioning and
  public API extraction, including XCTest framework resolution.

### Changed

- Pin the CI toolchain and SwiftLint version; verify the SwiftLint archive digest.
- Retain test result bundles and raw coverage reports for CI diagnostics.
- Require the shared CI quality gates before publishing a GitHub Release.
- Clarify conditional delivery guarantees and the limitations of legacy HTTP
  acknowledgements.

## [1.0.0] - 2026-10-16

### Added

- Typed, versioned event model with stable event IDs
- Plugin pipeline with enrichers, filters and destinations
- Persistent, ordered, bounded queue with `dropOldest` and `dropNewest`
- Batching by size and interval
- Retry with exponential backoff and jitter
- At-least-once delivery with per-event partial failure handling
- Context (device, app, OS, locale, network) and session tracking
- Consent gate, opt-out and PII redaction rules
- Console destination and verbose debug logging
- Flush on background, inside a background task
- File queue storage (JSON Lines, one segment per writer) with compaction
  and corruption recovery
- App Group shared queue and `RonalyticExtension` for extensions and widgets
- HTTP transport with status mapping and per-event response reports
- Read-only diagnostics: drops, retries, failures and flush time
- `RonalyticConfig.iOSDefaults` for one-line setup in the main app
- `RonalyticSDK.isOptedOut()` and public `waitUntilIdle()` on the client and `RonalyticSDK`
- Test support module with fakes, stubs and spies
- DocC documentation and a public API baseline checked in CI
