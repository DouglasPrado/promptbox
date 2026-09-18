import AppKit
import SwiftUI

/// Dono do ciclo de vida do painel flutuante.
/// A altura acompanha o conteúdo SwiftUI: `NSHostingController` com
/// `sizingOptions = .preferredContentSize` gera as constraints de tamanho ideal
/// (essa opção não tem efeito em `NSHostingView`).
@MainActor
final class FloatingPanelController<Content: View> {

    private let panel: FloatingPanel
    private let hostingController: NSHostingController<Content>

    /// Fração da altura da tela usada como margem superior. O painel fica
    /// acima do centro óptico, como Spotlight e Raycast.
    private let topInsetRatio: CGFloat

    var isVisible: Bool { panel.isVisible }

    init(
        identifier: String,
        width: CGFloat,
        topInsetRatio: CGFloat = 0.20,
        onCancel: @escaping () -> Void,
        keyHandler: @escaping (NSEvent) -> Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.topInsetRatio = topInsetRatio

        hostingController = NSHostingController(rootView: content())
        hostingController.sizingOptions = [.preferredContentSize]
        hostingController.view.frame.size = CGSize(width: width, height: 1)

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

        // Teclas do sistema só chegam ao app em primeiro plano, e desde o macOS 14
        // um app `.accessory` não consegue se ativar sozinho. Virar `.regular`
        // enquanto o painel está aberto é o que torna a ativação possível.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        focus()
    }

    func hide() {
        panel.orderOut(nil)

        // Volta ao modo background assim que o painel sai da tela, para o app
        // não ocupar o Dock enquanto não estiver em uso (PRD §42).
        if !NSApp.windows.contains(where: { $0.isVisible && $0 is FloatingPanel }) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    /// Centraliza horizontalmente e ancora o topo em `topInsetRatio` da tela.
    func center() {
        guard let screen = panel.screen ?? NSScreen.main else { return }

        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - visible.height * topInsetRatio - size.height

        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: max(visible.minY, y).rounded()))
    }

    /// Põe o cursor no primeiro campo de texto do painel.
    ///
    /// O SwiftUI entrega o foco por conta própria de forma pouco confiável dentro
    /// de um painel borderless — às vezes o painel abre e o que é digitado não
    /// chega a lugar nenhum. Aqui o primeiro respondedor é escolhido explicitamente,
    /// e repetido no próximo ciclo do runloop porque na primeira exibição a
    /// hierarquia do SwiftUI ainda pode não estar montada.
    func focus() {
        panel.makeKey()
        focusFirstTextField()

        DispatchQueue.main.async { [weak self] in
            self?.focusFirstTextField()
        }

        panel.invalidateShadow()
    }

    private func focusFirstTextField() {
        guard let field = panel.contentView?.firstTextField() else { return }
        panel.makeFirstResponder(field)
    }
}
