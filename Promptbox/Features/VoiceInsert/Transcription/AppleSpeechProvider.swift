import AVFoundation
import Foundation
import Speech

/// Reconhecimento pelo framework `Speech` da Apple (VOICE-INSERT §Apple Speech).
///
/// É o primeiro provider porque não exige download, não sai do Mac quando o
/// reconhecimento local está disponível e já entende pt-BR.
@MainActor
final class AppleSpeechProvider: TranscriptionProvider {

    var onPartialResult: ((String) -> Void)?

    /// Quanto esperar pelo resultado final depois do `endAudio()`.
    ///
    /// O reconhecedor quase sempre responde em alguns décimos de segundo. Quando
    /// não responde, inserir a última hipótese vale mais do que deixar o overlay
    /// preso esperando um evento que pode não vir.
    private static let finalResultTimeout = Duration.seconds(3)

    private let locale: Locale
    private let recorder = AudioRecorder()

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var sink: Sink?

    /// Última hipótese recebida — é o que `finish()` devolve.
    private var transcript = ""

    private var didFinish = false
    private var didFail = false
    private var isOnDevice = false
    private var didFallBackToServer = false
    private var isFinishing = false

    /// Identifica de qual reconhecedor um resultado veio.
    ///
    /// A queda para o servidor cancela a tarefa local, e o que ela ainda entregar
    /// depois disso não pode encerrar a sessão nova. O mesmo vale entre sessões.
    private var generation = 0
    /// A falha foi apenas silêncio? Muda a mensagem, não o texto inserido.
    private var failureWasSilence = false

    /// Quem espera o resultado final. Carrega `Void` porque o texto sai de
    /// `transcript` — a continuação só diz "pode ler agora".
    private var pendingFinal: CheckedContinuation<Void, Never>?
    private var timeout: Task<Void, Never>?

    init(locale: Locale = Locale(identifier: "pt-BR")) {
        self.locale = locale
    }

    // MARK: - TranscriptionProvider

    func start() async throws -> AsyncStream<Float> {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionFailure.recognizerUnavailable
        }

        reset()
        self.recognizer = recognizer

        // Local quando dá, servidor quando não dá. `supportsOnDeviceRecognition`
        // diz se o modelo do idioma existe, não se ele pode ser usado agora —
        // com o Ditado desligado nos Ajustes ele existe e falha mesmo assim
        // (VOICE-INSERT §Apple Speech).
        isOnDevice = recognizer.supportsOnDeviceRecognition
        let request = makeRequest(onDevice: isOnDevice)
        let sink = Sink(request)

        self.request = request
        self.sink = sink
        listen(to: request, on: recognizer)

        do {
            return try await recorder.start(sink: sink)
        } catch {
            cancel()
            throw TranscriptionFailure.audioUnavailable
        }
    }

    private func makeRequest(onDevice: Bool) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = TechnicalVocabulary.terms
        request.requiresOnDeviceRecognition = onDevice
        return request
    }

    private func listen(to request: SFSpeechAudioBufferRecognitionRequest, on recognizer: SFSpeechRecognizer) {
        let generation = self.generation

        // `@Sendable` não é decoração: o handler vem de uma fila de background e,
        // sem a marcação, o Swift o isolaria nesta main actor e o app abortaria na
        // primeira resposta do reconhecedor — em tempo de execução, sem aviso do
        // compilador. Só valores `Sendable` atravessam, então o resultado vira
        // texto antes do salto de volta.
        task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failure = error.map { Failure($0 as NSError) }

            Task { @MainActor in
                self?.handle(generation: generation, text: text, isFinal: isFinal, failure: failure)
            }
        }
    }

    func finish() async throws -> String {
        guard request != nil else { return transcript }

        // A partir daqui não há mais áudio entrando, então trocar de reconhecedor
        // deixou de fazer sentido: o que vier é o resultado, bom ou ruim.
        isFinishing = true

        // Fechar o sink antes: parar o motor é assíncrono, e um bloco atrasado do
        // microfone chegaria a um pedido já encerrado.
        sink?.close()

        // Sem `endAudio()` o reconhecedor continua esperando mais fala e o
        // resultado final nunca sai.
        request?.endAudio()
        recorder.stop()

        if !didFinish {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                pendingFinal = continuation

                timeout = Task { [weak self] in
                    try? await Task.sleep(for: Self.finalResultTimeout)
                    guard !Task.isCancelled else { return }

                    Log.voice.warning("Resultado final não chegou; usando a última hipótese.")
                    self?.deliverFinal()
                }
            }
        }

        let text = transcript
        let failed = didFail && !failureWasSilence
        teardown()

        // Silêncio não é falha: volta vazio e quem chama mostra "nenhuma fala
        // detectada". Só um erro de verdade, sem nada transcrito, é falha.
        if text.isEmpty, failed {
            throw TranscriptionFailure.recognitionFailed
        }

        return text
    }

    func cancel() {
        sink?.close()
        recorder.stop()
        task?.cancel()
        request?.endAudio()

        // Quem estiver esperando o resultado final não pode ficar suspenso.
        deliverFinal()
        teardown()
        reset()
    }

    // MARK: - Resultado

    private func handle(generation: Int, text: String?, isFinal: Bool, failure: Failure?) {
        guard generation == self.generation else { return }

        if let text, !text.isEmpty {
            transcript = text
            if !isFinal { onPartialResult?(text) }
        }

        if let failure {
            Log.voice.error("Reconhecimento falhou: \(failure.description, privacy: .public)")

            if shouldFallBackToServer(after: failure) {
                fallBackToServer()
                return
            }

            didFail = true
            failureWasSilence = failure == .noSpeechDetected
        }

        guard isFinal || failure != nil else { return }

        didFinish = true
        deliverFinal()
    }

    /// O reconhecimento local falha inteiro e logo no início quando o Ditado está
    /// desligado nos Ajustes — o modelo do idioma está lá, mas não pode ser usado.
    /// Só vale trocar enquanto ainda há áudio entrando e nada foi transcrito.
    private func shouldFallBackToServer(after failure: Failure) -> Bool {
        isOnDevice
            && !didFallBackToServer
            && !isFinishing
            && transcript.isEmpty
            && failure != .noSpeechDetected
    }

    /// Segue a mesma sessão pelo servidor, com o microfone sem parar.
    ///
    /// O que se perde é o trecho entre o ⌥V e a falha — frações de segundo, antes
    /// de o usuário começar a falar. Cair de vez para o erro seria pior: o
    /// documento pede justamente que o app não assuma reconhecimento local.
    private func fallBackToServer() {
        guard let recognizer, let sink else { return }

        didFallBackToServer = true
        isOnDevice = false
        generation += 1
        Log.voice.notice("Reconhecimento local indisponível; seguindo pelo servidor.")

        task?.cancel()

        let request = makeRequest(onDevice: false)
        self.request = request
        sink.replace(with: request)
        listen(to: request, on: recognizer)
    }

    private func deliverFinal() {
        timeout?.cancel()
        timeout = nil

        guard let continuation = pendingFinal else { return }
        pendingFinal = nil
        continuation.resume()
    }

    private func teardown() {
        task = nil
        request = nil
        sink = nil
        recognizer = nil
        onPartialResult = nil
    }

    private func reset() {
        transcript = ""
        didFinish = false
        didFail = false
        failureWasSilence = false
        isOnDevice = false
        didFallBackToServer = false
        isFinishing = false
        generation += 1
    }

    // MARK: - Apoio

    /// Erros que o `Speech` reporta, reduzidos ao que muda a resposta do app.
    private enum Failure: Equatable, Sendable {
        case noSpeechDetected
        /// O reconhecedor local não pôde ser usado. Observado neste Mac com o
        /// Ditado desativado nos Ajustes, mesmo com o modelo pt-BR instalado.
        case localUnavailable
        case other(String)

        /// Os dois casos que mudam a resposta do app chegam como erro, em domínios
        /// privados e sem constante pública. O que sobra é o código observado — e
        /// errar aqui só troca a mensagem exibida, nunca o texto inserido.
        init(_ error: NSError) {
            switch (error.domain, error.code) {
            case ("kAFAssistantErrorDomain", 1110):
                self = .noSpeechDetected
            case ("kLSRErrorDomain", _):
                self = .localUnavailable
            default:
                self = .other("\(error.domain) \(error.code)")
            }
        }

        var description: String {
            switch self {
            case .noSpeechDetected: "nenhuma fala detectada"
            case .localUnavailable: "reconhecimento local indisponível"
            case .other(let detail): detail
            }
        }
    }

    /// Repassa os buffers do microfone ao reconhecedor da vez.
    ///
    /// `SFSpeechAudioBufferRecognitionRequest` não é `Sendable`, mas `append` é
    /// feito para ser chamado da thread de áudio — é o caminho do próprio exemplo
    /// da Apple. O `@unchecked` registra que a garantia vem da API e não do
    /// compilador.
    ///
    /// O destino é trocável porque a queda para o servidor acontece no meio da
    /// sessão. O lock protege essa troca: quem lê é a thread de áudio, quem
    /// escreve é a main actor.
    private final class Sink: AudioBufferSink, @unchecked Sendable {

        private let lock = NSLock()
        private var request: SFSpeechAudioBufferRecognitionRequest?

        init(_ request: SFSpeechAudioBufferRecognitionRequest) {
            self.request = request
        }

        func replace(with request: SFSpeechAudioBufferRecognitionRequest) {
            lock.lock()
            defer { lock.unlock() }
            self.request = request
        }

        /// Depois disso os blocos que ainda estiverem a caminho são descartados.
        func close() {
            lock.lock()
            defer { lock.unlock() }
            request = nil
        }

        func append(_ buffer: AVAudioPCMBuffer) {
            lock.lock()
            let current = request
            lock.unlock()

            current?.append(buffer)
        }
    }
}
