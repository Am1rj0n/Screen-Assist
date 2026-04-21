import Security
import Foundation

/// All API keys are stored in macOS Keychain.
/// They are NEVER saved to UserDefaults, plists, or any plaintext file.
enum KeychainHelper {

    private static let service = "com.screenassist.app"

    @discardableResult
    static func save(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(account: account)   // remove stale entry first

        let q: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    account,
            kSecValueData:      data,
            // Accessible only when device is unlocked; excluded from iCloud backup
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> String? {
        let q: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  account,
            kSecReturnData:   kCFBooleanTrue as Any,
            kSecMatchLimit:   kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let d = item as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        let q: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        return SecItemDelete(q as CFDictionary) == errSecSuccess
    }
}
