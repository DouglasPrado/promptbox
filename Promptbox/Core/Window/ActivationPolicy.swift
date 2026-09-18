import AppKit

/// Dono único da política de ativação do app.
///
/// Teclas do sistema só chegam ao app em primeiro plano e, desde o macOS 14, um
/// app `.accessory` não se ativa sozinho. O Promptbox vira `.regular` enquanto
/// houver painel na tela e volta a `.accessory` quando o último fecha.
///
/// O estado é um conjunto de painéis visíveis, e não um contador: chamadas
/// repetidas de mostrar ou esconder não desregulam a conta.
@MainActor
final class ActivationPolicy {

    private var visiblePanels: Set<String> = []

    func panelDidShow(_ identifier: String) {
        visiblePanels.insert(identifier)
        apply()
    }

    func panelDidHide(_ identifier: String) {
        visiblePanels.remove(identifier)
        apply()
    }

    private func apply() {
        let desired: NSApplication.ActivationPolicy = visiblePanels.isEmpty ? .accessory : .regular
        guard NSApp.activationPolicy() != desired else { return }
        NSApp.setActivationPolicy(desired)
    }
}
