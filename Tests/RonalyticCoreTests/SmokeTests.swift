//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import  RonalyticCore

final class SmokeTests: XCTestCase {
    func test_SDKVersion_isSematicVersion() {
        let parts = RonalyticInfo.version.split(separator: ".")
        XCTAssertTrue(parts.allSatisfy { Int($0) != nil})
    }
}
