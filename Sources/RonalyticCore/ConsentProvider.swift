//
// Copyright (c) 2026 Enjel Hutasoit
//

public enum ConsentStatus: Sendable, Equatable {
    case granted
    case denied
    case unknown
}

/// Tells the SDK whether the user allowed tracking.
/// Typically backed by the app's own consent dialog.
public protocol ConsentProvider: Sendable {
    func status() async -> ConsentStatus
}
