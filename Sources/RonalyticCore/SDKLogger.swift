//
// Copyright (c) 2026 Enjel Hutasoit
//

/// How loud the SDK is. A level shows itself and everything quieter.
public enum LogLevel: Int, Sendable, Comparable {
    case off = 0
    case error
    case info
    case verbose

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .off: return "off"
        case .error: return "error"
        case .info: return "info"
        case .verbose: return "verbose"
        }
    }
}

/// Receives the SDK's own diagnostic messages.
/// The message is an autoclosure: the text is only built when it is used.
public protocol SDKLogger: Sendable {
    func log(_ level: LogLevel, _ message: @autoclosure () -> String)
}

/// Default logger. Does nothing and costs nothing.
public struct NoOpLogger: SDKLogger {
    public init() {}

    public func log(_ level: LogLevel, _ message: @autoclosure () -> String) {}
}
