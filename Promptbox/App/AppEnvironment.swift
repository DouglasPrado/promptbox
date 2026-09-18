import SwiftUI

/// Estado compartilhado do protótipo. Dono dos modelos e dos dois painéis.
@MainActor
final class AppEnvironment {

    let store = PromptStore()
    let inserter = PromptInserter()

    private var launcherPanel: FloatingPanelController<LauncherView>?
    private var editorPanel: FloatingPanelController<PromptEditorView>?
    private var didBootstrap = false

    /// Falso quando ⌥Space já pertence a outro app — o menu avisa em vez de
    /// deixar o usuário achar que a hotkey existe.
    var isLauncherHotkeyActive = true

    /// Abrir o Promptbox é abrir a busca: o painel aparece assim que o app sobe.
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        showLauncher()
    }

    func toggleLauncher() {
        // A decisão vem do painel, não de um espelho de estado: o macOS pode
        // ordenar a janela para fora sem passar por `hideLauncher()`.
        launcherPanel?.isVisible == true ? hideLauncher() : showLauncher()
    }

    func showLauncher() {
        // Precisa vir antes de o painel ativar o Promptbox (PRD §36).
        inserter.captureFrontmostApp()
        launcher.show()
    }

    func hideLauncher() {
        // Fechar zera a busca: reabrir mostra os recentes, não o último termo
        // digitado (PRD §9).
        guard launcherPanel != nil else { return }
        launcherModel.reset()
        launcherPanel?.hide()
    }

    /// O editor substitui o launcher na tela; ao fechar, o launcher volta.
    /// Com `prompt`, abre em modo edição reaproveitando o mesmo componente (PRD §15).
    func showEditor(editing prompt: Prompt? = nil) {
        editorModel.load(prompt)
        hideLauncher()
        editor.show()
    }

    private func closeEditor() {
        editorPanel?.hide()
        showLauncher()
    }

    // MARK: - Modelos

    private lazy var launcherModel: LauncherViewModel = {
        let model = LauncherViewModel(store: store)
        model.onInsert = { [weak self] prompt, mode in
            self?.store.record(mode, prompt: prompt)
            self?.inserter.insert(prompt, mode: mode)
        }
        model.onNewPrompt = { [weak self] in self?.showEditor() }
        model.onEditPrompt = { [weak self] prompt in self?.showEditor(editing: prompt) }
        model.onDeletePrompt = { [weak self] prompt in self?.confirmDelete(prompt) }
        model.onClose = { [weak self] in self?.hideLauncher() }
        return model
    }()

    private lazy var editorModel: PromptEditorViewModel = {
        let model = PromptEditorViewModel()
        model.onSave = { [weak self] prompt in
            self?.store.save(prompt)
            self?.closeEditor()
        }
        model.onCancel = { [weak self] in self?.closeEditor() }
        model.onDelete = { [weak self] prompt in
            self?.confirmDelete(prompt, closingEditor: true)
        }
        return model
    }()

    /// Excluir é irreversível, então passa por confirmação. O botão padrão é
    /// Cancelar: um Enter distraído não pode apagar um prompt.
    private func confirmDelete(_ prompt: Prompt, closingEditor: Bool = false) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Excluir \"\(prompt.title)\"?"
        alert.informativeText = "Esta ação não pode ser desfeita."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Excluir")
        alert.addButton(withTitle: "Cancelar")
        alert.buttons[0].hasDestructiveAction = true
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"

        guard alert.runAbovePanels() == .alertFirstButtonReturn else { return }

        store.delete(prompt)
        launcherModel.clampSelection()

        if closingEditor {
            closeEditor()
        }
    }

    // MARK: - Painéis

    private var launcher: FloatingPanelController<LauncherView> {
        if let launcherPanel { return launcherPanel }

        let model = launcherModel
        let panel = FloatingPanelController<LauncherView>(
            identifier: PanelID.launcher,
            width: Metrics.launcherWidth,
            onCancel: { [weak self] in self?.hideLauncher() },
            keyHandler: { model.handleKey($0) }
        ) {
            LauncherView(model: model)
        }

        launcherPanel = panel
        return panel
    }

    private var editor: FloatingPanelController<PromptEditorView> {
        if let editorPanel { return editorPanel }

        let model = editorModel
        let panel = FloatingPanelController<PromptEditorView>(
            identifier: PanelID.editor,
            width: Metrics.editorWidth,
            onCancel: { [weak self] in self?.closeEditor() },
            keyHandler: { model.handleKey($0) }
        ) {
            PromptEditorView(model: model)
        }

        editorPanel = panel
        return panel
    }
}
