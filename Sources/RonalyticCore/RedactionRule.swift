//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// One rule that cleans a single property before the event is stored.
/// Return nil to remove the property, or a value to keep or replace it.
public struct RedactionRule: Sendable {
    let apply: @Sendable (_ key: String, _ value: PropertyValue) -> PropertyValue?

    /// Write your own rule.
    public init(_ apply: @escaping @Sendable (_ key: String, _ value: PropertyValue) -> PropertyValue?) {
        self.apply = apply
    }

    /// Replaces email addresses inside text with `[redacted-email]`.
    public static let maskEmails = maskStrings(
        pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        replacement: "[redacted-email]"
    )

    /// Replaces phone numbers inside text with `[redacted-phone]`.
    /// Heuristic: 9 or more digits, optionally with spaces, dashes, dots or brackets.
    public static let maskPhoneNumbers = maskStrings(
        pattern: #"\+?\d[\d\s().-]{7,}\d"#,
        replacement: "[redacted-phone]"
    )

    /// Removes properties by key name. Ignores upper and lower case.
    public static func removeKeys(_ keys: Set<String>) -> RedactionRule {
        let lowered = Set(keys.map { $0.lowercased() })
        return RedactionRule { key, value in
            if lowered.contains(key.lowercased()) { return nil }
            return value
        }
    }

    private static func maskStrings(pattern: String, replacement: String) -> RedactionRule {
        RedactionRule { _, value in
            guard case .string(let text) = value else { return value }
            let masked = text.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
            return .string(masked)
        }
    }
}
