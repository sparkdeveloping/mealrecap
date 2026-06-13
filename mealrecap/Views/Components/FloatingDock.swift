import SwiftUI

struct FloatingDock: View {
    let onCalendar: () -> Void
    let onPhoto: () -> Void
    let onVoice: () -> Void
    let onRecap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            DockButton(systemName: "calendar", action: onCalendar)
            DockButton(systemName: "camera.fill", action: onPhoto)
            DockButton(systemName: "mic.fill", action: onVoice)
            DockButton(systemName: "text.badge.plus", action: onRecap)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
        .shadow(color: MRColor.text.opacity(0.13), radius: 24, x: 0, y: 14)
    }
}

struct DockButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MRColor.text)
                .frame(width: 46, height: 46)
                .background(MRColor.card.opacity(0.90))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
