import Combine
import CryptoKit
import Foundation
import OSLog
import Security

/// Stores and verifies the "parent code" used to authorize privileged
/// actions such as temporarily disabling the forcible sleep.
///
/// The code is never stored in plain text. Only a SHA-256 hash is kept,
/// and it lives in the Keychain rather than UserDefaults so that it is
/// not trivially readable or resettable by the person being supervised.
final class PasscodeManager: ObservableObject {
    static let shared = PasscodeManager()

    private let service = Bundle.main.bundleIdentifier ?? "ScreenBreakTime"
    private let account = "parentCode"

    /// Whether a parent code has been configured.
    @Published private(set) var isSet: Bool = false

    private init() {
        isSet = loadHash() != nil
    }

    /// Store a new parent code, replacing any existing one.
    func setPasscode(_ code: String) {
        saveHash(Self.hash(code))
        isSet = true
        Logger.action.log("Parent code was set.")
    }

    /// Return `true` when `code` matches the stored parent code.
    func verify(_ code: String) -> Bool {
        guard let stored = loadHash() else { return false }
        return Self.hash(code) == stored
    }

    private static func hash(_ code: String) -> Data {
        Data(SHA256.hash(data: Data(code.utf8)))
    }

    // MARK: - Keychain

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func saveHash(_ data: Data) {
        SecItemDelete(baseQuery() as CFDictionary)

        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.action.error("Failed to store parent code in Keychain: \(status)")
        }
    }

    private func loadHash() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
