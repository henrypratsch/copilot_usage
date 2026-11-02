import Foundation

public struct UsageClient: Sendable {
    private static let endpoint = URL(string: "https://api.github.com/copilot_internal/user")!

    private let session: URLSession
    private let userAgent: String

    public init(userAgent: String, session: URLSession = UsageClient.makeSession()) {
        self.userAgent = userAgent
        self.session = session
    }

    /// An ephemeral session: nothing is cached or written to disk and every request hits the API.
    public static func makeSession(configuration: URLSessionConfiguration = .ephemeral) -> URLSession {
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }

    public func fetch(token: String) async throws(UsageError) -> UsageSnapshot {
        guard TokenStore.isWellFormed(token) else { throw .invalidToken }

        var request = URLRequest(url: Self.endpoint, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .offline
        }

        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return try UsageSnapshot.decode(from: data)
        case 401: throw .unauthorized
        case 403: throw .forbidden
        case let code?: throw .http(code)
        case nil: throw .unexpectedResponse
        }
    }
}
