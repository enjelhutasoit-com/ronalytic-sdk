//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

private actor CallRecorder {
    private(set) var names: [String] = []
    func record(_ name: String) { names.append(name) }
}

private struct RecordingPlugin: Plugin {
    let name: String
    let recorder: CallRecorder
    var drops = false

    func process(_ event: RonalyticCore.Event) async -> RonalyticCore.Event? {
        await recorder.record(name)
        return drops ? nil : event
    }
}

private struct SuffixPlugin: Plugin {
    let name: String
    let suffix: String

    func process(_ event: RonalyticCore.Event) async -> RonalyticCore.Event? {
        var copy = event
        copy.name += suffix
        return copy
    }
}

final class PipelineTests: XCTestCase {
    func test_emptyPipeline_returnsEventUnchanged() async {
        let event = makeTestEvent()
        let result = await Pipeline(plugins: []).run(event)

        XCTAssertEqual(result, event)
    }

    func test_runsPluginsInOrder() async {
        let recorder = CallRecorder()
        let pipeline = Pipeline(plugins: [
            RecordingPlugin(name: "first", recorder: recorder),
            RecordingPlugin(name: "second", recorder: recorder),
            RecordingPlugin(name: "third", recorder: recorder)
        ])
        _ = await pipeline.run(makeTestEvent())
        let names = await recorder.names

        XCTAssertEqual(names, ["first", "second", "third"])
    }

    func test_passesOutputOfEachPluginToTheNext() async {
        let pipeline = Pipeline(plugins: [
            SuffixPlugin(name: "a", suffix: "A"),
            SuffixPlugin(name: "b", suffix: "B")
        ])
        let result = await pipeline.run(makeTestEvent(name: "buy"))

        XCTAssertEqual(result?.name, "buyAB")
    }

    func test_dropStopsThePipeline() async {
        let recorder = CallRecorder()
        let pipeline = Pipeline(plugins: [
            RecordingPlugin(name: "first", recorder: recorder),
            RecordingPlugin(name: "second", recorder: recorder, drops: true),
            RecordingPlugin(name: "third", recorder: recorder)
        ])
        let result = await pipeline.run(makeTestEvent())
        let names = await recorder.names

        XCTAssertNil(result)
        XCTAssertEqual(names, ["first", "second"])
    }
}
