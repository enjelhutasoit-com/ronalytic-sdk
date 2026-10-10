//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Applies redaction rules to `Event.properties`, in order.
struct Redactor: Plugin {
    let name = "redactor"

    let rules: [RedactionRule]

    func process(_ event: Event) async -> Event? {
        guard !rules.isEmpty else { return event }

        var redacted = event
        redacted.properties = [:]
        for (key, original) in event.properties {
            if let value = apply(rules, key: key, value: original) {
                redacted.properties[key] = value
            }
        }
        return redacted
    }

    private func apply(_ rules: [RedactionRule], key: String, value: PropertyValue) -> PropertyValue? {
        var current: PropertyValue? = value
        for rule in rules {
            guard let existing = current else { return nil }
            current = rule.apply(key, existing)
        }
        return current
    }
}
