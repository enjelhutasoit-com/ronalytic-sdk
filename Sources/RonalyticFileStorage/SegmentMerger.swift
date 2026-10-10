//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// Merges several ordered event lists into one, oldest first.
/// The order inside each list is never changed.
enum SegmentMerger {
    static func merge(_ lists: [[Event]]) -> [Event] {
        var cursors = Array(repeating: 0, count: lists.count)
        var merged: [Event] = []

        while true {
            var chosen: Int?
            var chosenTime: Date?
            for index in lists.indices where cursors[index] < lists[index].count {
                let time = lists[index][cursors[index]].timestamp
                // Strictly earlier wins, so on a tie the earlier list stays chosen.
                if chosenTime == nil || time < (chosenTime ?? time) {
                    chosen = index
                    chosenTime = time
                }
            }
            guard let index = chosen else { return merged }

            merged.append(lists[index][cursors[index]])
            cursors[index] += 1
        }
    }
}
