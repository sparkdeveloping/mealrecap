import SwiftUI

struct FloatingDock: View {
    let onCalendar: () -> Void
    let onPhoto: () -> Void
    let onVoice: () -> Void
    let onRecap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            DockButton(systemName: "calendar", label: "Days", action: onCalendar)
            DockButton(systemName: "camera.fill", label: "Snap", action: onPhoto)
            DockButton(systemName: "mic.fill", label: "Say", action: onVoice)
            DockButton(systemName: "text.badge.plus", label: "Recap", action: onRecap)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.62), lineWidth: 1))
        .shadow(color: MRColor.accentDeep.opacity(0.32), radius: 18, x: 0, y: 16)
        .background(
            Capsule()
                .fill(MRColor.accentDeep)
                .offset(x: 7, y: 10)
                .blur(radius: 0.4)
        )
    }
}

struct DockButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 17, weight: .semibold))
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundStyle(MRColor.text)
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(MRColor.card.opacity(0.92))
                    .overlay(Circle().stroke(.white.opacity(0.68), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
