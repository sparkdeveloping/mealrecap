import SwiftUI

struct ProcessingOverlay: View {
    let title: String
    let subtitle: String

    @State private var spin = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.72))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(MRColor.background)
                        .frame(width: 78, height: 78)
                        .scaleEffect(breathe ? 1.05 : 0.96)
                        .shadow(color: MRColor.accentDeep.opacity(0.16), radius: 24, y: 12)

                    Circle()
                        .stroke(MRColor.accentDeep.opacity(0.14), lineWidth: 9)
                        .frame(width: 58, height: 58)

                    Circle()
                        .trim(from: 0.05, to: 0.72)
                        .stroke(MRColor.accentDeep, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .frame(width: 58, height: 58)
                        .rotationEffect(.degrees(spin ? 360 : 0))

                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MRColor.accentDeep)
                }

                VStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(MRColor.text)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.mrBody)
                        .foregroundStyle(MRColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: 330)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(.white.opacity(0.95), lineWidth: 1))
            .shadow(color: MRColor.text.opacity(0.12), radius: 34, y: 18)
            .padding(.horizontal, 28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .onAppear {
            withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 0.92).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}
