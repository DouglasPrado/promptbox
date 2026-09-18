import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Insere o prompt no app que estava em foco antes do Promptbox abrir (PRD §36–40).
///
/// Caminho: guardar o clipboard → copiar o prompt → devolver o foco ao app anterior
/// → ⌘V → (opcional) Enter → restaurar o clipboard.
@MainActor
final class PromptInserter {

    private var previousApp: NSRunningApplication?

    /// Chamado antes de o painel roubar o foco.
    func captureFrontmostApp() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp = front
    }

    var hasPermission: Bool { AXIsProcessTrusted() }

    func insert(_ prompt: Prompt, mode: InsertMode) {
        guard hasPermission else {
            presentPermissionAlert()
            return
        }

        let target = previousApp
        let saved = pasteboardSnapshot()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)

        // Devolve a ativação explicitamente: no macOS 14+ um app só ativa outro
        // com esse consentimento.
        if let target {
            NSApp.yieldActivation(to: target)
        }

        Task { @MainActor in
            target?.activate()

            // O app anterior precisa de um instante para voltar a receber eventos.
            try? await Task.sleep(for: .milliseconds(140))
            post(key: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)

            if mode == .insertAndSend {
                try? await Task.sleep(for: .milliseconds(80))
                post(key: CGKeyCode(kVK_Return), flags: [])
            }

            // Restaurar cedo demais faria o app de destino ler o clipboard antigo:
            // alguns apps leem a área de transferência de forma preguiçosa.
            try? await Task.sleep(for: .milliseconds(800))
            restore(saved)
        }
    }

    // MARK: - Eventos de teclado

    /// `cghidEventTap` entrega o evento no nível mais baixo, como se viesse do
    /// teclado físico — é o que apps de terminal esperam.
    private func post(key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - Clipboard

    /// O conteúdo original do clipboard não pode ser perdido (PRD §40), então a
    /// cópia guarda todos os tipos de cada item, não só o texto.
    private func pasteboardSnapshot() -> [[NSPasteboard.PasteboardType: Data]] {
        NSPasteboard.general.pasteboardItems?.map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    contents[type] = data
                }
            }
            return contents
        } ?? []
    }

    private func restore(_ snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let items = snapshot.map { contents -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }

        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }

    // MARK: - Permissão (PRD §41)

    private func presentPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Promptbox precisa de permissão de Acessibilidade"
        alert.informativeText = """
        Para inserir o prompt no app anterior, o Promptbox precisa ser autorizado em:

        Ajustes do Sistema → Privacidade e Segurança → Acessibilidade

        Depois de autorizar, tente novamente.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Abrir Ajustes")
        alert.addButton(withTitle: "Depois")

        guard alert.runAbovePanels() == .alertFirstButtonReturn else { return }

        // Registra o app na lista de Acessibilidade e abre o painel do sistema.
        // A chave é usada como literal porque `kAXTrustedCheckOptionPrompt` é uma
        // global mutável, rejeitada pelo modo de concorrência do Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
