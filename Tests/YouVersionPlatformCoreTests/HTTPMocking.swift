import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum HTTPMocking {
    static let tokenHeader = "X-Test-Token"
    private static let handlerStore = HandlerStore()

    final class TokenURLProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let token = request.value(forHTTPHeaderField: HTTPMocking.tokenHeader)
            let handler: ((URLRequest) throws -> (Data, URLResponse))? = {
                guard let token else { return nil }
                return HTTPMocking.handler(for: token)
            }()

            guard let handler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }

            do {
                let (data, response) = try handler(request)
                if let http = response as? HTTPURLResponse {
                    client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
                } else {
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    static func makeSession() -> (URLSession, String) {
        let token = UUID().uuidString
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [TokenURLProtocol.self]
        var headers = cfg.httpAdditionalHeaders ?? [:]
        headers[HTTPMocking.tokenHeader] = token
        cfg.httpAdditionalHeaders = headers
        return (URLSession(configuration: cfg), token)
    }

    static func setHandler(token: String, handler: @escaping (URLRequest) throws -> (Data, URLResponse)) {
        handlerStore.set(token: token, handler: handler)
    }

    static func clear(token: String) {
        handlerStore.clear(token: token)
    }

    private static func handler(for token: String) -> ((URLRequest) throws -> (Data, URLResponse))? {
        handlerStore.handler(for: token)
    }
}

private final class HandlerStore: @unchecked Sendable {
    private var storage: [String: (URLRequest) throws -> (Data, URLResponse)] = [:]
    private let lock = NSLock()

    func set(token: String, handler: @escaping (URLRequest) throws -> (Data, URLResponse)) {
        lock.lock()
        storage[token] = handler
        lock.unlock()
    }

    func clear(token: String) {
        lock.lock()
        storage.removeValue(forKey: token)
        lock.unlock()
    }

    func handler(for token: String) -> ((URLRequest) throws -> (Data, URLResponse))? {
        lock.lock()
        defer { lock.unlock() }
        return storage[token]
    }
}


