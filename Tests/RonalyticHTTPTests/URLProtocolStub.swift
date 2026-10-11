//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Intercepts requests of a URLSession so tests never touch the network.
final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    enum Reply {
        case status(Int)
        case failure(URLError)
    }

    struct Captured {
        let request: URLRequest
        let body: Data
    }

    // Every access goes through `lock`.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var reply: Reply = .status(200)
    nonisolated(unsafe) private static var captured: [Captured] = []

    static func reset(reply: Reply = .status(200)) {
        lock.withLock {
            self.reply = reply
            captured = []
        }
    }

    static var requests: [Captured] {
        lock.withLock { captured }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let currentReply = Self.lock.withLock { () -> Reply in
            Self.captured.append(Captured(request: request, body: Self.body(of: request)))
            return Self.reply
        }

        switch currentReply {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .status(let code):
            let url = request.url ?? URL(fileURLWithPath: "/")
            let response = HTTPURLResponse(
                url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil
            )
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    /// URLSession moves the body into a stream, so it has to be read from there.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }

        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
