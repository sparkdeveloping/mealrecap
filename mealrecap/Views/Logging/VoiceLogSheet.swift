import SwiftUI

struct VoiceLogSheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(MRColor.line).frame(width: 42, height: 5)
            Text("Say what you ate")
                .font(.mrTitle)
                .foregroundStyle(MRColor.text)
            Text(app.speech.transcript.isEmpty ? "Hold a thought naturally. MealRecap will turn it into meals." : app.speech.transcript)
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 80)
                .padding()
                .background(MRColor.card.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Button {
                Task {
                    do {
                        if app.speech.isRecording {
                            app.speech.stop()
                        } else {
                            try await app.speech.requestPermission()
                            try app.speech.start()
                        }
                    } catch {
                        app.errorMessage = error.localizedDescription
                    }
                }
            } label: {
                Image(systemName: app.speech.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 74, height: 74)
                    .background(app.speech.isRecording ? MRColor.danger : MRColor.accent)
                    .clipShape(Circle())
            }

            Button("Log voice recap") {
                let transcript = app.speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !transcript.isEmpty else { return }
                app.speech.stop()
                Task { await app.logText(transcript, source: .voice) }
                dismiss()
            }
            .font(.mrHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(MRColor.accent)
            .clipShape(Capsule())
            .disabled(app.speech.transcript.isEmpty)
        }
        .padding(24)
        .background(AmbientBackground())
    }
}
