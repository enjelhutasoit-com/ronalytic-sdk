//
// Copyright (c) 2026 Enjel Hutasoit
//

/// What to discard when the queue is full.
public enum DropPolicy: Sendable, Equatable {
    /// Discard the oldest stored events to make room for new ones.
    case dropOldest
    /// Keep stored events and discard the incoming ones.
    case dropNewest
}
