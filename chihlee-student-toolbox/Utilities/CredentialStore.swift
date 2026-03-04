import Foundation
import Security

struct StoredCredentials {
    let muid: String
    let mpassword: String
}

final class CredentialStore {
    static let shared = CredentialStore()

    private let service: String

    private enum Account {
        static let muid = "muid"
        static let mpassword = "mpassword"
    }

    private init() {
        service = Bundle.main.bundleIdentifier ?? "chihlee-student-toolbox.auth"
    }

    func save(muid: String, mpassword: String) {
        saveValue(muid, forAccount: Account.muid)
        saveValue(mpassword, forAccount: Account.mpassword)
    }

    func load() -> StoredCredentials? {
        guard
            let muid = readValue(forAccount: Account.muid),
            let mpassword = readValue(forAccount: Account.mpassword),
            !muid.isEmpty,
            !mpassword.isEmpty
        else {
            return nil
        }
        return StoredCredentials(muid: muid, mpassword: mpassword)
    }

    func clear() {
        deleteValue(forAccount: Account.muid)
        deleteValue(forAccount: Account.mpassword)
    }

    private func saveValue(_ value: String, forAccount account: String) {
        let encoded = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = encoded
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func readValue(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard
            status == errSecSuccess,
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }

    private func deleteValue(forAccount account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
