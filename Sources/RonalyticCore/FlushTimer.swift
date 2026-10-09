//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Calls `onTick` once per interval until cancelled or the clock's sleep fails.
enum FlushTimer {
    static func run(
        every interval: Duration,
        clock: any SDKClock,
        onTick: @Sendable () async -> Void
    ) async {
        while !Task.isCancelled {
            do {
                try await clock.sleep(for: interval)
            } catch {
                return
            }
            await onTick()
        }
    }
}
