import AppKit

extension NSAlert {

    /// Exibe o alerta acima dos painéis do Promptbox.
    ///
    /// O launcher e o editor ficam no nível `.floating`; um alerta comum nasce no
    /// nível normal e abriria atrás deles — a confirmação simplesmente não
    /// apareceria.
    func runAbovePanels() -> NSApplication.ModalResponse {
        window.level = .modalPanel
        return runModal()
    }
}
