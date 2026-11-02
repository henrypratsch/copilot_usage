public enum UsageError: Error, Equatable, Sendable {
    case invalidToken
    case unauthorized
    case forbidden
    case http(Int)
    case offline
    case unexpectedResponse
    case noQuota
    case keychain

    public var message: String {
        switch self {
        case .invalidToken: "Token contains invalid characters"
        case .unauthorized: "Token invalid or expired"
        case .forbidden: "Access denied – check token or SSO authorization"
        case .http(let code): "GitHub API error (\(code))"
        case .offline: "Network unavailable"
        case .unexpectedResponse: "Unexpected API response"
        case .noQuota: "No premium request quota found"
        case .keychain: "Could not save token to keychain"
        }
    }
}
