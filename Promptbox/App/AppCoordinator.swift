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
    private var voicePanel: FloatingPanelController?

    private var focusObserver: NSObjectProtocol?
    private var launcherHotkey: GlobalHotkey?
    private var editorHotkey: GlobalHotkey?
    private var voiceHotkey: GlobalHotkey?
    private var didStart = false

    /// De onde o editor foi aberto, para saber ao que voltar quando fechar.
    private enum EditorOrigin {
        case launcher
        case standalone
    }

    private var editorOrigin: EditorOrigin = .standalone


    /// Estado da permissão de Acessibilidade, exposto no menu para que a resposta
    /// venha do app e não de uma leitura do painel de Ajustes — os dois divergem
    /// quando a autorização aponta para um binário anterior.
    var hasInsertionPermission: Bool { inserter.hasPermission }

    func requestInsertionPermission() {
        Dialogs.requestAccessibilityPermission()
    }

    /// Falso quando ⌥Space já pertence a outro app — o menu avisa em vez de
    /// deixar o usuário achar que a hotkey existe.
    private(set) var isLauncherHotkeyActive = true

    /// O mesmo para ⌥V (VOICE-INSERT §Atalhos).
    private(set) var isVoiceHotkeyActive = true

    init(store: PromptStore = PromptStore(), inserter: PromptInserter = PromptInserter()) {
        self.store = store
        self.inserter = inserter
    }

    /// Abrir o Promptbox é abrir a busca: o painel aparece assim que o app sobe.
    func start() {
        guard !didStart else { return }
        didStart = true

        registerHotkeys()
        observePanelsLosingFocus()
        showLauncher()
    }

    /// O launcher some quando deixa de ser a janela com o foco de teclado (PRD §4.3).
    ///
    /// Esse é o sinal que descreve a intenção do usuário. Duas alternativas foram
    /// testadas e falharam: reagir a `applicationDidResignActive` escondia o painel
    /// no piscar da troca de política de ativação, e reagir à ativação de outro app
    /// o fechava sozinho sempre que o Promptbox não conseguia segurar o primeiro
    /// plano — o painel abria e sumia em menos de um segundo.
    ///
    /// Se o painel nunca chega a receber o foco, ele também não o perde, e fica
    /// aberto até ESC ou ⌥Space. É o comportamento menos surpreendente dos três.
    ///
    /// O overlay de voz segue a mesma regra, por um motivo mais duro: sem foco de
    /// teclado não chegam nem ⌃↵ nem Esc, e a gravação ficaria presa até o limite
    /// de cinco minutos. Perder o foco vira cancelamento — mas só enquanto grava,
    /// nunca depois do ⌃↵ (ver `cancelIfRecording`).
    private func observePanelsLosingFocus() {
        focusObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let panel = notification.object as? FloatingPanel

            MainActor.assumeIsolated {
                // Um alerta modal do próprio app também tira o foco do painel;
                // nesse caso quem decide o que fechar é o fluxo do alerta.
                guard NSApp.modalWindow == nil else { return }

                switch panel?.identifier?.rawValue {
                case PanelID.launcher: self?.hideLauncher()
                case PanelID.voice: self?.voiceModel.cancelIfRecording()
                default: break
                }
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

    // MARK: - Voice Insert (VOICE-INSERT)

    /// ⌥V grava; ⌥V de novo cancela.
    ///
    /// O documento só prevê ⌥V para começar, mas o overlay é um painel não-ativante:
    /// se ele nunca virar a janela com o foco de teclado, nem ⌃↵ nem Esc chegam.
    /// Repetir a hotkey é a saída que sempre funciona, porque ela não depende de foco.
    func toggleVoiceInsert() {
        guard !voiceModel.isActive else {
            voiceModel.cancel()
            return
        }

        // Mesma regra do launcher: registrar o destino antes de o Promptbox tomar
        // o primeiro plano (PRD §36, VOICE-INSERT §Contexto do destino).
        inserter.captureFrontmostApp()

        Task { @MainActor [weak self] in
            guard let self else { return }

            // O overlay só aparece quando há o que mostrar. Na primeira execução o
            // sistema pede microfone e fala antes disso, e um overlay vazio atrás
            // do diálogo de permissão seria ruído.
            guard await self.voiceModel.begin() else { return }

            self.activation.panelDidShow(PanelID.voice)
            self.voice.show()
        }
    }

    private func hideVoiceInsert() {
        guard let voicePanel, voicePanel.isVisible else { return }

        voicePanel.hide()
        activation.panelDidHide(PanelID.voice)
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

        voiceHotkey = GlobalHotkey(
            keyCode: Hotkey.voiceKey,
            modifiers: Hotkey.voiceModifiers
        ) { [weak self] in
            self?.toggleVoiceInsert()
        }

        isVoiceHotkeyActive = voiceHotkey != nil

        if voiceHotkey == nil {
            Log.hotkey.warning("⌥V já está em uso por outro app.")
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

    private lazy var voiceModel: VoiceInsertViewModel = {
        let model = VoiceInsertViewModel()
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

    private var voice: FloatingPanelController {
        if let voicePanel { return voicePanel }

        let model = voiceModel
        let panel = FloatingPanelController(
            identifier: PanelID.voice,
            width: Metrics.voiceOverlayWidth,
            // Junto à base: o overlay avisa, não pede atenção, e não deve cobrir
            // o que o usuário está lendo enquanto fala (VOICE-INSERT §Interface).
            placement: .aboveBottom(inset: Metrics.voiceOverlayBottomInset),
            onCancel: { [weak self] in self?.voiceModel.cancel() },
            keyHandler: { model.handle($0) }
        ) {
            VoiceOverlayView(model: model)
        }

        voicePanel = panel
        return panel
    }
}

// MARK: - Voice Insert

extension AppCoordinator: VoiceInsertViewModelDelegate {

    func voiceInsertDidTranscribe(_ text: String, mode: InsertMode) {
        guard inserter.insert(text: text, mode: mode) == .permissionRequired else { return }

        // Deixa o overlay fechar antes do alerta modal aparecer.
        Task { @MainActor in
            Dialogs.requestAccessibilityPermission()
        }
    }

    func voiceInsertDidRequestClose() {
        hideVoiceInsert()
    }

    func voiceInsertDidRequirePermission(_ permission: VoicePermission) {
        hideVoiceInsert()
        Dialogs.requestVoicePermission(permission)
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
