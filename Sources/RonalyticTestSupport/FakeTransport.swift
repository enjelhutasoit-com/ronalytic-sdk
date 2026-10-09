//
// Copyright (c) 2026 Enjel Hutasoit
//

import RonalyticCore

/// Scriptable Transport for tests. Plays the given responses in order,
/// then delivers everything. Records every batch it receives.
public actor FakeTransport {
    private var response = [Response]
    
    public init(response: [Response] = []) {
        self.response = response
    }
    
    public func send(_ batch: [Event]) async throws -> DeliveryResult {
        
    }
}
