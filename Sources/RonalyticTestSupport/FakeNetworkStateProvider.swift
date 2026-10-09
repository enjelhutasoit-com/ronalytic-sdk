//
// Copyright (c) 2026 Enjel Hutasoit
//

import RonalyticCore

/// Network provider whose state tests can change.
public actor FakeNetworkStateProvider: NetworkStateProvider {
    private var state: NetworkState

    public init(_ state: NetworkState = .wifi) {
        self.state = state
    }

    public func setState(_ newState: NetworkState) {
        state = newState
    }

    public func current() async -> NetworkState { state }
}
