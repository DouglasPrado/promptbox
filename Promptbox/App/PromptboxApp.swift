import SwiftUI

@main
struct PromptboxApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // O Promptbox vive na barra de menus (PRD §42). Não há janela principal:
        // a interface é o painel flutuante, criado em AppKit.
        MenuBarExtra {
            Button(searchTitle) {
                appDelegate.coordinator.toggleLauncher()
            }
            .keyboardShortcut("k", modifiers: .command)

            Button(Strings.Menu.newPrompt) {
                appDelegate.coordinator.showEditor()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Divider()

            Toggle(Strings.Menu.launchAtLogin, isOn: launchAtLogin)

            Divider()

            Button(Strings.Menu.quit) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            // Imagem em modo template: o macOS inverte a cor conforme a barra de
            // menus clara ou escura.
            Image(.menuBarIcon)
        }
        .menuBarExtraStyle(.menu)
    }

    private var searchTitle: String {
        appDelegate.coordinator.isLauncherHotkeyActive
            ? Strings.Menu.search
            : Strings.Menu.searchHotkeyTaken
    }

    /// Lê o estado real do sistema: o usuário pode desligar o item de login pelos
    /// Ajustes, sem passar por aqui.
    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { LoginItem.isEnabled },
            set: { LoginItem.setEnabled($0) }
        )
    }
}
