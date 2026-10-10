//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

public struct LogEntry: Sendable, Equatable {
    public let level: LogLevel
    public let message: String

    public init(_ level: LogLevel, _ message: String) {
        self.level = level
        self.message = message
    }
}

/// Logger that remembers everything it receives. For tests.
public final class RecordingLogger: SDKLogger, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [LogEntry] = []

    public init() {}

    public var entries: [LogEntry] {
        lock.withLock { recorded }
    }

    public func log(_ level: LogLevel, _ message: @autoclosure () -> String) {
        let text = message()
        lock.withLock { recorded.append(LogEntry(level, text)) }
    }
}
