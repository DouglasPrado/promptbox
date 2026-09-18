import CoreGraphics

/// Medidas compartilhadas da interface. Centralizadas para que o launcher e o editor
/// mantenham o mesmo ritmo visual (PRD §19).
enum Metrics {

    // Painéis
    static let launcherWidth: CGFloat = 680
    static let editorWidth: CGFloat = 560
    static let panelCornerRadius: CGFloat = 16
    static let panelBorderWidth: CGFloat = 1

    // Linhas do launcher
    static let searchFieldHeight: CGFloat = 60
    static let rowHeight: CGFloat = 56
    static let rowCornerRadius: CGFloat = 10
    static let listMaxHeight: CGFloat = 480
    static let footerHeight: CGFloat = 40

    // Ícones
    static let iconTileSize: CGFloat = 34
    static let iconTileCornerRadius: CGFloat = 9
    static let iconGlyphSize: CGFloat = 15

    // Espaçamento
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 20

    // Campos e botões
    static let fieldHeight: CGFloat = 38
    static let fieldCornerRadius: CGFloat = 8
    static let buttonHeight: CGFloat = 32
    static let buttonCornerRadius: CGFloat = 8
    static let shortcutCornerRadius: CGFloat = 5
}
