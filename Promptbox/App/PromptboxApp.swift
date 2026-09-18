import SwiftUI

@main
struct PromptboxApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var launchAtLogin = false

    var body: some Scene {
        // O Promptbox vive na barra de menus (PRD §42). Não há janela principal:
        // a interface é o painel flutuante, criado em AppKit.
        MenuBarExtra {
            Button(appDelegate.environment.isLauncherHotkeyActive ? "Buscar Prompt  ⌥Space" : "Buscar Prompt  (⌥Space em uso por outro app)") {
                appDelegate.environment.toggleLauncher()
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Novo Prompt") {
                appDelegate.environment.showEditor()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Divider()

            Toggle("Abrir ao iniciar o Mac", isOn: launchAtLoginBinding)

            Divider()

            Button("Sair do Promptbox") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            // Imagem em modo template: o macOS inverte a cor conforme a barra
            // de menus clara ou escura.
            Image(.menuBarIcon)
        }
        .menuBarExtraStyle(.menu)
    }

    /// Lê o estado real do sistema a cada avaliação: o usuário pode desligar o
    /// item de login pelos Ajustes, sem passar por aqui.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LoginItem.isEnabled },
            set: { launchAtLogin = LoginItem.setEnabled($0) }
        )
    }
}
