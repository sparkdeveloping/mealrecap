import SwiftUI

struct MessageBubble: View {
    let message: DayMessage

    var body: some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 42) }
            Text(message.content)
                .font(.mrBody)
                .foregroundStyle(message.role == "user" ? .white : MRColor.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(message.role == "user" ? MRColor.accent : MRColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: MRColor.text.opacity(message.role == "user" ? 0.06 : 0.04), radius: 14, x: 0, y: 8)
            if message.role != "user" { Spacer(minLength: 42) }
        }
    }
}
