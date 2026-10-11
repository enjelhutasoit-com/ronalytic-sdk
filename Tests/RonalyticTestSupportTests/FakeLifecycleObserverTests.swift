//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport

final class FakeLifecycleObserverTests: XCTestCase {

    func test_deliversSentEventsInOrder() async {
        let observer = FakeLifecycleObserver()
        observer.send(.didEnterBackground)
        observer.send(.willEnterForeground)
        observer.finish()

        var received: [LifecycleEvent] = []
        for await event in observer.events() {
            received.append(event)
        }

        XCTAssertEqual(received, [.didEnterBackground, .willEnterForeground])
    }

    func test_canBeUsedThroughTheProtocol() async {
        let fake = FakeLifecycleObserver()
        let observer: any LifecycleObserver = fake
        fake.send(.willTerminate)
        fake.finish()

        var received: [LifecycleEvent] = []
        for await event in observer.events() {
            received.append(event)
        }

        XCTAssertEqual(received, [.willTerminate])
    }
}
