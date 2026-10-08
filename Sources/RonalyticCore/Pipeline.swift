//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Runs plugins in order. Each plugin gets the previous plugin's output.
/// A nil result drops the event and skips the remaining plugins.
struct Pipeline: Sendable {
    private let plugins: [any Plugin]

    init(plugins: [any Plugin]) {
        self.plugins = plugins
    }

    func run(_ event: Event) async -> Event? {
        var current = event
        for plugin in plugins {
            guard let next = await plugin.process(current) else { return nil }
            current = next
        }
        return current
    }
}
