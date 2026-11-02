import CopilotUsageCore
import Foundation
import Testing

@Suite(.serialized) struct UsageClientTests {
    private let client = UsageClient(userAgent: "Test", session: StubProtocol.session)

    @Test func returnsUsageOn200() async throws {
        StubProtocol.stub(status: 200, body: #"{ "quota_snapshots": { "premium_interactions": { "entitlement": 100, "remaining": 40 } } }"#)
        let usage = try await client.fetch(token: "abc")
        #expect(usage.used == 60)
        #expect(StubProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
        #expect(StubProtocol.lastRequest?.url?.host() == "api.github.com")
    }

    @Test(arguments: [
        (401, UsageError.unauthorized),
        (403, .forbidden),
        (500, .http(500)),
    ])
    func mapsStatusCodes(status: Int, expected: UsageError) async {
        StubProtocol.stub(status: status, body: "{}")
        await #expect(throws: expected) { try await client.fetch(token: "abc") }
    }

    @Test func mapsNetworkFailureToOffline() async {
        StubProtocol.stubFailure()
        await #expect(throws: UsageError.offline) { try await client.fetch(token: "abc") }
    }

    @Test func rejectsMalformedTokenWithoutRequest() async {
        StubProtocol.lastRequest = nil
        await #expect(throws: UsageError.invalidToken) { try await client.fetch(token: "a\r\nb") }
        #expect(StubProtocol.lastRequest == nil)
    }
}

final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) private static var result: Result<(Int, Data), URLError> = .failure(URLError(.notConnectedToInternet))
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return UsageClient.makeSession(configuration: configuration)
    }()

    static func stub(status: Int, body: String) {
        result = .success((status, Data(body.utf8)))
    }

    static func stubFailure() {
        result = .failure(URLError(.notConnectedToInternet))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lastRequest = request
        switch Self.result {
        case .success(let (status, data)):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}
