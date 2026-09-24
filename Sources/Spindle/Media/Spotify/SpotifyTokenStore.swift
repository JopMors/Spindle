import Foundation
import Security

/// Where the refresh token lives between launches.
protocol SpotifyTokenStore {
    func load() -> String?
    func save(_ token: String)
    func delete()
}

/// Keeps the refresh token in the login keychain rather than in preferences,
/// where any process that can read a plist could lift it.
struct KeychainTokenStore: SpotifyTokenStore {

    private static let service = "nl.jopmors.spindle.spotify"
    private static let account = "refresh-token"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
    }

    func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                NSLog("Spindle: keychain read failed (\(status))")
            }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String) {
        let data = Data(token.utf8)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else {
            if status != errSecSuccess { NSLog("Spindle: keychain update failed (\(status))") }
            return
        }
        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        if addStatus != errSecSuccess {
            NSLog("Spindle: keychain write failed (\(addStatus))")
        }
    }

    func delete() {
        let status = SecItemDelete(baseQuery as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            NSLog("Spindle: keychain delete failed (\(status))")
        }
    }
}
