import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("mealrecap.hasSeenIntro.v1") private var hasSeenIntro = false
    @AppStorage("mealrecap.pendingFirstName.v1") private var pendingFirstName = ""

    @State private var route: AuthRoute = .intro
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var resetEmail = ""
    @State private var isBusy = false
    @State private var inlineMessage: AuthInlineMessage?
    @State private var heroAppeared = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AmbientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        Spacer(minLength: proxy.safeAreaInsets.top + 24)

                        header
                            .padding(.top)
                        Group {
                            switch route {
                            case .intro:
                                introContent
                            case .choice:
                                choiceContent
                            case .signUp:
                                signUpContent
                            case .signIn:
                                signInContent
                            case .reset:
                                resetContent
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                        Spacer(minLength: proxy.safeAreaInsets.bottom + 28)
                    }
                    .padding(.horizontal, 22)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .onAppear {
            route = hasSeenIntro ? .choice : .intro
            guard !reduceMotion else {
                heroAppeared = true
                return
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.86).delay(0.08)) {
                heroAppeared = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            VStack(spacing: route == .intro ? 13 : 9) {
                MealRecapLogoMark(size: route == .intro ? 82 : 58)
                MealRecapWordmark()
                    .scaleEffect(route == .intro ? 1.14 : 0.96)
            }
                .frame(maxWidth: .infinity)
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 12)

            if route == .intro {
                Text("Track meals in seconds.")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(MRColor.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text("Type it. Say it. Snap it. MealRecap turns your day into calories, macros, and a clean meal history.")
                    .font(.mrBody)
                    .foregroundStyle(MRColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var introContent: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                IntroPill(icon: "keyboard", title: "Type")
                IntroPill(icon: "mic.fill", title: "Say")
                IntroPill(icon: "camera.fill", title: "Snap")
            }

            VStack(alignment: .leading, spacing: 12) {
                IntroRow(icon: "sparkles", title: "No food database search", subtitle: "Describe a meal naturally and keep moving.")
                IntroRow(icon: "chart.pie.fill", title: "Calories and macros", subtitle: "Get a simple daily picture without clutter.")
                IntroRow(icon: "photo.on.rectangle.angled", title: "Meal memory", subtitle: "Photos and notes stay organized by day.")
            }
            .padding(18)
            .glassRounded(cornerRadius: 30, tint: MRColor.backgroundTop.opacity(0.10), strokeOpacity: 0.52, shadowOpacity: 0.08)

            AuthPrimaryButton(title: "Continue", isBusy: false) {
                hasSeenIntro = true
                go(.choice)
            }
        }
    }

    private var choiceContent: some View {
        VStack(spacing: 14) {
            AuthCardTitle(title: "Welcome to MealRecap", subtitle: "Create an account to keep your meals, goals, and history together.")

            AuthPrimaryButton(title: "Create account", isBusy: false) { go(.signUp) }

            AuthSecondaryButton(title: "I already have an account") { go(.signIn) }

            Text("or continue with")
                .font(.mrMicro)
                .tracking(1.8)
                .foregroundStyle(MRColor.tertiaryText)
                .frame(maxWidth: .infinity, minHeight: 28)

            appleButton

            LegalLinks()
        }
        .padding(18)
        .glassRounded(cornerRadius: 32, tint: MRColor.backgroundTop.opacity(0.10), strokeOpacity: 0.54, shadowOpacity: 0.08)
    }

    private var signUpContent: some View {
        AuthFormCard(title: "Create your account", subtitle: "Use email or Apple to start your private meal history.") {
            appleButton
            AuthTextField(title: "Email", placeholder: "Email address", text: $email, keyboard: .emailAddress)
            AuthSecureField(title: "Password", placeholder: "At least 8 characters", text: $password, contentType: .newPassword)
            AuthSecureField(title: "Confirm password", placeholder: "Re-enter password", text: $confirmPassword, contentType: .newPassword)
            inlineMessageView
            AuthPrimaryButton(title: "Create account", isBusy: isBusy) {
                Task { await createAccount() }
            }
            .disabled(isBusy)
            AuthFooterSwitch(prefix: "Already have an account?", actionTitle: "Sign in") { go(.signIn) }
            LegalLinks()
        }
    }

    private var signInContent: some View {
        AuthFormCard(title: "Sign in", subtitle: "Welcome back. Continue with Apple or your email.") {
            appleButton
            AuthTextField(title: "Email", placeholder: "Email address", text: $email, keyboard: .emailAddress)
            AuthSecureField(title: "Password", placeholder: "Password", text: $password, contentType: .password)
            inlineMessageView
            AuthPrimaryButton(title: "Sign in", isBusy: isBusy) {
                Task { await signIn() }
            }
            .disabled(isBusy)
            Button("Forgot password?") {
                resetEmail = email
                go(.reset)
            }
            .font(.mrSmall.weight(.semibold))
            .foregroundStyle(MRColor.accentDeep)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            AuthFooterSwitch(prefix: "New to MealRecap?", actionTitle: "Create account") { go(.signUp) }
        }
    }

    private var resetContent: some View {
        AuthFormCard(title: "Reset password", subtitle: "Enter your email and we’ll send reset instructions.") {
            AuthTextField(title: "Email", placeholder: "Email address", text: $resetEmail, keyboard: .emailAddress)
            inlineMessageView
            AuthPrimaryButton(title: "Send reset instructions", isBusy: isBusy) {
                Task { await resetPassword() }
            }
            .disabled(isBusy)
            AuthSecondaryButton(title: "Back to sign in") { go(.signIn) }
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.email]
        } onCompletion: { result in
            Task { await handleApple(result) }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity, minHeight: 52)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .accessibilityLabel("Continue with Apple")
    }

    @ViewBuilder
    private var inlineMessageView: some View {
        if let inlineMessage {
            Text(inlineMessage.text)
                .font(.mrSmall.weight(.semibold))
                .foregroundStyle(inlineMessage.kind == .success ? MRColor.accentDeep : MRColor.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func go(_ route: AuthRoute) {
        inlineMessage = nil
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            self.route = route
        }
    }

    private func createAccount() async {
        guard validateEmailPassword(confirming: true) else { return }
        await performAuth {
            try await app.auth.createAccount(email: email, password: password)
        }
    }

    private func signIn() async {
        guard validateEmailPassword(confirming: false) else { return }
        await performAuth {
            try await app.auth.signIn(email: email, password: password)
        }
    }

    private func resetPassword() async {
        let cleaned = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.contains("@"), cleaned.contains(".") else {
            inlineMessage = AuthInlineMessage(kind: .error, text: "Enter a valid email address.")
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await app.auth.sendPasswordReset(email: cleaned)
            inlineMessage = AuthInlineMessage(kind: .success, text: "If that email has an account, reset instructions are on the way.")
        } catch {
            inlineMessage = AuthInlineMessage(kind: .error, text: friendlyAuthMessage(error))
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                inlineMessage = AuthInlineMessage(kind: .error, text: "Apple sign-in could not be completed. Please try again.")
                return
            }
            if let givenName = credential.fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines), !givenName.isEmpty {
                pendingFirstName = givenName
            }
            await performAuth {
                try await app.auth.signInWithApple(credential: credential)
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                inlineMessage = AuthInlineMessage(kind: .error, text: "Sign in with Apple was canceled.")
            } else {
                inlineMessage = AuthInlineMessage(kind: .error, text: "Apple sign-in could not be completed. Please try again.")
            }
        }
    }

    private func performAuth(_ operation: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await operation()
        } catch {
            inlineMessage = AuthInlineMessage(kind: .error, text: friendlyAuthMessage(error))
        }
    }

    private func validateEmailPassword(confirming: Bool) -> Bool {
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.contains("@"), cleaned.contains(".") else {
            inlineMessage = AuthInlineMessage(kind: .error, text: "Enter a valid email address.")
            return false
        }
        guard password.count >= 8 else {
            inlineMessage = AuthInlineMessage(kind: .error, text: "Password must be at least 8 characters.")
            return false
        }
        if confirming, password != confirmPassword {
            inlineMessage = AuthInlineMessage(kind: .error, text: "Passwords do not match.")
            return false
        }
        return true
    }

    private func friendlyAuthMessage(_ error: Error) -> String {
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = text.lowercased()
        if lower.contains("network") || lower.contains("offline") || lower.contains("unavailable") {
            return "Check your connection and try again."
        }
        if lower.contains("too many") { return "Too many attempts. Try again in a few minutes." }
        if lower.contains("firebase") ||
            lower.contains("backend") ||
            lower.contains("internal") ||
            lower.contains("document") {
            return "Couldn’t complete that right now. Try again."
        }
        return text.isEmpty ? "Couldn’t complete that right now. Try again." : text
    }
}

private enum AuthRoute: Hashable {
    case intro
    case choice
    case signUp
    case signIn
    case reset
}

private struct AuthInlineMessage: Equatable {
    enum Kind { case success, error }
    let kind: Kind
    let text: String
}

private struct AuthCardTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.mrTitle)
                .foregroundStyle(MRColor.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text(subtitle)
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }
}

private struct AuthFormCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 15) {
            AuthCardTitle(title: title, subtitle: subtitle)
            content
        }
        .padding(18)
        .glassRounded(cornerRadius: 32, tint: MRColor.backgroundTop.opacity(0.10), strokeOpacity: 0.54, shadowOpacity: 0.08)
    }
}

private struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.mrMicro)
                .tracking(2.2)
                .foregroundStyle(MRColor.tertiaryText)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .authInputSurface()
        }
    }
}

private struct AuthSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.mrMicro)
                .tracking(2.2)
                .foregroundStyle(MRColor.tertiaryText)
            SecureField(placeholder, text: $text)
                .textContentType(contentType)
                .authInputSurface()
        }
    }
}

private struct AuthPrimaryButton: View {
    let title: String
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isBusy { ProgressView().tint(.white) }
                Text(title)
            }
            .font(.mrBody.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(MRColor.accentDeep.opacity(isBusy ? 0.62 : 1), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressablePolish())
        .accessibilityLabel(title)
    }
}

private struct AuthSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.mrBody.weight(.bold))
                .foregroundStyle(MRColor.text)
                .frame(maxWidth: .infinity, minHeight: 50)
                .glassCapsule(tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.34, shadowOpacity: 0.02)
                .contentShape(Capsule())
        }
        .buttonStyle(PressablePolish())
        .accessibilityLabel(title)
    }
}

private struct AuthFooterSwitch: View {
    let prefix: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(prefix) \(actionTitle)")
                .font(.mrSmall.weight(.semibold))
                .foregroundStyle(MRColor.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(prefix) \(actionTitle)")
    }
}

private struct IntroPill: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .font(.mrSmall.weight(.bold))
        }
        .foregroundStyle(MRColor.accentDeep)
        .frame(maxWidth: .infinity, minHeight: 70)
        .glassRounded(cornerRadius: 22, tint: MRColor.accentSoft.opacity(0.22), strokeOpacity: 0.38, shadowOpacity: 0.03)
    }
}

private struct IntroRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MRColor.accentDeep)
                .frame(width: 34, height: 34)
                .glassCircle(tint: MRColor.accentSoft.opacity(0.28), strokeOpacity: 0.28, shadowOpacity: 0.01)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mrBody.weight(.bold))
                    .foregroundStyle(MRColor.text)
                Text(subtitle)
                    .font(.mrSmall)
                    .foregroundStyle(MRColor.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
    }
}

private struct LegalLinks: View {
    @Environment(\.openURL) private var openURL
    private let termsURL = URL(string: "https://mealrecap.app/terms")!
    private let privacyURL = URL(string: "https://mealrecap.app/privacy")!

    var body: some View {
        HStack(spacing: 4) {
            Text("By continuing, you agree to the")
            Button("Terms") { openURL(termsURL) }
                .contentShape(Rectangle())
            Text("and")
            Button("Privacy Policy") { openURL(privacyURL) }
                .contentShape(Rectangle())
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(MRColor.tertiaryText)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

private extension View {
    func authInputSurface() -> some View {
        self
            .font(.mrBody)
            .foregroundStyle(MRColor.text)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .glassRounded(cornerRadius: 20, tint: MRColor.backgroundTop.opacity(0.08), strokeOpacity: 0.34, shadowOpacity: 0.02)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
