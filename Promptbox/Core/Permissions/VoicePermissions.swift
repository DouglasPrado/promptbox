import AVFoundation
import Speech

/// Permissões que o Voice Insert precisa antes de gravar
/// (VOICE-INSERT §Permissões).
///
/// A de Acessibilidade não entra aqui: ela é da inserção, não da captura, e já
/// tem dono em `PromptInserter`.
enum VoicePermission: Equatable {
    case microphone
    case speechRecognition
}

/// Um protocolo para que o view model possa ser testado sem tocar no TCC — pedir
/// microfone de verdade abriria um diálogo do sistema no meio da suíte.
@MainActor
protocol VoicePermissions {
    func authorize(_ permission: VoicePermission) async -> Bool
}

/// O caminho real: pergunta ao sistema e, na primeira vez, ao usuário.
@MainActor
struct SystemVoicePermissions: VoicePermissions {

    func authorize(_ permission: VoicePermission) async -> Bool {
        switch permission {
        case .microphone: await microphone()
        case .speechRecognition: await speechRecognition()
        }
    }

    nonisolated private func microphone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            true
        case .notDetermined:
            await AVCaptureDevice.requestAccess(for: .audio)
        default:
            // Negado ou restrito: pedir de novo não abre nada, só o painel de
            // Ajustes resolve.
            false
        }
    }

    /// `nonisolated` e com o closure marcado `@Sendable` de propósito.
    ///
    /// `requestAuthorization` responde numa fila de background. Dentro de um tipo
    /// isolado na main actor, o Swift isola o closure junto — e aí a chamada vinda
    /// do TCC bate na checagem de executor e o app aborta em tempo de execução,
    /// sem nenhum aviso em tempo de compilação. Custou um crash para aparecer.
    nonisolated private func speechRecognition() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            true
        case .notDetermined:
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { @Sendable status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default:
            false
        }
    }
}
