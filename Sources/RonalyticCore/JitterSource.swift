//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Source of randomness for retry waits. Injected so tests are exact.
protocol JitterSource: Sendable {
    /// A value from 0 to 1.
    func nextUnit() -> Double
}

struct SystemJitter: JitterSource {
    func nextUnit() -> Double { Double.random(in: 0...1) }
}
