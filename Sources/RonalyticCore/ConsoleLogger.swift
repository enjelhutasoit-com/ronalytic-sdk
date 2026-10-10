//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Prints SDK diagnostics, filtered by level.
public struct ConsoleLogger: SDKLogger {
    private let level: LogLevel
    private let output: @Sendable (String) -> Void

    public init(
        level: LogLevel = .verbose,
        output: @escaping @Sendable (String) -> Void = { print($0) }
    ) {
        self.level = level
        self.output = output
    }

    public func log(_ messageLevel: LogLevel, _ message: @autoclosure () -> String) {
        guard messageLevel != .off, messageLevel <= level else { return }

        output("[Ronalytic][\(messageLevel.label)] \(message())")
    }
}
