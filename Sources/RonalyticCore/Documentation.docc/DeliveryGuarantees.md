# Delivery guarantees

What the SDK promises about your events, and what it does not.

## At-least-once retry semantics

Events that remain in a healthy queue are retried after temporary delivery
failures. If the backend eventually accepts them and a later flush completes,
they may be delivered more than once.

This is not an unconditional delivery guarantee. Queue capacity policies,
consent and plugin filtering, permanent server rejection, storage failures,
and process termination before persistence can prevent delivery.

## Duplicates and event IDs

A resend can create a duplicate. Every event has a stable `id` that does not
change between attempts. The backend should deduplicate by event ID to prevent
duplicate processing.

## Ordering

Events are read from the front of the queue. Retryable events stay queued
unless a capacity policy evicts them. Partial acknowledgements can complete
some events before earlier ones, so the SDK does not guarantee strict
server-side delivery order.

## Partial failure

If the server answers per event, delivered and permanently rejected events
are removed and retryable ones stay for another attempt with exponential
backoff and jitter. Events the server did not mention are retried.

The HTTP transport retains malformed structured acknowledgements and invalid
UTF-8 responses. HTTP 401, 403 and 413 retain events for later attempts.
Authentication recovery and oversized batch handling may require host or
backend changes. For compatibility, empty or legacy non-report 2xx responses
still acknowledge the whole batch.

## What is not promised

Exactly-once delivery is not possible from the client alone. Stable event IDs
allow the server to implement idempotent processing. Retrying is bounded per
flush; a subsequent flush is needed after retries are exhausted.
