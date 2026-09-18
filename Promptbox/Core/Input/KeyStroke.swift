import Carbon.HIToolbox

/// Tecla pressionada, sem AppKit.
///
/// Os view models trabalham com este tipo em vez de `NSEvent` para que a lógica
/// de teclado seja testável sem servidor de janelas.
nonisolated struct KeyStroke: Equatable, Sendable {

    struct Modifiers: OptionSet, Sendable {
        let rawValue: Int

        static let command = Modifiers(rawValue: 1 << 0)
        static let shift = Modifiers(rawValue: 1 << 1)
        static let option = Modifiers(rawValue: 1 << 2)
        static let control = Modifiers(rawValue: 1 << 3)
    }

    let code: UInt16
    let modifiers: Modifiers
    /// Caractere sem os modificadores, usado para atalhos por letra (⌘N, ⌘E).
    let characters: String?

    init(code: UInt16, modifiers: Modifiers = [], characters: String? = nil) {
        self.code = code
        self.modifiers = modifiers
        self.characters = characters
    }

    var hasCommand: Bool { modifiers.contains(.command) }

    func matches(_ letter: Character) -> Bool {
        characters?.lowercased() == String(letter)
    }

    /// Dígito de 1 a 9 identificado pelo código físico da tecla.
    ///
    /// Ler o caractere quebraria em layouts onde o dígito exige Shift, como o
    /// AZERTY francês.
    var digit: Int? {
        KeyCode.digits.firstIndex(of: code).map { $0 + 1 }
    }
}

/// Códigos virtuais do Carbon, nomeados. Evita repetir números mágicos.
nonisolated enum KeyCode {
    static let returnKey = UInt16(kVK_Return)
    static let escape = UInt16(kVK_Escape)
    static let arrowUp = UInt16(kVK_UpArrow)
    static let arrowDown = UInt16(kVK_DownArrow)
    static let delete = UInt16(kVK_Delete)
    static let tab = UInt16(kVK_Tab)

    /// Em ordem de 1 a 9 — os códigos ANSI não são sequenciais.
    static let digits: [UInt16] = [
        UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3),
        UInt16(kVK_ANSI_4), UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_6),
        UInt16(kVK_ANSI_7), UInt16(kVK_ANSI_8), UInt16(kVK_ANSI_9)
    ]
}
