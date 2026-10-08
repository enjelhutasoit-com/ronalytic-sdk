//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

public extension Event {
    /// Quick event for tests. Only `id` usually matters.
    static func fixture(
        id: String = "evt-1",
        name: String = "test"
    ) -> Event {
        Event(
            id: id,
            name: name,
            type: .track,
            timestamp: Date(timeIntervalSince1970: 1_000),
            sessionID: "sess-1",
            userID: nil,
            properties: [:]
        )
    }
}
