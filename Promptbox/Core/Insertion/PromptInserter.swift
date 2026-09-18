import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Insere o prompt no app que estava em foco antes do Promptbox abrir (PRD §36–40).
///
/// Caminho: guardar o clipboard → copiar o prompt → devolver o foco ao app anterior
/// → ⌘V → (opcional) Enter → restaurar o clipboard.
@MainActor
final class PromptInserter {

    enum Outcome {
        case started
        /// Sem permissão de Acessibilidade não há como postar o ⌘V (PRD §41).
        case permissionRequired
    }

    private var previousApp: NSRunningApplication?

    /// Inserção em voo. A restauração do clipboard acontece no fim dela, então
    /// uma segunda inserção precisa cancelar a primeira em vez de disputar.
    private var pendingInsertion: Task<Void, Never>?

    /// Clipboard do usuário, preservado enquanto houver inserção em andamento.
    private var clipboardBackup: [[NSPasteboard.PasteboardType: Data]]?

    var hasPermission: Bool { AXIsProcessTrusted() }

    /// Chamado antes de o painel roubar o foco.
    func captureFrontmostApp() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp = front
    }

    @discardableResult
    func insert(_ prompt: Prompt, mode: InsertMode) -> Outcome {
        guard hasPermission else { return .permissionRequired }

        // Se já há inserção em voo, o clipboard guardado é o do usuário — não o
        // prompt anterior. Preserva o backup e cancela a restauração pendente.
        let backup = clipboardBackup ?? pasteboardSnapshot()
        clipboardBackup = backup
        pendingInsertion?.cancel()

        let target = previousApp

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)

        // Devolve a ativação explicitamente: no macOS 14+ um app só ativa outro
        // com esse consentimento.
        if let target {
            NSApp.yieldActivation(to: target)
        }

        pendingInsertion = Task { @MainActor [weak self] in
            guard let self else { return }

            await self.paste(into: target, mode: mode)
            guard !Task.isCancelled else { return }

            // Alguns apps leem a área de transferência de forma preguiçosa;
            // restaurar cedo demais faria o destino ler o conteúdo antigo.
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            self.restoreClipboard()
        }

        return .started
    }

    // MARK: - Colagem

    private func paste(into target: NSRunningApplication?, mode: InsertMode) async {
        if let target {
            if !target.activate() {
                Log.insertion.warning("O app de destino não aceitou a ativação.")
            }
            await waitForActivation(of: target)
        }

        post(key: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)

        if mode == .insertAndSend {
            try? await Task.sleep(for: .milliseconds(80))
            post(key: CGKeyCode(kVK_Return), flags: [])
        }
    }

    /// Espera o destino voltar ao primeiro plano em vez de apostar num tempo fixo:
    /// sob carga a ativação leva bem mais que uma constante escolhida no olho.
    private func waitForActivation(
        of target: NSRunningApplication,
        timeout: Duration = .milliseconds(800)
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
                // Pequena folga para a janela do destino virar key.
                try? await Task.sleep(for: .milliseconds(40))
                return
            }

            try? await Task.sleep(for: .milliseconds(20))
        }

        Log.insertion.warning("Tempo esgotado esperando a ativação do app de destino; o ⌘V pode cair no app errado.")
    }

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

    private func restoreClipboard() {
        guard let backup = clipboardBackup else { return }
        clipboardBackup = nil

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let items = backup.map { contents -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }

        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }
}
