//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

public enum EventType: String, Sendable, Codable {
    case track, identify, screen
}

public struct Event: Sendable, Codable, Equatable, Identifiable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public var name: String
    public let type: EventType
    public let timestamp: Date
    public let sessionID: String
    public var userID: String?
    public var properties: [String: PropertyValue]

    public init(
        id: String,
        name: String,
        type: EventType,
        timestamp: Date,
        sessionID: String,
        userID: String?,
        properties: [String: PropertyValue],
        schemaVersion: Int = Event.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.type = type
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.userID = userID
        self.properties = properties
    }
}
