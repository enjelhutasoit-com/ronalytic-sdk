//
// Copyright (c) 2026 Enjel Hutasoit
//

/// The small part of the system we need for background time.
/// The UIKit adapter implements it. Tests use a fake.
public protocol BackgroundTaskAPI: Sendable {
    /// Returns a task identifier, or nil when the system refuses.
    /// `onExpiration` is called when the system says time is up.
    func beginTask(name: String, onExpiration: @escaping @Sendable () -> Void) async -> Int?

    func endTask(_ id: Int)
}
