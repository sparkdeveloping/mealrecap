import SwiftUI

struct ChatComposer: View {
    @Binding var text: String
    let send: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("What did you eat?", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.mrBody)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(MRColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(MRColor.line.opacity(0.45), lineWidth: 1))
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(MRColor.accent)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 12)
    }
}
