//
// Copyright (c) 2026 Enjel Hutasoit
//

import Network

/// Wraps Apple's NWPathMonitor. Not unit tested: tried in the demo app.
final class NWPathMonitorAdapter: PathMonitoring, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.ronalytic.network-path")

    func start(onChange: @escaping @Sendable (NetworkPathSnapshot) -> Void) {
        monitor.pathUpdateHandler = { path in
            onChange(NetworkPathSnapshot(
                isSatisfied: path.status == .satisfied,
                interfaces: Self.interfaces(of: path)
            ))
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    private static func interfaces(of path: NWPath) -> [NetworkPathSnapshot.Interface] {
        var result: [NetworkPathSnapshot.Interface] = []
        if path.usesInterfaceType(.wifi) { result.append(.wifi) }
        if path.usesInterfaceType(.cellular) { result.append(.cellular) }
        if path.usesInterfaceType(.wiredEthernet) { result.append(.wired) }
        if result.isEmpty { result.append(.other) }
        return result
    }
}
