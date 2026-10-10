//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Collects printed lines in tests. Thread-safe.
final class LineRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedLines: [String] = []

    var lines: [String] {
        lock.withLock { storedLines }
    }

    func add(_ line: String) {
        lock.withLock { storedLines.append(line) }
    }
}
