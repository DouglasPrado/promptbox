import AppKit

/// Painel flutuante sem chrome, no espírito do Spotlight (PRD §23).
/// Borderless para que o desenho do painel venha inteiro do SwiftUI.
///
/// `nonactivatingPanel` é o que permite o painel virar key window sem ativar o
/// app: com a ativação cooperativa do macOS 14+, um app em background não
/// consegue se ativar sozinho a partir de uma hotkey.
final class FloatingPanel: NSPanel {

    /// Disparado pelo ESC (PRD §24 — closeOnEscape).
    var onCancel: (() -> Void)?

    /// Teclas do painel são tratadas aqui, antes do campo de texto que estiver
    /// com o foco. Retornar `true` consome o evento.
    ///
    /// Um monitor global (`NSEvent.addLocalMonitorForEvents`) dependeria do ciclo
    /// de vida da view SwiftUI para ser instalado — e na primeira exibição do
    /// painel ele não estava instalado a tempo, deixando o teclado morto.
    var keyHandler: ((KeyStroke) -> Bool)?

    init(contentRect: NSRect, identifier: String) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.identifier = NSUserInterfaceItemIdentifier(identifier)

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false

        // O painel é efêmero: não deve ser recriado pela restauração de janelas
        // do macOS na próxima execução.
        isRestorable = false

        // Sumir ao perder o foco é decisão de produto e varia por painel: o
        // launcher some, o editor não pode sumir com texto não salvo dentro.
        // Quem coordena os painéis decide (PRD §4.3).
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyHandler?(KeyStroke(event)) == true { return }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
