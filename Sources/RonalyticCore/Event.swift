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
    /// Values written by the developer.
    public var properties: [String: PropertyValue]
    /// Facts about the environment, written by the SDK (device, app, network).
    public var context: [String: PropertyValue]

    public init(
        id: String,
        name: String,
        type: EventType,
        timestamp: Date,
        sessionID: String,
        userID: String?,
        properties: [String: PropertyValue],
        context: [String: PropertyValue] = [:],
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
        self.context = context
    }
}
