import AppKit
import SwiftUI

/// Dono do ciclo de vida de um painel flutuante.
///
/// Cuida só da janela: posição, exibição e foco. Política de ativação do app e
/// navegação entre painéis são decisões de quem coordena, não daqui.
///
/// A altura acompanha o conteúdo SwiftUI através de `NSHostingController` com
/// `sizingOptions = .preferredContentSize` (essa opção não tem efeito em
/// `NSHostingView`).
///
/// A classe não é genérica de propósito: apenas o inicializador é. Com o
/// parâmetro de tipo na classe, o otimizador SIL do Swift 6.3 quebra ao compilar
/// o destrutor em modo Release (`EarlyPerfInliner`), e o tipo do conteúdo não
/// serve para nada depois que a view vira um `NSHostingController`.
@MainActor
final class FloatingPanelController {

    let identifier: String

    private let panel: FloatingPanel
    private let hostingController: NSViewController

    /// Fração da altura da tela usada como margem superior. O painel fica acima
    /// do centro óptico, como Spotlight e Raycast.
    private let topInsetRatio: CGFloat

    var isVisible: Bool { panel.isVisible }

    init<Content: View>(
        identifier: String,
        width: CGFloat,
        topInsetRatio: CGFloat = 0.20,
        onCancel: @escaping () -> Void,
        keyHandler: @escaping (KeyStroke) -> Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.identifier = identifier
        self.topInsetRatio = topInsetRatio

        let hosting = NSHostingController(rootView: content())
        hosting.sizingOptions = [.preferredContentSize]
        hosting.view.frame.size = CGSize(width: width, height: 1)
        hostingController = hosting

        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 1),
            identifier: identifier
        )
        panel.contentViewController = hostingController
        panel.onCancel = onCancel
        panel.keyHandler = keyHandler
    }

    func show() {
        center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        focus()
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Centraliza horizontalmente e ancora o topo em `topInsetRatio` da tela em
    /// que está o cursor — em vários monitores, o painel abre onde o usuário está.
    func center() {
        guard let screen = screenUnderCursor() else { return }

        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - visible.height * topInsetRatio - size.height

        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: max(visible.minY, y).rounded()))
    }

    private func screenUnderCursor() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) } ?? panel.screen ?? NSScreen.main
    }

    /// Põe o cursor no primeiro campo de texto do painel.
    ///
    /// O SwiftUI entrega o foco de forma pouco confiável dentro de um painel
    /// borderless — às vezes o painel abre e o que é digitado não chega a lugar
    /// nenhum. Aqui o primeiro respondedor é escolhido explicitamente, e repetido
    /// no ciclo seguinte do runloop porque na primeira exibição a hierarquia do
    /// SwiftUI ainda pode não estar montada.
    func focus() {
        panel.makeKey()
        focusFirstTextField()

        DispatchQueue.main.async { [weak self] in
            self?.focusFirstTextField()
        }

        panel.invalidateShadow()
    }

    private func focusFirstTextField() {
        guard let field = panel.contentView.flatMap(Self.firstTextField(in:)) else { return }
        panel.makeFirstResponder(field)
    }

    private static func firstTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField { return field }

        for subview in view.subviews {
            if let field = firstTextField(in: subview) { return field }
        }

        return nil
    }
}
