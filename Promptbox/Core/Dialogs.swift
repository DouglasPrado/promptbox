import AppKit
import ApplicationServices

/// Diálogos modais do app.
///
/// Ficam reunidos aqui para que serviços (inserção, persistência) não precisem
/// conhecer AppKit nem decidir quando falar com o usuário.
@MainActor
enum Dialogs {

    /// Confirmação de exclusão. Irreversível, então o botão padrão é Cancelar:
    /// um Enter distraído não pode apagar um prompt.
    static func confirmDelete(of promptTitle: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = Strings.DeleteAlert.title(promptTitle)
        alert.informativeText = Strings.DeleteAlert.message
        alert.alertStyle = .warning
        alert.addButton(withTitle: Strings.DeleteAlert.confirm)
        alert.addButton(withTitle: Strings.DeleteAlert.cancel)
        alert.buttons[0].hasDestructiveAction = true
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"

        return alert.runAbovePanels() == .alertFirstButtonReturn
    }

    /// Explica a permissão de Acessibilidade e leva ao painel do sistema (PRD §41).
    static func requestAccessibilityPermission() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = Strings.PermissionAlert.title
        alert.informativeText = Strings.PermissionAlert.message
        alert.alertStyle = .informational
        alert.addButton(withTitle: Strings.PermissionAlert.openSettings)
        alert.addButton(withTitle: Strings.PermissionAlert.later)

        guard alert.runAbovePanels() == .alertFirstButtonReturn else { return }

        // Registra o app na lista de Acessibilidade e abre o painel do sistema.
        // A chave é literal porque `kAXTrustedCheckOptionPrompt` é uma global
        // mutável, rejeitada pelo modo de concorrência do Swift 6.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

        openPrivacySettings("Privacy_Accessibility")
    }

    /// Explica microfone e reconhecimento de fala (VOICE-INSERT §Permissões).
    ///
    /// Separado do alerta de Acessibilidade porque cada permissão abre um painel
    /// diferente dos Ajustes, e mandar o usuário para o painel errado é pior do
    /// que não mandar para lugar nenhum.
    static func requestVoicePermission(_ permission: VoicePermission) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.addButton(withTitle: Strings.VoicePermissionAlert.openSettings)
        alert.addButton(withTitle: Strings.VoicePermissionAlert.later)

        let pane: String

        switch permission {
        case .microphone:
            alert.messageText = Strings.VoicePermissionAlert.microphoneTitle
            alert.informativeText = Strings.VoicePermissionAlert.microphoneMessage
            pane = "Privacy_Microphone"

        case .speechRecognition:
            alert.messageText = Strings.VoicePermissionAlert.speechTitle
            alert.informativeText = Strings.VoicePermissionAlert.speechMessage
            pane = "Privacy_SpeechRecognition"
        }

        guard alert.runAbovePanels() == .alertFirstButtonReturn else { return }
        openPrivacySettings(pane)
    }

    private static func openPrivacySettings(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension NSAlert {

    /// Os painéis do Promptbox ficam em `.floating`; um alerta comum nasce no
    /// nível normal e abriria atrás deles — a confirmação não apareceria.
    func runAbovePanels() -> NSApplication.ModalResponse {
        window.level = .modalPanel
        return runModal()
    }
}
