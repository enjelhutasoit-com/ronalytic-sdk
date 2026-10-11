//
// Copyright (c) 2026 Enjel Hutasoit
//

import RonalyticCore

/// Lifecycle observer driven by tests. Supports a single consumer.
public final class FakeLifecycleObserver: LifecycleObserver, Sendable {
    private let stream: AsyncStream<LifecycleEvent>
    private let continuation: AsyncStream<LifecycleEvent>.Continuation

    public init() {
        let (stream, continuation) = AsyncStream.makeStream(of: LifecycleEvent.self)
        self.stream = stream
        self.continuation = continuation
    }

    public func events() -> AsyncStream<LifecycleEvent> { stream }

    public func send(_ event: LifecycleEvent) {
        continuation.yield(event)
    }

    /// Ends the stream, so a consumer loop finishes after the buffered events.
    public func finish() {
        continuation.finish()
    }
}
