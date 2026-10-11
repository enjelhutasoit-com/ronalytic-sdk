# Delivery guarantees

What the SDK promises about your events, and what it does not.

## At-least-once

Every event is delivered one or more times, never zero. An event leaves the
queue only after the server confirms it, so a crash or lost connection causes
a resend, not a loss.

## Duplicates and event IDs

A resend can create a duplicate. Every event has a stable `id` that never
changes between attempts, so the server can drop repeats.

## Ordering

Events are read from the front of the queue and removed only after
confirmation. An event that failed stays in front of newer ones.

## Partial failure

If the server answers per event, delivered and rejected events are removed and
retryable ones stay for another attempt with exponential backoff and jitter.
Events the server did not mention are retried.

## What is not promised

Exactly-once delivery is not possible from the client alone. The SDK gives
at-least-once plus stable IDs, so a server can achieve exactly-once effects.
