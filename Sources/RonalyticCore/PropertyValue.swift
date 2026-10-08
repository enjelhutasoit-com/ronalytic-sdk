//
// Copyright (c) 2026 Enjel Hutasoit
//

/// A JSON-friendly value. Typed so properties stay Sendable and Codable.
public enum PropertyValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

extension PropertyValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Order matters: bool and int must be tried before double.
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.typeMismatch(
                PropertyValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported property value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }
}
