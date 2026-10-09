//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Reads the real environment using Foundation only (no UIKit).
public struct SystemContextProvider: ContextProvider {
    public init() {}

    public func current() async -> EnvironmentContext {
        let info = Bundle.main.infoDictionary
        let version = ProcessInfo.processInfo.operatingSystemVersion

        return EnvironmentContext(
            osName: Self.osName,
            osVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            model: Self.machine,
            locale: Locale.current.identifier,
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info?["CFBundleVersion"] as? String ?? "unknown",
            bundleID: Bundle.main.bundleIdentifier ?? "unknown"
        )
    }

    private static var osName: String {
        #if os(iOS)
        "iOS"
        #elseif os(macOS)
        "macOS"
        #else
        "unknown"
        #endif
    }

    private static var machine: String {
        var info = utsname()
        uname(&info)

        return withUnsafeBytes(of: &info.machine) { raw in
            let bytes = raw.prefix(while: { $0 != 0 })
            return String(bytes: bytes, encoding: .utf8) ?? "Unknown"
        }
    }
}
