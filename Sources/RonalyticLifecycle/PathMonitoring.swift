//
// Copyright (c) 2026 Enjel Hutasoit
//

/// What we need to know about the current network path.
struct NetworkPathSnapshot: Sendable, Equatable {
    enum Interface: Sendable, Equatable {
        case wifi
        case cellular
        case wired
        case other
    }

    let isSatisfied: Bool
    let interfaces: [Interface]
}

/// Reports network path changes. The real one wraps NWPathMonitor.
protocol PathMonitoring: Sendable {
    func start(onChange: @escaping @Sendable (NetworkPathSnapshot) -> Void)
    func stop()
}
