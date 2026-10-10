//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Drops every event unless the user gave consent.
/// Must run first in the pipeline.
struct ConsentGate: Plugin {
    let name = "consent-gate"

    let provider: any ConsentProvider
    let allowWhenUnknown: Bool

    func process(_ event: Event) async -> Event? {
        switch await provider.status() {
        case .granted: return event
        case .denied: return nil
        case .unknown: return allowWhenUnknown ? event : nil
        }
    }
}
