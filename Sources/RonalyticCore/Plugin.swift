//
// Copyright (c) 2026 Enjel Hutasoit
//

/// A step in the event pipeline: enricher, filter or destination.
/// Return nil to drop the event.
public protocol Plugin: Sendable {
    var name: String { get }
    func process(_ event: Event) async -> Event?
}
