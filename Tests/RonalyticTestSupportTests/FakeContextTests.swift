//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

final class ContextProviderTests: XCTestCase {
    func test_systemProvider_returnsNonEmptyValues() async {
        let context = await SystemContextProvider().current()

        XCTAssertFalse(context.osName.isEmpty)
        XCTAssertFalse(context.osVersion.isEmpty)
        XCTAssertFalse(context.model.isEmpty)
        XCTAssertFalse(context.locale.isEmpty)
        XCTAssertFalse(context.appVersion.isEmpty)
        XCTAssertFalse(context.appBuild.isEmpty)
        XCTAssertFalse(context.bundleID.isEmpty)
    }

    func test_unknownNetworkProvider_answersUnknown() async {
        let state = await UnknownNetworkStateProvider().current()

        XCTAssertEqual(state, .unknown)
    }

    func test_networkState_hasStableRawValues() {
        let raw = [
            NetworkState.wifi,
            .cellular,
            .wired,
            .offline,
            .unknown
        ].map(\.rawValue)

        XCTAssertEqual(
            raw,
            ["wifi", "cellular", "wired", "offline", "unknown"]
        )
    }
}
