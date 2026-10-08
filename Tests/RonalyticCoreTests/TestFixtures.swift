//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
@testable import RonalyticCore

func makeTestEvent(name: String = "purchase") -> Event {
    Event(
        id: "evt-1",
        name: name,
        type: .track,
        timestamp: Date(timeIntervalSince1970: 1_000),
        sessionID: "sess-1",
        userID: nil,
        properties: ["price": .double(9.99)]
    )
}
