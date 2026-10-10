//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Prints every event as one line, then passes it on. For demos and debugging.
public struct ConsoleDestination: Plugin {
    public let name = "console-destination"

    private let output: @Sendable (String) -> Void

    public init(output: @escaping @Sendable (String) -> Void = { print($0) }) {
        self.output = output
    }

    public func process(_ event: Event) async -> Event? {
        let user = event.userID ?? "-"
        let props = event.properties
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value.logText)" }
            .joined(separator: ", ")

        output(
            "[Ronalytic] \(event.type.rawValue) \"\(event.name)\" " +
            "user=\(user) session=\(event.sessionID) props={\(props)}"
        )
        return event
    }
}

private extension PropertyValue {
    var logText: String {
        switch self {
        case .string(let value): return "\"\(value)\""
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .bool(let value): return "\(value)"
        }
    }
}
