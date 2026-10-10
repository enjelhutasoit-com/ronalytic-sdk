//
// Copyright (c) 2026 Enjel Hutasoit
//

import RonalyticCore

/// Consent provider whose status tests can change.
public actor FakeConsentProvider: ConsentProvider {
    private var current: ConsentStatus

    public init(_ status: ConsentStatus = .granted) {
        self.current = status
    }

    public func setStatus(_ status: ConsentStatus) {
        current = status
    }

    public func status() async -> RonalyticCore.ConsentStatus { current }
}
