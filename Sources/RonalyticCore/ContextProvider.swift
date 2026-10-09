//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Supplies device and app facts. Injected so tests control the values.
public protocol ContextProvider: Sendable {
    func current() async -> EnvironmentContext
}
