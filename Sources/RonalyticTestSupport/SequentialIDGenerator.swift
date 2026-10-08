//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// Predictable IDs for tests: "id-1", "id-2", ...
public final class SequentialIDGenerator: IDGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private let prefix: String
    private var counter = 0

    public init(prefix: String = "id") {
        self.prefix = prefix
    }

    public func makeID() -> String {
        lock.withLock {
            counter += 1
            return "\(prefix)-\(counter)"
        }
    }
}
