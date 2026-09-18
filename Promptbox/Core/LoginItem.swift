import Foundation
import ServiceManagement

/// "Abrir Promptbox ao iniciar o Mac" (PRD §43). Desligado por padrão.
@MainActor
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Retorna o estado real depois da tentativa — registrar pode falhar quando o
    /// app roda de um local temporário ou sem assinatura estável.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[Promptbox] Launch at Login falhou: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
