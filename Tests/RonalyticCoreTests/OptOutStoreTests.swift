//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

final class OptOutStoreTests: XCTestCase {

    private var suiteName = ""

    override func setUp() {
        suiteName = "ronalytic.tests.\(UUID().uuidString)"
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    func test_inMemory_startsNotOptedOut() {
        let store = InMemoryOptOutStore()

        XCTAssertFalse(store.isOptedOut())
    }

    func test_inMemory_remembersValue() {
        let store = InMemoryOptOutStore()

        store.setOptedOut(true)

        XCTAssertTrue(store.isOptedOut())
    }

    func test_userDefaults_startsNotOptedOut() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let store = UserDefaultsOptOutStore(defaults: defaults)

        XCTAssertFalse(store.isOptedOut())
    }

    func test_userDefaults_valueSurvivesANewStoreInstance() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        UserDefaultsOptOutStore(defaults: defaults).setOptedOut(true)

        let reopened = UserDefaultsOptOutStore(defaults: defaults)

        XCTAssertTrue(reopened.isOptedOut())
    }
}
