//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Keeps the app alive while a piece of work finishes, for example an upload
/// after the app moved to the background. The real one lives in RonalyticLifecycle.
public protocol BackgroundTaskRunner: Sendable {
    func run(_ work: @Sendable () async -> Void) async
}

/// Default. Just runs the work and asks the system for nothing.
public struct ImmediateBackgroundTaskRunner: BackgroundTaskRunner {
    public init() {}

    public func run(_ work: @Sendable () async -> Void) async {
        await work()
    }
}
