//
// Copyright (c) 2026 Enjel Hutasoit
//

import RonalyticCore

public extension EnvironmentContext {
    /// Fixed values for tests.
    static let fixture = EnvironmentContext(
        osName: "iOS",
        osVersion: "17.2.1",
        model: "iPhone15,2",
        locale: "en_US",
        appVersion: "2.3.0",
        appBuild: "45",
        bundleID: "com.example.app"
    )
}

/// Returns the context it was given.
public struct FakeContextProvider: ContextProvider {
    private let context: EnvironmentContext

    public init(_ context: EnvironmentContext = .fixture) {
        self.context = context
    }

    public func current() async -> EnvironmentContext { context }
}
