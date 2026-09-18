import Foundation
import OSLog

/// Logging do app. Conteúdo e título de prompt são dados do usuário: quando
/// precisam aparecer, vão como `.private`, que o sistema mascara fora do Xcode.
enum Log {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.oialbert.promptbox"

    static let store = Logger(subsystem: subsystem, category: "store")
    static let insertion = Logger(subsystem: subsystem, category: "insertion")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let loginItem = Logger(subsystem: subsystem, category: "login-item")
}
