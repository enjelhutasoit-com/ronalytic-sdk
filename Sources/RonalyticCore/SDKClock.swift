//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Source of time for the SDK. Injected so tests control "now" and waiting.
public protocol SDKClock: Sendable {
    func now() -> Date
    func sleep(for duration: Duration) async throws
}

public struct SystemClock: SDKClock {
    public init() {}

    public func now() -> Date { Date() }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
