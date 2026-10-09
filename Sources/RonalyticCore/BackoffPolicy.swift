//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// How long to wait between retries, and how many retries to make.
public struct BackoffPolicy: Sendable, Equatable {
    /// Wait before the first retry, in seconds. Doubles every retry.
    public let baseDelay: TimeInterval
    /// The wait never grows past this, in seconds.
    public let maxDelay: TimeInterval
    /// Retries after the first attempt. 0 means never retry.
    public let maxRetries: Int

    public static let `default` = BackoffPolicy(baseDelay: 1, maxDelay: 60, maxRetries: 5)
    public static let noRetry = BackoffPolicy(baseDelay: 0, maxDelay: 0, maxRetries: 0)

    public init(
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        maxRetries: Int
    ) {
        self.baseDelay = max(baseDelay, 0)
        self.maxDelay = max(maxDelay, 0)
        self.maxRetries = max(maxRetries, 0)
    }

    /// Full jitter: a random share (0...1) of the exponential ceiling.
    func delay(forRetry retry: Int, jitter: Double) -> TimeInterval {
        let exponent = Double(min(max(retry, 0), 30))
        let ceiling = min(maxDelay, baseDelay * pow(2, exponent))
        return ceiling * min(max(jitter, 0), 1)
    }
}
