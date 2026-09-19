import SwiftUI

/// Paleta do Promptbox, derivada dos mockups em `docs/` e das diretrizes do PRD §19.
/// Dark mode é o único tema desta fase.
enum Palette {

    // Superfícies
    static let panel = Color(hex: 0x1A1B1F)
    static let panelElevated = Color(hex: 0x212227)
    static let footer = Color(hex: 0x141519)
    static let tile = Color.white.opacity(0.06)

    // Traços
    static let border = Color.white.opacity(0.08)
    static let separator = Color.white.opacity(0.06)

    // Texto
    static let textPrimary = Color(hex: 0xF5F5F7)
    static let textSecondary = Color(hex: 0x9A9AA2)
    static let textTertiary = Color(hex: 0x6E6E76)
    static let textOnAccent = Color.white
    static let textOnAccentSecondary = Color.white.opacity(0.78)

    // Seleção
    static let accent = Color(hex: 0x0A70F5)
    static let accentHover = Color(hex: 0x2A86FF)

    // Voice Insert
    static let recording = Color(hex: 0xFF453A)
    static let waveform = Color(hex: 0x4A9EFF)
    /// Mais forte que `separator`: sobre o blur do overlay, 6% de branco some.
    static let voiceDivider = Color.white.opacity(0.14)

    // Cores de categoria (usadas nos ícones do launcher)
    static let categoryBlue = Color(hex: 0x3B82F6)
    static let categoryRed = Color(hex: 0xEF4444)
    static let categoryGreen = Color(hex: 0x34D399)
    static let categoryPurple = Color(hex: 0xA78BFA)
    static let categoryOrange = Color(hex: 0xF97316)
    static let categoryYellow = Color(hex: 0xFBBF24)
    static let categoryGray = Color(hex: 0x8E8E96)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
