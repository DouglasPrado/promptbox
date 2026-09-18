import SwiftUI

/// Teclas exibidas como no Raycast: pequenos blocos arredondados.
struct ShortcutBadge: View {

    let keys: [String]
    var style: Style = .neutral

    enum Style {
        case neutral
        case onAccent
    }

    var body: some View {
        HStack(spacing: Metrics.spacingXS) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(Typography.shortcut)
                    .foregroundStyle(foreground)
                    .frame(minWidth: 20, minHeight: 19)
                    .padding(.horizontal, 4)
                    .background(background, in: RoundedRectangle(cornerRadius: Metrics.shortcutCornerRadius, style: .continuous))
            }
        }
    }

    private var foreground: Color {
        switch style {
        case .neutral: Palette.textSecondary
        case .onAccent: Palette.textOnAccent
        }
    }

    private var background: Color {
        switch style {
        case .neutral: Color.white.opacity(0.07)
        case .onAccent: Color.white.opacity(0.20)
        }
    }
}
