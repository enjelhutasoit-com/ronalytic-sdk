//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

public enum AppGroupError: Error, Equatable {
    /// The App Group folder was not found. Usually the App Group capability is missing
    /// in the target's Signing & Capabilities, or the identifier has a typo.
    case containerUnavailable(String)
}

public extension FileQueueStorage {
    /// A queue in the shared folder of an App Group, so an app and its extensions
    /// (widgets, share extensions) can put events in one place.
    ///
    /// Every process writes only its own files. Give each process a different,
    /// fixed `writerID`, for example "app" and "widget". A fixed ID reuses the same
    /// files after every launch, so they can be cleaned up.
    ///
    /// - Parameters:
    ///   - identifier: The App Group identifier, for example "group.com.example.app".
    ///   - writerID: Fixed name of this process. Different per app and per extension.
    ///   - folderName: Folder inside the container for the queue files.
    ///   - containerProvider: Finds the shared folder. Replace in tests.
    /// - Throws: `AppGroupError.containerUnavailable` when the group cannot be found.
    static func appGroup(
        identifier: String,
        writerID: String,
        folderName: String = "Ronalytic",
        containerProvider: @Sendable (String) -> URL? = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    ) throws -> FileQueueStorage {
        guard let container = containerProvider(identifier) else {
            throw AppGroupError.containerUnavailable(identifier)
        }

        return FileQueueStorage(
            directory: container.appendingPathComponent(folderName, isDirectory: true),
            writerID: writerID
        )
    }
}
