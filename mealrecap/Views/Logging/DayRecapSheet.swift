import SwiftUI

struct DayRecapSheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Capsule().fill(MRColor.line).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                    Text("Recap your whole day")
                        .font(.mrTitle)
                        .foregroundStyle(MRColor.text)
                    Text("Example: I skipped breakfast, had sushi and miso soup for lunch, two coffees, then steak with potatoes and ice cream.")
                        .font(.mrBody)
                        .foregroundStyle(MRColor.secondaryText)
                        .lineSpacing(3)

                    TextEditor(text: $text)
                        .font(.mrBody)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .frame(minHeight: 170)
                        .background(MRColor.card.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(MRColor.line.opacity(0.36), lineWidth: 1))
                }
                .padding(24)
                .padding(.bottom, 86)
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .contentMargins(.top, 0, for: .scrollContent)
            .contentMargins(.bottom, 0, for: .scrollContent)

            Button {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                isWorking = true
                Task {
                    await app.logDayRecap(trimmed)
                    app.markPaywallMilestoneIfNeeded(.firstRecapSuccess)
                    isWorking = false
                    dismiss()
                }
            } label: {
                HStack {
                    if isWorking { ProgressView().tint(.white) }
                    Text("Organize my day")
                }
                .font(.mrHeadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(MRColor.accent)
                .clipShape(Capsule())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.regularMaterial)
        }
        .background(
            AmbientBackground()
        )
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
}
