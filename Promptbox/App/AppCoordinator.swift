import AppKit

/// Orquestra o app: donos dos modelos, dos painéis, dos atalhos globais e da
/// navegação entre launcher e editor.
///
/// Serviços (`PromptStore`, `PromptInserter`) não conhecem navegação; diálogos
/// modais ficam em `Dialogs`; a política de ativação tem dono próprio. Aqui fica
/// apenas a decisão de o que aparece quando.
@MainActor
final class AppCoordinator {

    let store: PromptStore

    private let inserter: PromptInserter
    private let activation = ActivationPolicy()

    private var launcherPanel: FloatingPanelController?
    private var editorPanel: FloatingPanelController?

    private var activationObserver: NSObjectProtocol?
    private var launcherHotkey: GlobalHotkey?
    private var editorHotkey: GlobalHotkey?
    private var didStart = false

    /// De onde o editor foi aberto, para saber ao que voltar quando fechar.
    private enum EditorOrigin {
        case launcher
        case standalone
    }

    private var editorOrigin: EditorOrigin = .standalone

    /// Falso quando ⌥Space já pertence a outro app — o menu avisa em vez de
    /// deixar o usuário achar que a hotkey existe.
    private(set) var isLauncherHotkeyActive = true

    init(store: PromptStore = PromptStore(), inserter: PromptInserter = PromptInserter()) {
        self.store = store
        self.inserter = inserter
    }

    /// Abrir o Promptbox é abrir a busca: o painel aparece assim que o app sobe.
    func start() {
        guard !didStart else { return }
        didStart = true

        registerHotkeys()
        observeOtherAppsActivating()
        showLauncher()
    }

    /// O launcher some quando **outro app** assume o primeiro plano (PRD §4.3).
    /// O editor fica: ele pode ter texto não salvo.
    ///
    /// Escutar "outro app ativou" em vez de "este app desativou" é o que torna isso
    /// confiável: trocar a política de ativação faz o Promptbox piscar inativo, e
    /// reagir a esse piscar escondia o painel que tinha acabado de abrir.
    private func observeOtherAppsActivating() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Só o identificador atravessa para a main actor: `Notification` e
            // `NSRunningApplication` não são `Sendable`.
            let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleIdentifier = activated?.bundleIdentifier

            MainActor.assumeIsolated {
                guard bundleIdentifier != Bundle.main.bundleIdentifier else { return }
                self?.hideLauncher()
            }
        }
    }

    // MARK: - Navegação

    func toggleLauncher() {
        // A decisão vem do painel, não de um espelho de estado: o macOS pode
        // ordenar a janela para fora sem passar por `hideLauncher()`.
        launcherPanel?.isVisible == true ? hideLauncher() : showLauncher()
    }

    func showLauncher() {
        // Precisa vir antes de o painel ativar o Promptbox (PRD §36).
        inserter.captureFrontmostApp()

        // A política vem antes de exibir: um app `.accessory` não consegue se
        // ativar, e trocar depois faria o painel aparecer sem o teclado.
        activation.panelDidShow(PanelID.launcher)
        launcher.show()
    }

    func hideLauncher() {
        guard let launcherPanel, launcherPanel.isVisible else { return }

        // Fechar zera a busca: reabrir mostra os recentes, não o último termo
        // digitado (PRD §9).
        launcherModel.reset()
        launcherPanel.hide()
        activation.panelDidHide(PanelID.launcher)
    }

    /// Com `prompt`, abre em modo edição reaproveitando o mesmo componente (PRD §15).
    func showEditor(editing prompt: Prompt? = nil) {
        editorOrigin = launcherPanel?.isVisible == true ? .launcher : .standalone

        editorModel.load(prompt)
        hideLauncher()

        activation.panelDidShow(PanelID.editor)
        editor.show()
    }

    private func closeEditor() {
        editorPanel?.hide()
        activation.panelDidHide(PanelID.editor)

        // Voltar para o launcher só faz sentido se foi de lá que o editor veio.
        // Aberto pelo ⇧⌘P dentro do terminal, fechar não deve abrir nada.
        if editorOrigin == .launcher {
            showLauncher()
        }
    }

    private func confirmDelete(_ prompt: Prompt, closingEditor: Bool = false) {
        guard Dialogs.confirmDelete(of: prompt.title) else { return }

        store.delete(prompt)
        launcherModel.clampSelection()

        if closingEditor {
            closeEditor()
        }
    }

    // MARK: - Atalhos globais (PRD §35)

    private func registerHotkeys() {
        launcherHotkey = makeLauncherHotkey()
        isLauncherHotkeyActive = launcherHotkey != nil

        editorHotkey = GlobalHotkey(
            keyCode: Hotkey.editorKey,
            modifiers: Hotkey.editorModifiers
        ) { [weak self] in
            self?.showEditor()
        }

        if editorHotkey == nil {
            Log.hotkey.warning("⇧⌘P já está em uso por outro app.")
        }

        guard launcherHotkey == nil else { return }

        // Uma execução anterior recém-encerrada pode ainda estar segurando a
        // combinação; vale uma segunda tentativa antes de desistir.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, self.launcherHotkey == nil else { return }

            self.launcherHotkey = self.makeLauncherHotkey()
            self.isLauncherHotkeyActive = self.launcherHotkey != nil

            if self.launcherHotkey == nil {
                Log.hotkey.warning("⌥Space já está em uso por outro app.")
            }
        }
    }

    private func makeLauncherHotkey() -> GlobalHotkey? {
        GlobalHotkey(
            keyCode: Hotkey.launcherKey,
            modifiers: Hotkey.launcherModifiers
        ) { [weak self] in
            self?.toggleLauncher()
        }
    }

    // MARK: - Modelos

    private lazy var launcherModel: LauncherViewModel = {
        let model = LauncherViewModel(store: store)
        model.delegate = self
        return model
    }()

    private lazy var editorModel: PromptEditorViewModel = {
        let model = PromptEditorViewModel()
        model.delegate = self
        return model
    }()

    // MARK: - Painéis

    private var launcher: FloatingPanelController {
        if let launcherPanel { return launcherPanel }

        let model = launcherModel
        let panel = FloatingPanelController(
            identifier: PanelID.launcher,
            width: Metrics.launcherWidth,
            onCancel: { [weak self] in self?.hideLauncher() },
            keyHandler: { model.handle($0) }
        ) {
            LauncherView(model: model)
        }

        launcherPanel = panel
        return panel
    }

    private var editor: FloatingPanelController {
        if let editorPanel { return editorPanel }

        let model = editorModel
        let panel = FloatingPanelController(
            identifier: PanelID.editor,
            width: Metrics.editorWidth,
            onCancel: { [weak self] in self?.editorModel.cancel() },
            keyHandler: { model.handle($0) }
        ) {
            PromptEditorView(model: model)
        }

        editorPanel = panel
        return panel
    }
}

// MARK: - Launcher

extension AppCoordinator: LauncherViewModelDelegate {

    func launcherDidInsert(_ prompt: Prompt, mode: InsertMode) {
        store.markUsed(prompt)

        guard inserter.insert(prompt, mode: mode) == .permissionRequired else { return }

        // Deixa o painel fechar antes do alerta modal aparecer.
        Task { @MainActor in
            Dialogs.requestAccessibilityPermission()
        }
    }

    func launcherDidRequestNewPrompt() {
        showEditor()
    }

    func launcherDidRequestEdit(_ prompt: Prompt) {
        showEditor(editing: prompt)
    }

    func launcherDidRequestDelete(_ prompt: Prompt) {
        confirmDelete(prompt)
    }

    func launcherDidRequestClose() {
        hideLauncher()
    }
}

// MARK: - Editor

extension AppCoordinator: PromptEditorViewModelDelegate {

    func editorDidSave(_ prompt: Prompt) {
        store.save(prompt)
        closeEditor()
    }

    func editorDidCancel() {
        closeEditor()
    }

    func editorDidRequestDelete(_ prompt: Prompt) {
        confirmDelete(prompt, closingEditor: true)
    }
}
