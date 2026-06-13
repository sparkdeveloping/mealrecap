import SwiftUI

struct MessageBubble: View {
    let message: DayMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 42) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.mrBody)
                    .foregroundStyle(isUser ? .white : MRColor.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isUser ? AnyShapeStyle(LinearGradient(colors: [MRColor.accent, MRColor.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(MRColor.card)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(isUser ? 0.24 : 0.62), lineWidth: 1)
                    )
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.mrMicro)
                    .foregroundStyle(MRColor.tertiaryText)
                    .padding(.horizontal, 4)
            }
            if !isUser { Spacer(minLength: 42) }
        }
    }
}
