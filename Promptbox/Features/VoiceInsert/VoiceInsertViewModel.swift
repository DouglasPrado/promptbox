import Foundation

/// Quem recebe as intenções do Voice Insert. Mesmo contrato por protocolo do
/// launcher e do editor: esquecer de ligar uma ação vira erro de compilação.
@MainActor
protocol VoiceInsertViewModelDelegate: AnyObject {
    /// Transcrição final, pronta para o app que estava em foco.
    func voiceInsertDidTranscribe(_ text: String, mode: InsertMode)
    /// Fecha o overlay.
    func voiceInsertDidRequestClose()
    /// Falta uma permissão. Quem coordena decide como pedir.
    func voiceInsertDidRequirePermission(_ permission: VoicePermission)
}

/// Estados do Voice Insert (VOICE-INSERT §Estados).
///
/// `completed` e `cancelled` do documento ficaram de fora: os dois são o mesmo
/// instante em que o overlay fecha e tudo volta a `idle`, e um estado que
/// ninguém chega a observar só engorda o `switch` da view. O resultado de cada
/// sessão já está no delegate.
enum VoiceInsertState: Equatable {
    case idle
    case requestingPermission
    case recording
    case finalizing
    case inserting
    case failed(VoiceInsertFailure)
}

/// O erro é do tamanho da mensagem que ele vira na tela — é para isso que existe.
///
/// Um `Error` concreto em vez do `any Error` do documento deixa o estado
/// `Equatable`, e é o que permite testar a máquina de estados por igualdade.
enum VoiceInsertFailure: Equatable {
    /// Gravou, mas ninguém falou. Não existe inserção de texto vazio.
    case noSpeech
    /// A transcrição não aconteceu.
    case transcription
}

@MainActor
@Observable
final class VoiceInsertViewModel {

    /// Ditado rápido, não gravação longa (VOICE-INSERT §Duração máxima).
    static let maximumSeconds = 5 * 60

    /// Quantas barras a waveform mostra.
    static let waveformBars = 22

    /// Um bloco do microfone a cada ~23 ms. Virar barra a cada quatro dá ~10 Hz:
    /// o olho não vê diferença e a interface redesenha quatro vezes menos.
    private static let buffersPerBar = 4

    /// Quanto o erro fica na tela antes de sumir sozinho. É um aviso, não um
    /// diálogo: não exige clique.
    private static let failureDismissal = Duration.milliseconds(2500)

    private(set) var state: VoiceInsertState = .idle

    /// Última hipótese do reconhecedor. Só feedback visual — nunca é inserida
    /// (VOICE-INSERT §Transcrição parcial).
    private(set) var partial = ""

    /// Níveis recentes do microfone, do mais antigo ao mais novo.
    private(set) var levels: [Float] = []

    private(set) var elapsedSeconds = 0

    weak var delegate: VoiceInsertViewModelDelegate?

    private let provider: TranscriptionProvider
    private let permissions: VoicePermissions

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var meter: Task<Void, Never>?
    @ObservationIgnored private var dismissal: Task<Void, Never>?
    @ObservationIgnored private var peak: Float = 0
    @ObservationIgnored private var buffersSinceBar = 0

    init(
        provider: TranscriptionProvider = AppleSpeechProvider(),
        permissions: VoicePermissions = SystemVoicePermissions()
    ) {
        self.provider = provider
        self.permissions = permissions
    }

    // MARK: - Estado derivado

    var isActive: Bool { state != .idle }

    var isRecording: Bool { state == .recording }

    var timeLabel: String { Self.timeLabel(seconds: elapsedSeconds) }

    /// `0:08`, como no mockup: sem zero à esquerda no minuto.
    static func timeLabel(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Sessão

    /// Resolve as permissões e começa a ouvir.
    ///
    /// Devolve se há algo para mostrar — gravando, ou o erro que impediu isso.
    /// Falta de permissão devolve `false`: quem assume é o alerta do sistema, e
    /// um overlay vazio atrás dele seria só ruído.
    @discardableResult
    func begin() async -> Bool {
        guard state == .idle else { return false }

        state = .requestingPermission

        for permission in [VoicePermission.microphone, .speechRecognition] {
            guard await permissions.authorize(permission) else {
                state = .idle
                delegate?.voiceInsertDidRequirePermission(permission)
                return false
            }
        }

        partial = ""
        levels = []
        elapsedSeconds = 0
        peak = 0
        buffersSinceBar = 0

        provider.onPartialResult = { [weak self] text in
            self?.partial = text
        }

        let stream: AsyncStream<Float>
        do {
            stream = try await provider.start()
        } catch {
            Log.voice.error("Não foi possível começar a gravar: \(String(describing: error), privacy: .public)")
            fail(.transcription)
            return true
        }

        // Abrir o microfone pode levar segundos, e nesse intervalo um segundo ⌥V
        // já pode ter encerrado a sessão. Sem esta guarda ela renasceria aqui,
        // gravando com o overlay fechado.
        guard state == .requestingPermission else {
            provider.cancel()
            return false
        }

        state = .recording

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tock()
            }
        }

        meter = Task { [weak self] in
            for await level in stream {
                self?.append(level)
            }
        }

        return true
    }

    /// `⌃↵`: encerra a fala e entrega o texto (VOICE-INSERT §Atalhos).
    func confirm(mode: InsertMode) async {
        guard state == .recording else { return }

        state = .finalizing
        stopTimers()

        let text: String
        do {
            text = try await provider.finish()
        } catch {
            guard state == .finalizing else { return }

            Log.voice.error("Transcrição falhou: \(String(describing: error), privacy: .public)")
            fail(.transcription)
            return
        }

        // Esperar o resultado final leva até alguns segundos, e nesse intervalo
        // o Esc (ou o overlay perdendo o foco) pode ter encerrado a sessão. O que
        // o reconhecedor devolve depois disso não é mais de ninguém: mostrar um
        // erro agora faria o overlay voltar sozinho, já cancelado.
        guard state == .finalizing else { return }

        let transcription = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcription.isEmpty else {
            fail(.noSpeech)
            return
        }

        state = .inserting
        Log.voice.notice("Transcrição pronta: \(transcription.count) caracteres.")

        // Fechar vem primeiro, como no launcher: a inserção devolve o foco ao
        // app anterior, e isso é mais confiável com o overlay já fora da tela.
        reset()
        delegate?.voiceInsertDidRequestClose()
        delegate?.voiceInsertDidTranscribe(transcription, mode: mode)
    }

    /// Cancela só enquanto está gravando.
    ///
    /// É o que o overlay deve fazer ao perder o foco de teclado: sem ⌃↵ e sem Esc
    /// a gravação não teria saída. Depois do ⌃↵, não — o usuário já pediu o
    /// texto, e jogá-lo fora porque a janela perdeu o foco seria trair o pedido.
    /// Foi assim que uma transcrição sumiu em teste: o overlay fechava durante
    /// "Transcrevendo...", sem erro e sem inserir nada.
    func cancelIfRecording() {
        guard state == .recording else { return }
        cancel()
    }

    /// `Esc`: para, descarta e fecha. Não pergunta, não salva rascunho, não
    /// toca no clipboard (VOICE-INSERT §Comportamento do Esc).
    func cancel() {
        guard isActive else { return }

        provider.cancel()
        reset()
        delegate?.voiceInsertDidRequestClose()
    }

    /// Um segundo passou.
    ///
    /// Separado do laço para que o limite de duração possa ser verificado sem
    /// esperar cinco minutos de relógio.
    func tock() {
        guard state == .recording else { return }

        elapsedSeconds += 1
        guard elapsedSeconds >= Self.maximumSeconds else { return }

        // No limite, o ⌃↵ acontece sozinho: o que foi dito é inserido, nunca
        // enviado. Descartar cinco minutos de fala seria pior.
        Log.voice.notice("Duração máxima atingida; encerrando a gravação.")
        Task { [weak self] in await self?.confirm(mode: .insert) }
    }

    // MARK: - Teclado

    /// Chamado pelo painel antes de qualquer view ver o evento.
    func handle(_ key: KeyStroke) -> Bool {
        switch key.code {
        case KeyCode.escape:
            cancel()
            return true

        case KeyCode.returnKey:
            // Enter sozinho não faz nada: o overlay não é campo de texto, e
            // consumir o Enter puro esconderia um atalho digitado errado.
            guard key.hasControl else { return false }

            let mode: InsertMode = key.hasShift ? .insertAndSend : .insert
            Task { [weak self] in await self?.confirm(mode: mode) }
            return true

        default:
            return false
        }
    }

    // MARK: - Waveform

    private func append(_ level: Float) {
        peak = max(peak, level)
        buffersSinceBar += 1

        guard buffersSinceBar >= Self.buffersPerBar else { return }

        // O pico do grupo, não a média: é o que preserva a impressão de volume.
        levels.append(peak)
        if levels.count > Self.waveformBars {
            levels.removeFirst(levels.count - Self.waveformBars)
        }

        peak = 0
        buffersSinceBar = 0
    }

    // MARK: - Encerramento

    private func fail(_ failure: VoiceInsertFailure) {
        stopTimers()
        provider.cancel()

        state = .failed(failure)
        partial = ""
        levels = []

        dismissal = Task { [weak self] in
            try? await Task.sleep(for: Self.failureDismissal)
            guard !Task.isCancelled else { return }

            self?.reset()
            self?.delegate?.voiceInsertDidRequestClose()
        }
    }

    private func stopTimers() {
        ticker?.cancel()
        ticker = nil
        meter?.cancel()
        meter = nil
    }

    private func reset() {
        stopTimers()
        dismissal?.cancel()
        dismissal = nil

        provider.onPartialResult = nil

        state = .idle
        partial = ""
        levels = []
        elapsedSeconds = 0
        peak = 0
        buffersSinceBar = 0
    }
}
