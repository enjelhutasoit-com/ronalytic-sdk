//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticLifecycle
import RonalyticTestSupport
@testable import Ronalytic

private struct NamedPlugin: Plugin {
    let name: String
    func process(_ event: Event) async -> Event? { event }
}

private struct NoOpBackgroundTaskAPI: BackgroundTaskAPI {
    func beginTask(name: String, onExpiration: @escaping @Sendable () -> Void) async -> Int? { nil }
    func endTask(_ id: Int) {}
}

final class IOSDefaultsTests: XCTestCase {

    private let center = NotificationCenter()

    func test_installsALifecycleObserver() {
        let config = makeConfig(network: FakeNetworkStateProvider(.wifi))

        XCTAssertTrue(config.lifecycleObserver is NotificationLifecycleObserver)
    }

    func test_installedObserver_listensToTheGivenNotifications() async {
        let config = makeConfig(network: FakeNetworkStateProvider(.wifi))
        let stream = config.lifecycleObserver?.events()
        var iterator = stream?.makeAsyncIterator()

        center.post(name: names.background, object: nil)
        let first = await iterator?.next()

        XCTAssertEqual(first, .didEnterBackground)
    }

    func test_installsTheSystemBackgroundTaskRunner() {
        let config = makeConfig(network: FakeNetworkStateProvider(.wifi))

        XCTAssertTrue(config.backgroundTaskRunner is SystemBackgroundTaskRunner)
    }

    func test_installsTheGivenNetworkProvider() async {
        let config = makeConfig(network: FakeNetworkStateProvider(.cellular))

        let state = await config.networkStateProvider.current()

        XCTAssertEqual(state, .cellular)
    }

    func test_keepsEverythingTheCallerSet() {
        let config = makeConfig(network: FakeNetworkStateProvider(.wifi))

        XCTAssertEqual(config.batchSize, 7)
        XCTAssertEqual(config.plugins.map(\.name), ["mine"])
        XCTAssertNotNil(config.transport)
    }

    // MARK: - Helper

    private let names = NotificationLifecycleObserver.Names(
        background: Notification.Name("test.background"),
        foreground: Notification.Name("test.foreground"),
        terminate: Notification.Name("test.terminate")
    )

    private func makeConfig(network: FakeNetworkStateProvider) -> RonalyticConfig {
        RonalyticConfig(
            storage: InMemoryQueueStorage(),
            transport: FakeTransport(),
            plugins: [NamedPlugin(name: "mine")],
            batchSize: 7
        )
        .applyingSystemIntegrations(
            lifecycleNames: names,
            center: center,
            backgroundTaskAPI: NoOpBackgroundTaskAPI(),
            networkStateProvider: network
        )
    }
}
