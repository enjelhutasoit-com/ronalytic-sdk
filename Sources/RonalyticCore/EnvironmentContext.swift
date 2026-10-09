//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Facts about the device and the app an event came from.
public struct EnvironmentContext: Sendable, Equatable {
    public let osName: String
    public let osVersion: String
    public let model: String
    public let locale: String
    public let appVersion: String
    public let appBuild: String
    public let bundleID: String

    public init(
        osName: String,
        osVersion: String,
        model: String,
        locale: String,
        appVersion: String,
        appBuild: String,
        bundleID: String
    ) {
        self.osName = osName
        self.osVersion = osVersion
        self.model = model
        self.locale = locale
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.bundleID = bundleID
    }

    /// Flat keys, as written into `Event.context`.
    var properties: [String: PropertyValue] {
        [
            "os.name": .string(osName),
            "os.version": .string(osVersion),
            "device.model": .string(model),
            "locale": .string(locale),
            "app.version": .string(appVersion),
            "app.build": .string(appBuild),
            "app.bundleID": .string(bundleID)
        ]
    }
}
