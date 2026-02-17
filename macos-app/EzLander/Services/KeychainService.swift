import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let service = "com.ezlander.app"
    private let useUserDefaultsFallback = true  // Enable fallback for unsigned builds

    private init() {}

    // MARK: - Save
    @discardableResult
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("KeychainService: Failed to convert value to data for key: \(key)")
            return false
        }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("KeychainService: Successfully saved key to Keychain: \(key)")
            return true
        } else {
            print("KeychainService: Failed to save key to Keychain: \(key), status: \(status)")
            // Fallback to UserDefaults for development/unsigned builds
            if useUserDefaultsFallback {
                UserDefaults.standard.set(value, forKey: "secure_\(key)")
                print("KeychainService: Saved to UserDefaults fallback: \(key)")
                return true
            }
            return false
        }
    }

    // MARK: - Get
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            print("KeychainService: Retrieved key from Keychain: \(key)")
            return string
        }

        // Fallback to UserDefaults for development/unsigned builds
        if useUserDefaultsFallback {
            if let fallbackValue = UserDefaults.standard.string(forKey: "secure_\(key)") {
                print("KeychainService: Retrieved key from UserDefaults fallback: \(key)")
                return fallbackValue
            }
        }

        print("KeychainService: Key not found: \(key)")
        return nil
    }

    // MARK: - Delete
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        // Also delete from UserDefaults fallback
        if useUserDefaultsFallback {
            UserDefaults.standard.removeObject(forKey: "secure_\(key)")
        }
    }

    // MARK: - Clear All
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Check Exists
    func exists(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
