//
// Copyright (c) 2026 Enjel Hutasoit
//

public enum NetworkState: String, Sendable, Equatable {
    case wifi
    case cellular
    case wired
    case offline
    case unknown
}

/// Reports the current network state. A real implementation comes later.
public protocol NetworkStateProvider: Sendable {
    func current() async -> NetworkState
}

/// Default until a real provider is given. Honest about not knowing.
public struct UnknownNetworkStateProvider: NetworkStateProvider {
    public init() {}

    public func current() async -> NetworkState { .unknown }
}
