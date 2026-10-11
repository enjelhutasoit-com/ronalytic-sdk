# Changelog

All notable changes are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com), and versions follow
[Semantic Versioning](https://semver.org).

## [Unreleased]

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
- Test support module with fakes, stubs and spies
- DocC documentation and a public API baseline checked in CI
