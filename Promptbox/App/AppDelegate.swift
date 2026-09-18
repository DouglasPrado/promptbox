import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    let environment = AppEnvironment()

    private var launcherHotkey: GlobalHotkey?
    private var editorHotkey: GlobalHotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Sem ícone no Dock: o Promptbox roda em background, com a barra de
        // menus como porta de entrada (PRD §42).
        NSApp.setActivationPolicy(.accessory)
        registerHotkeys()
        environment.bootstrap()
    }

    /// ⌥Space abre a busca, ⇧⌘P abre o editor (PRD §35). Se a combinação já
    /// estiver tomada por outro app, o registro falha e resta a barra de menus.
    private func registerHotkeys() {
        launcherHotkey = GlobalHotkey(
            keyCode: Hotkey.launcherKey,
            modifiers: Hotkey.launcherModifiers
        ) { [weak self] in
            self?.environment.toggleLauncher()
        }

        environment.isLauncherHotkeyActive = launcherHotkey != nil

        editorHotkey = GlobalHotkey(
            keyCode: Hotkey.editorKey,
            modifiers: Hotkey.editorModifiers
        ) { [weak self] in
            self?.environment.showEditor()
        }

        guard launcherHotkey == nil else { return }

        // Uma execução anterior recém-encerrada pode ainda estar segurando a
        // combinação; vale uma segunda tentativa antes de desistir.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, self.launcherHotkey == nil else { return }

            self.launcherHotkey = GlobalHotkey(
                keyCode: Hotkey.launcherKey,
                modifiers: Hotkey.launcherModifiers
            ) { [weak self] in
                self?.environment.toggleLauncher()
            }

            self.environment.isLauncherHotkeyActive = self.launcherHotkey != nil
            if self.launcherHotkey == nil {
                NSLog("[Promptbox] ⌥Space já está em uso por outro app.")
            }
        }
    }

    /// Abrir o app de novo (Finder, Spotlight) reabre o launcher, em vez de não
    /// fazer nada. A hotkey global ⌥Space ainda é Fase 3 (PRD §35).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        environment.showLauncher()
        return true
    }

    /// O painel não é uma janela comum: fechá-lo não encerra o app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
