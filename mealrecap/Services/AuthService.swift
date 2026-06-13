import Foundation
import CryptoKit

@MainActor
final class AuthService: ObservableObject {
    private var onChange: ((UserSession?) -> Void)?
    private let accountsKey = "mealrecap.local.accounts.v1"
    private let currentKey = "mealrecap.local.currentSession.v1"

    func listen(_ onChange: @escaping (UserSession?) -> Void) {
        self.onChange = onChange
        onChange(currentSession())
    }

    func signIn(email: String, password: String) async throws {
        let normalizedEmail = normalize(email)
        guard normalizedEmail.isEmpty == false else { throw LocalAuthError.emailRequired }
        guard password.count >= 6 else { throw LocalAuthError.passwordTooShort }

        var accounts = loadAccounts()
        let passwordHash = Self.sha256(password)

        // Local-only auth: if this email has not been seen on this device, create it.
        // This intentionally does not use Firebase Auth or Firebase ID tokens.
        let account: LocalAccount
        if let existing = accounts[normalizedEmail] {
            guard existing.passwordHash == passwordHash else { throw LocalAuthError.invalidPassword }
            account = existing
        } else {
            account = LocalAccount(uid: "local_" + UUID().uuidString.replacingOccurrences(of: "-", with: ""), email: normalizedEmail, passwordHash: passwordHash)
            accounts[normalizedEmail] = account
            saveAccounts(accounts)
        }

        saveCurrent(account.session)
        onChange?(account.session)
    }

    func createAccount(email: String, password: String) async throws {
        let normalizedEmail = normalize(email)
        guard normalizedEmail.isEmpty == false else { throw LocalAuthError.emailRequired }
        guard password.count >= 6 else { throw LocalAuthError.passwordTooShort }

        var accounts = loadAccounts()
        if accounts[normalizedEmail] != nil { throw LocalAuthError.accountAlreadyExists }

        let account = LocalAccount(uid: "local_" + UUID().uuidString.replacingOccurrences(of: "-", with: ""), email: normalizedEmail, passwordHash: Self.sha256(password))
        accounts[normalizedEmail] = account
        saveAccounts(accounts)
        saveCurrent(account.session)
        onChange?(account.session)
    }

    func signOut() throws {
        UserDefaults.standard.removeObject(forKey: currentKey)
        onChange?(nil)
    }

    func deleteCurrentAccount() throws {
        guard let session = currentSession(), let email = session.email else {
            try signOut()
            return
        }
        var accounts = loadAccounts()
        accounts.removeValue(forKey: normalize(email))
        saveAccounts(accounts)
        UserDefaults.standard.removeObject(forKey: currentKey)
        onChange?(nil)
    }

    func currentSession() -> UserSession? {
        guard let data = UserDefaults.standard.data(forKey: currentKey) else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }

    private func saveCurrent(_ session: UserSession) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: currentKey)
        }
    }

    private func loadAccounts() -> [String: LocalAccount] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: LocalAccount].self, from: data)) ?? [:]
    }

    private func saveAccounts(_ accounts: [String: LocalAccount]) {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private struct LocalAccount: Codable {
        let uid: String
        let email: String
        let passwordHash: String

        var session: UserSession {
            UserSession(uid: uid, email: email)
        }
    }

    enum LocalAuthError: LocalizedError {
        case emailRequired
        case passwordTooShort
        case invalidPassword
        case accountAlreadyExists

        var errorDescription: String? {
            switch self {
            case .emailRequired:
                return "Enter an email to continue."
            case .passwordTooShort:
                return "Use at least 6 characters for your local MealRecap password."
            case .invalidPassword:
                return "That local password does not match this device's saved MealRecap account."
            case .accountAlreadyExists:
                return "That local account already exists on this device. Sign in instead."
            }
        }
    }
}

enum LocalAuthStore {
    private static let currentKey = "mealrecap.local.currentSession.v1"

    static func currentSession() -> UserSession? {
        guard let data = UserDefaults.standard.data(forKey: currentKey) else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }
}
