//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Source of unique event IDs. Injected so tests get predictable IDs.
public protocol IDGenerator: Sendable {
    func makeID() -> String
}

public struct UUIDGenerator: IDGenerator {
    public init() {}

    public func makeID() -> String { UUID().uuidString }
}
