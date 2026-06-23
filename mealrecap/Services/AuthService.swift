import Foundation
import CryptoKit
import AuthenticationServices

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
        guard isValidEmail(normalizedEmail) else { throw LocalAuthError.invalidEmail }
        guard password.count >= 8 else { throw LocalAuthError.passwordTooShort }

        let accounts = loadAccounts()
        let passwordHash = Self.sha256(password)

        guard let account = accounts[normalizedEmail] else { throw LocalAuthError.accountNotFound }
        guard account.passwordHash == passwordHash else { throw LocalAuthError.invalidPassword }

        saveCurrent(account.session)
        onChange?(account.session)
    }

    func createAccount(email: String, password: String) async throws {
        let normalizedEmail = normalize(email)
        guard normalizedEmail.isEmpty == false else { throw LocalAuthError.emailRequired }
        guard isValidEmail(normalizedEmail) else { throw LocalAuthError.invalidEmail }
        guard password.count >= 8 else { throw LocalAuthError.passwordTooShort }

        var accounts = loadAccounts()
        if accounts[normalizedEmail] != nil { throw LocalAuthError.accountAlreadyExists }

        let account = LocalAccount(uid: "local_" + UUID().uuidString.replacingOccurrences(of: "-", with: ""), email: normalizedEmail, passwordHash: Self.sha256(password))
        accounts[normalizedEmail] = account
        saveAccounts(accounts)
        saveCurrent(account.session)
        onChange?(account.session)
    }

    func sendPasswordReset(email: String) async throws {
        let normalizedEmail = normalize(email)
        guard normalizedEmail.isEmpty == false else { throw LocalAuthError.emailRequired }
        guard isValidEmail(normalizedEmail) else { throw LocalAuthError.invalidEmail }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        let appleID = credential.user
        guard appleID.isEmpty == false else { throw LocalAuthError.appleSignInFailed }
        let email = credential.email ?? "\(appleID.prefix(10))@privaterelay.appleid.com"
        let account = LocalAccount(
            uid: "apple_" + Self.sha256(appleID).prefix(28),
            email: normalize(email),
            passwordHash: "apple"
        )
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

    private func isValidEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".") && email.count >= 5
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
        case invalidEmail
        case passwordTooShort
        case invalidPassword
        case accountAlreadyExists
        case accountNotFound
        case appleSignInCancelled
        case appleSignInFailed

        var errorDescription: String? {
            switch self {
            case .emailRequired:
                return "Enter an email to continue."
            case .invalidEmail:
                return "Enter a valid email address."
            case .passwordTooShort:
                return "Password must be at least 8 characters."
            case .invalidPassword:
                return "That password does not match this account."
            case .accountAlreadyExists:
                return "That email is already in use. Sign in instead."
            case .accountNotFound:
                return "We could not find an account for that email."
            case .appleSignInCancelled:
                return "Sign in with Apple was canceled."
            case .appleSignInFailed:
                return "Apple sign-in could not be completed. Please try again."
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
