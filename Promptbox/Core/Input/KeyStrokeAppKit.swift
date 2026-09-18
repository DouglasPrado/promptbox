import AppKit

extension KeyStroke {

    /// Ponte com o AppKit, usada só na fronteira do painel.
    init(_ event: NSEvent) {
        var modifiers: Modifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }

        self.init(
            code: event.keyCode,
            modifiers: modifiers,
            characters: event.charactersIgnoringModifiers
        )
    }
}
