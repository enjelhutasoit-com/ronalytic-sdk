//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
@testable import RonalyticLifecycle

private final class FakePathMonitor: PathMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (NetworkPathSnapshot) -> Void)?
    private var stops = 0

    var stopCount: Int {
        lock.withLock { stops }
    }

    func start(onChange: @escaping @Sendable (NetworkPathSnapshot) -> Void) {
        lock.withLock { handler = onChange }
    }

    func stop() {
        lock.withLock { stops += 1 }
    }

    func report(_ snapshot: NetworkPathSnapshot) {
        let current = lock.withLock { handler }
        current?(snapshot)
    }
}

final class NetworkPathStateProviderTests: XCTestCase {

    private let monitor = FakePathMonitor()

    private var provider: NetworkPathStateProvider {
        NetworkPathStateProvider(monitor: monitor)
    }

    func test_beforeAnyReport_isUnknown() async {
        let sut = provider

        let state = await sut.current()

        XCTAssertEqual(state, .unknown)
    }

    func test_unsatisfiedPath_isOffline() async {
        let sut = provider

        monitor.report(NetworkPathSnapshot(isSatisfied: false, interfaces: [.wifi]))
        let state = await sut.current()

        XCTAssertEqual(state, .offline)
    }

    func test_mapsEachInterface() async {
        let sut = provider
        let cases: [(NetworkPathSnapshot.Interface, NetworkState)] = [
            (.wifi, .wifi), (.cellular, .cellular), (.wired, .wired), (.other, .unknown)
        ]

        for (interface, expected) in cases {
            monitor.report(NetworkPathSnapshot(isSatisfied: true, interfaces: [interface]))
            let state = await sut.current()

            XCTAssertEqual(state, expected)
        }
    }

    func test_wifiBeatsCellularWhenBothAreActive() async {
        let sut = provider

        monitor.report(NetworkPathSnapshot(isSatisfied: true, interfaces: [.cellular, .wifi]))
        let state = await sut.current()

        XCTAssertEqual(state, .wifi)
    }

    func test_satisfiedWithoutKnownInterface_isUnknown() async {
        let sut = provider

        monitor.report(NetworkPathSnapshot(isSatisfied: true, interfaces: []))
        let state = await sut.current()

        XCTAssertEqual(state, .unknown)
    }

    func test_followsLaterChanges() async {
        let sut = provider

        monitor.report(NetworkPathSnapshot(isSatisfied: true, interfaces: [.wifi]))
        monitor.report(NetworkPathSnapshot(isSatisfied: false, interfaces: []))
        let state = await sut.current()

        XCTAssertEqual(state, .offline)
    }

    func test_stopsTheMonitorWhenReleased() {
        var sut: NetworkPathStateProvider? = provider
        XCTAssertEqual(monitor.stopCount, 0)

        sut = nil

        XCTAssertNil(sut)
        XCTAssertEqual(monitor.stopCount, 1)
    }
}
