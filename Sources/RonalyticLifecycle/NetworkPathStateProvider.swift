//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// Reports the real network state. Reads the last value the monitor delivered,
/// so `current()` is instant. Until the monitor reports, the answer is `unknown`.
public final class NetworkPathStateProvider: NetworkStateProvider, @unchecked Sendable {
    private let monitor: any PathMonitoring
    private let lock = NSLock()
    private var state: NetworkState = .unknown

    /// Starts monitoring with the system's NWPathMonitor.
    public convenience init() {
        self.init(monitor: NWPathMonitorAdapter())
    }

    init(monitor: any PathMonitoring) {
        self.monitor = monitor
        monitor.start { [weak self] snapshot in
            self?.update(Self.state(for: snapshot))
        }
    }

    deinit {
        monitor.stop()
    }

    public func current() async -> NetworkState {
        lock.withLock { state }
    }

    private func update(_ newState: NetworkState) {
        lock.withLock { state = newState }
    }

    /// Not satisfied is offline. Otherwise wifi, cellular, wired, in that order.
    static func state(for snapshot: NetworkPathSnapshot) -> NetworkState {
        guard snapshot.isSatisfied else { return .offline }

        let order: [(NetworkPathSnapshot.Interface, NetworkState)] = [
            (.wifi, .wifi), (.cellular, .cellular), (.wired, .wired)
        ]
        for (interface, state) in order where snapshot.interfaces.contains(interface) {
            return state
        }
        return .unknown
    }
}
