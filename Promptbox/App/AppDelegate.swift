import AppKit

/// Ciclo de vida do processo. Tudo que é decisão de produto mora no coordinator.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Sem ícone no Dock: o Promptbox roda em background, com a barra de
        // menus como porta de entrada (PRD §42).
        NSApp.setActivationPolicy(.accessory)

        // Sob teste o app é apenas o host do bundle: abrir painel e registrar
        // hotkey global atrapalharia quem está rodando a suíte (e a CI).
        guard !Self.isRunningTests else { return }

        coordinator.start()
    }

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
    }

    func applicationDidResignActive(_ notification: Notification) {
        coordinator.appDidResignActive()
    }

    /// Abrir o app de novo (Finder, Spotlight) reabre o launcher em vez de não
    /// fazer nada.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator.showLauncher()
        return true
    }

    /// O painel não é uma janela comum: fechá-lo não encerra o app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
