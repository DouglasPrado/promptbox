import SwiftUI

/// Tipografia do sistema: SF Pro para interface, SF Mono para conteúdo de prompt (PRD §20).
enum Typography {

    // Interface
    static let searchField = Font.system(size: 20, weight: .regular)
    static let rowTitle = Font.system(size: 14, weight: .semibold)
    static let rowSubtitle = Font.system(size: 12.5, weight: .regular)
    static let sectionTitle = Font.system(size: 12, weight: .semibold)
    static let modalTitle = Font.system(size: 16, weight: .semibold)
    static let modalSubtitle = Font.system(size: 12.5, weight: .regular)
    static let field = Font.system(size: 13.5, weight: .regular)
    static let button = Font.system(size: 13, weight: .medium)
    static let footer = Font.system(size: 11.5, weight: .regular)
    static let shortcut = Font.system(size: 11, weight: .medium)

    // Voice Insert
    static let voiceStatus = Font.system(size: 13, weight: .medium)
    /// Dígitos monoespaçados: sem isso o timer treme a cada segundo.
    static let voiceTimer = Font.system(size: 12.5, weight: .regular).monospacedDigit()
    static let voiceHint = Font.system(size: 12.5, weight: .regular)
    static let voiceGlyph = Font.system(size: 13, weight: .regular)

    // Conteúdo de prompt
    static let promptContent = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let counter = Font.system(size: 11, weight: .regular, design: .monospaced)
}
