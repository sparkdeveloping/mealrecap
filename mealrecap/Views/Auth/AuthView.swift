import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var app: AppModel
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var isBusy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 48)

                VStack(spacing: 12) {
                    Text("MealRecap")
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .foregroundStyle(MRColor.text)
                    Text("Chat it. Say it. Snap it.\nYour day, cleanly recapped.")
                        .font(.mrBody)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(MRColor.secondaryText)
                }

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .authField()
                    SecureField("Local password", text: $password)
                        .textContentType(isCreatingAccount ? .newPassword : .password)
                        .authField()

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isBusy { ProgressView().tint(.white) }
                            Text(isCreatingAccount ? "Create local account" : "Continue")
                        }
                        .font(.mrHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(MRColor.accent)
                        .clipShape(Capsule())
                    }
                    .disabled(isBusy || email.isEmpty || password.count < 6)

                    Text("Your local MealRecap account keeps your cloud data grouped on this device.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MRColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Button(isCreatingAccount ? "Already have a local account? Continue" : "New here? Create local account") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            isCreatingAccount.toggle()
                        }
                    }
                    .font(.mrSmall)
                    .foregroundStyle(MRColor.secondaryText)
                }
                .padding(22)
                .premiumCard()
            }
            .padding(.horizontal, MRSpace.page)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func submit() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if isCreatingAccount {
                try await app.auth.createAccount(email: email, password: password)
            } else {
                try await app.auth.signIn(email: email, password: password)
            }
        } catch {
            app.errorMessage = error.localizedDescription
        }
    }
}

private extension View {
    func authField() -> some View {
        self
            .font(.mrBody)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(MRColor.background.opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(MRColor.line.opacity(0.7), lineWidth: 1))
    }
}
