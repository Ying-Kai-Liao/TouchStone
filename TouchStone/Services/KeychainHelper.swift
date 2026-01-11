import Foundation
import Security

enum KeychainHelper {
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case notFound
        case unexpectedData
    }

    private static let service = "com.touchstone.app"

    // MARK: - Save

    static func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    static func save(key: String, string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }
        try save(key: key, data: data)
    }

    // MARK: - Read

    static func read(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.unknown(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }

        return data
    }

    static func readString(key: String) throws -> String {
        let data = try read(key: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return string
    }

    // MARK: - Delete

    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Check Existence

    static func exists(key: String) -> Bool {
        do {
            _ = try read(key: key)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - API Key Manager

@Observable
class APIKeyManager {
    static let shared = APIKeyManager()

    private static let openAIKeyName = "openai_api_key"

    private(set) var hasAPIKey: Bool = false

    private init() {
        hasAPIKey = KeychainHelper.exists(key: Self.openAIKeyName)
    }

    var openAIKey: String? {
        try? KeychainHelper.readString(key: Self.openAIKeyName)
    }

    func setOpenAIKey(_ key: String) throws {
        try KeychainHelper.save(key: Self.openAIKeyName, string: key)
        hasAPIKey = true
    }

    func deleteOpenAIKey() throws {
        try KeychainHelper.delete(key: Self.openAIKeyName)
        hasAPIKey = false
    }
}
