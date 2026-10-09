//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport

final class FakeTransportTests: XCTestCase {
    func test_defaultsToDeliveringEverything() async throws {
        let transpot = FakeTransport()
        
        let result = try await transport.send()
        
        
    }
    
}
