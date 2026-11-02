import Foundation
import Security

/// Stores the GitHub token as a generic password in the login keychain.
public struct TokenStore: Sendable {
    private let service: String
    private let account = "github-token"

    public init(service: String = "com.copilotusage.CopilotUsage") {
        self.service = service
    }

    /// Rejects anything that cannot be a GitHub token, e.g. pasted text with spaces or line breaks.
    public static func isWellFormed(_ token: String) -> Bool {
        !token.isEmpty && token.count <= 512 && token.unicodeScalars.allSatisfy(allowedCharacters.contains)
    }

    private static let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func read() -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              Self.isWellFormed(token)
        else { return nil }
        return token
    }

    @discardableResult
    public func save(_ token: String) -> Bool {
        guard Self.isWellFormed(token) else { return false }
        delete()
        var query = query
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrLabel as String] = "CopilotUsage GitHub Token"
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    public func delete() -> Bool {
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
