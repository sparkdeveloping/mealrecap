import SwiftUI

struct VoiceLogSheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var editorFocused: Bool

    @State private var recapText = ""
    @State private var isAnalyzing = false
    @State private var pendingReview: PendingMealReview?

    private var cleanText: String { recapText.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Capsule()
                    .fill(MRColor.line)
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 12) {
                    DictationMark()
                    Text("Say or type what you ate")
                        .font(.mrTitle)
                        .foregroundStyle(MRColor.text)
                        .multilineTextAlignment(.center)
                    Text("Use the keyboard mic or write naturally. MealRecap will turn it into meals.")
                        .font(.mrBody)
                        .foregroundStyle(MRColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)

                transcriptCard

                Button {
                    analyzeMeal()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isAnalyzing ? "sparkles" : "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                        Text(isAnalyzing ? "Creating your meal…" : "Analyze meal")
                            .font(.mrHeadline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(MRColor.accent)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(PressablePolish())
                .disabled(cleanText.isEmpty || isAnalyzing)
                .opacity(cleanText.isEmpty || isAnalyzing ? 0.55 : 1)
                .accessibilityLabel("Analyze meal")

                Button("Cancel") {
                    dismiss()
                }
                .font(.mrSmall.weight(.semibold))
                .foregroundStyle(MRColor.secondaryText)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Cancel voice entry")
            }
            .padding(24)
            .padding(.bottom, 14)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AmbientBackground())
        .interactiveDismissDisabled(isAnalyzing)
        .onAppear {
            app.speech.cancelRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                editorFocused = true
            }
        }
        .fullScreenCover(item: $pendingReview) { pending in
            ReviewMealView(pending: pending) {
                dismiss()
            } onTryAgain: {
                recapText = pending.originPrompt ?? recapText
                editorFocused = true
            }
            .environmentObject(app)
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Quick recap")
                    .font(.mrMicro)
                    .tracking(1.8)
                    .foregroundStyle(MRColor.tertiaryText)
                Spacer()
                Text("Keyboard mic ready")
                    .font(.mrSmall.weight(.semibold))
                    .foregroundStyle(MRColor.accentDeep.opacity(0.78))
                    .lineLimit(1)
            }

            TextEditor(text: $recapText)
                .focused($editorFocused)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(MRColor.text)
                .frame(minHeight: 190)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(MRColor.card.opacity(0.80))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if recapText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Coffee and oatmeal, then a chicken rice bowl for lunch…")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(MRColor.tertiaryText.opacity(0.62))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            Text("Tap the microphone on the keyboard to dictate. You can edit before analyzing.")
                .font(.mrSmall)
                .foregroundStyle(MRColor.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .premiumCard(cornerRadius: 28, shadowOpacity: 0.05)
    }

    private func analyzeMeal() {
        guard !cleanText.isEmpty, !isAnalyzing else { return }
        isAnalyzing = true
        let text = cleanText
        Task {
            let pending = await app.analyzeMealForReview(text, source: .voice)
            await MainActor.run {
                isAnalyzing = false
                if let pending {
                    pendingReview = pending
                }
            }
        }
    }
}

private struct DictationMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(MRColor.accent.opacity(0.14))
                .frame(width: 92, height: 92)
                .blur(radius: 10)

            Image(systemName: "mic.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(MRColor.accent)
                .clipShape(Circle())
                .shadow(color: MRColor.accent.opacity(0.22), radius: 18, y: 10)
        }
        .frame(height: 104)
        .accessibilityHidden(true)
    }
}
