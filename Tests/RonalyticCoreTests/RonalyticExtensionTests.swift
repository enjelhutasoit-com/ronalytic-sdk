//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class RonalyticExtensionTests: XCTestCase {

    private let storage = QueueStorageFake()

    func test_trackScreenAndIdentify_areWrittenToStorage() async throws {
        let sut = makeExtension()

        sut.track("widget_tapped", properties: ["kind": "small"])
        sut.screen("Widget")
        sut.identify("user-1")
        await sut.waitUntilStored()

        let events = try await storage.peek(limit: 10)
        XCTAssertEqual(events.map(\.type), [.track, .screen, .identify])
        XCTAssertEqual(events.first?.properties["kind"], .string("small"))
    }

    func test_neverSends_evenWhenAGivenConfigHasATransportAndBatchSizeIsReached() async throws {
        let transport = TransportSpy()
        let sut = makeExtension(transport: transport)

        sut.track("a")
        sut.track("b")
        await sut.waitUntilStored()

        let batches = await transport.sentBatches
        let count = try await storage.count()
        XCTAssertTrue(batches.isEmpty)
        XCTAssertEqual(count, 2)
    }

    func test_ignoresTheLifecycleObserverOfTheConfig() async {
        let transport = TransportSpy()
        let observer = LifecycleObserverFake()
        let sut = makeExtension(transport: transport, lifecycleObserver: observer)
        sut.track("a")

        observer.send(.didEnterBackground)
        observer.finish()
        await sut.waitUntilStored()

        let batches = await transport.sentBatches
        XCTAssertTrue(batches.isEmpty)
    }

    func test_optOutStoreOfTheApp_isRespected() async throws {
        let store = InMemoryOptOutStore()
        store.setOptedOut(true)
        let sut = makeExtension(optOutStore: store)

        sut.track("a")
        await sut.waitUntilStored()

        let names = try await storedNames()
        XCTAssertEqual(names, [])
    }

    func test_deniedConsent_dropsEvents() async throws {
        let sut = makeExtension(consent: ConsentProviderFake(.denied))

        sut.track("a")
        await sut.waitUntilStored()

        let names = try await storedNames()
        XCTAssertEqual(names, [])
    }

    func test_eventsKeepTheirCallOrder() async throws {
        let sut = makeExtension()
        let names = (0..<10).map { "e\($0)" }

        names.forEach { sut.track($0) }
        await sut.waitUntilStored()

        let stored = try await storedNames()
        XCTAssertEqual(stored, names)
    }

    // MARK: - Helper

    private func makeExtension(
        transport: TransportSpy? = nil,
        consent: ConsentProviderFake? = nil,
        optOutStore: InMemoryOptOutStore = InMemoryOptOutStore(),
        lifecycleObserver: LifecycleObserverFake? = nil
    ) -> RonalyticExtension {
        RonalyticExtension(
            config: RonalyticConfig(
                storage: storage,
                transport: transport,
                batchSize: 1,
                flushInterval: .seconds(30),
                collectContext: false,
                consentProvider: consent,
                optOutStore: optOutStore,
                lifecycleObserver: lifecycleObserver,
                clock: ClockFake(),
                idGenerator: IDGeneratorFake()
            )
        )
    }

    private func storedNames() async throws -> [String] {
        try await storage.peek(limit: 100).map(\.name)
    }
}
