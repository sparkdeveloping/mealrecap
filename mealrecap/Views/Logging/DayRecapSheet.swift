import SwiftUI

struct DayRecapSheet: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(MRColor.line).frame(width: 42, height: 5).frame(maxWidth: .infinity)
            Text("Recap your whole day")
                .font(.mrTitle)
                .foregroundStyle(MRColor.text)
            Text("Example: I skipped breakfast, had sushi and miso soup for lunch, two coffees, then steak with potatoes and ice cream.")
                .font(.mrBody)
                .foregroundStyle(MRColor.secondaryText)

            TextEditor(text: $text)
                .font(.mrBody)
                .scrollContentBackground(.hidden)
                .padding(16)
                .frame(minHeight: 160)
                .background(MRColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

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
            Spacer()
        }
        .padding(24)
        .background(MRColor.background)
    }
}
