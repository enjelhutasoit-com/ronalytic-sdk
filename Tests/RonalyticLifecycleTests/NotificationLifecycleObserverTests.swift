//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
@testable import RonalyticLifecycle

final class NotificationLifecycleObserverTests: XCTestCase {

    private let center = NotificationCenter()

    func test_mapsEachNotificationToALifecycleEvent() async {
        let stream = observer.events()
        var iterator = stream.makeAsyncIterator()

        center.post(name: names.background, object: nil)
        center.post(name: names.foreground, object: nil)
        center.post(name: names.terminate, object: nil)
        let first = await iterator.next()
        let second = await iterator.next()
        let third = await iterator.next()

        XCTAssertEqual(first, .didEnterBackground)
        XCTAssertEqual(second, .willEnterForeground)
        XCTAssertEqual(third, .willTerminate)
    }

    func test_ignoresOtherNotifications() async {
        let stream = observer.events()
        var iterator = stream.makeAsyncIterator()

        center.post(name: Notification.Name("something.else"), object: nil)
        center.post(name: names.background, object: nil)
        let first = await iterator.next()

        XCTAssertEqual(first, .didEnterBackground)
    }

    func test_everyCallToEventsGetsItsOwnStream() async {
        let firstStream = observer.events()
        let secondStream = observer.events()
        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()

        center.post(name: names.foreground, object: nil)
        let first = await firstIterator.next()
        let second = await secondIterator.next()

        XCTAssertEqual(first, .willEnterForeground)
        XCTAssertEqual(second, .willEnterForeground)
    }

    // MARK: - Helper

    private let names = NotificationLifecycleObserver.Names(
        background: Notification.Name("test.background"),
        foreground: Notification.Name("test.foreground"),
        terminate: Notification.Name("test.terminate")
    )

    private var observer: NotificationLifecycleObserver {
        NotificationLifecycleObserver(names: names, center: center)
    }
}
