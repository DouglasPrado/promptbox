import AppKit

/// Painel flutuante sem chrome, no espírito do Spotlight (PRD §23).
/// Borderless para que o desenho do painel venha inteiro do SwiftUI.
///
/// `nonactivatingPanel` é o que permite o painel virar key window **sem** ativar
/// o app. Com a ativação cooperativa do macOS 14+, um app em background não
/// consegue se ativar sozinho a partir de uma hotkey; sem esse estilo o painel
/// aparecia mas o teclado continuava no app da frente.
final class FloatingPanel: NSPanel {

    /// Disparado pelo ESC (PRD §24 — closeOnEscape).
    var onCancel: (() -> Void)?

    /// Teclas do painel são tratadas aqui, antes do campo de texto que estiver
    /// com o foco. Retornar `true` consome o evento.
    ///
    /// Um monitor global (`NSEvent.addLocalMonitorForEvents`) dependeria do
    /// ciclo de vida da view SwiftUI para ser instalado — e na primeira exibição
    /// do painel ele não estava instalado a tempo, deixando o teclado morto.
    var keyHandler: ((NSEvent) -> Bool)?

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

        // Fase 1: o painel permanece visível quando o app perde o foco, para
        // facilitar a inspeção do protótipo. Revisitar na Fase 4.
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyHandler?(event) == true { return }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
