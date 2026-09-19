import Foundation
import Testing

@testable import Promptbox

@MainActor
@Suite("VoiceInsertViewModel")
struct VoiceInsertViewModelTests {

    // MARK: - Sessão

    @Test("Começar a gravar exige microfone e reconhecimento de fala")
    func beginRequiresBothPermissions() async {
        for denied in [VoicePermission.microphone, .speechRecognition] {
            let (model, provider, delegate) = make(denying: denied)

            #expect(await model.begin() == false)
            #expect(delegate.requiredPermission == denied)
            #expect(model.state == .idle)
            #expect(provider.didStart == false)
        }
    }

    @Test("Permissão negada não mostra overlay nem grava")
    func deniedPermissionKeepsOverlayClosed() async {
        let (model, _, delegate) = make(denying: .microphone)

        #expect(await model.begin() == false)
        #expect(delegate.closed == false)
        #expect(model.isActive == false)
    }

    @Test("Com permissão, o modelo fica gravando")
    func beginStartsRecording() async {
        let (model, provider, _) = make()

        #expect(await model.begin())
        #expect(model.state == .recording)
        #expect(provider.didStart)
    }

    @Test("⌥V duas vezes não reinicia a sessão")
    func beginIsIgnoredWhileActive() async {
        let (model, provider, _) = make()

        #expect(await model.begin())
        #expect(await model.begin() == false)
        #expect(provider.startCount == 1)
    }

    // MARK: - Confirmação

    @Test("⌃↵ insere; ⌃⇧↵ insere e envia")
    func controlReturnInserts() async {
        for (shift, expected) in [(false, InsertMode.insert), (true, .insertAndSend)] {
            let (model, provider, delegate) = make()
            provider.transcription = "revise a implementação"
            #expect(await model.begin())

            await model.confirm(mode: shift ? .insertAndSend : .insert)

            #expect(delegate.transcribed?.text == "revise a implementação")
            #expect(delegate.transcribed?.mode == expected)
            #expect(provider.didFinish)
        }
    }

    @Test("O overlay fecha antes de o texto ser entregue")
    func overlayClosesBeforeInsertion() async {
        let (model, provider, delegate) = make()
        provider.transcription = "olá"
        #expect(await model.begin())

        await model.confirm(mode: .insert)

        // A inserção devolve o foco ao app anterior, e isso é mais confiável com
        // o overlay já fora da tela — a ordem é parte do contrato.
        #expect(delegate.events == [.closed, .transcribed])
        #expect(model.state == .idle)
    }

    @Test("Espaço em volta da transcrição é aparado")
    func transcriptionIsTrimmed() async {
        let (model, provider, delegate) = make()
        provider.transcription = "  criar um teste \n"
        #expect(await model.begin())

        await model.confirm(mode: .insert)

        #expect(delegate.transcribed?.text == "criar um teste")
    }

    @Test("Silêncio não vira inserção de texto vazio")
    func silenceDoesNotInsert() async {
        let (model, provider, delegate) = make()
        provider.transcription = "   "
        #expect(await model.begin())

        await model.confirm(mode: .insert)

        #expect(delegate.transcribed == nil)
        #expect(model.state == .failed(.noSpeech))
    }

    @Test("Falha do reconhecedor vira estado de erro, não inserção")
    func recognitionFailureShowsError() async {
        let (model, provider, delegate) = make()
        provider.finishFailure = TranscriptionFailure.recognitionFailed
        #expect(await model.begin())

        await model.confirm(mode: .insert)

        #expect(delegate.transcribed == nil)
        #expect(model.state == .failed(.transcription))
        #expect(provider.didCancel)
    }

    @Test("Falha ao abrir o microfone mostra o erro em vez de não abrir nada")
    func startFailureShowsOverlay() async {
        let (model, provider, delegate) = make()
        provider.startFailure = TranscriptionFailure.audioUnavailable

        #expect(await model.begin())
        #expect(model.state == .failed(.transcription))
        #expect(delegate.transcribed == nil)
    }

    @Test("Confirmar fora da gravação não faz nada")
    func confirmOutsideRecordingIsIgnored() async {
        let (model, _, delegate) = make()

        await model.confirm(mode: .insert)

        #expect(delegate.transcribed == nil)
        #expect(model.state == .idle)
    }

    // MARK: - Cancelamento

    @Test("Esc para, descarta e fecha, sem inserir nada")
    func escapeDiscardsEverything() async {
        let (model, provider, delegate) = make()
        provider.transcription = "isso não deve ser inserido"
        #expect(await model.begin())

        #expect(model.handle(KeyStroke(code: KeyCode.escape)))

        #expect(provider.didCancel)
        #expect(provider.didFinish == false)
        #expect(delegate.transcribed == nil)
        #expect(delegate.closed)
        #expect(model.state == .idle)
    }

    @Test("Esc durante a transcrição não faz o overlay voltar com erro")
    func cancellingWhileFinalizingStaysClosed() async {
        let (model, provider, delegate) = make()
        provider.holdFinish = true
        #expect(await model.begin())

        // ⌃↵ leva a `finalizing`, onde o reconhecedor ainda está respondendo.
        #expect(model.handle(KeyStroke(code: KeyCode.returnKey, modifiers: .control)))
        await until { model.state == .finalizing }

        model.cancel()
        #expect(model.state == .idle)

        // O resultado chega depois do cancelamento e não pode reabrir nada.
        provider.releaseFinish(with: "")
        await until { delegate.events.count > 1 }

        #expect(model.state == .idle)
        #expect(delegate.transcribed == nil)
        #expect(delegate.events == [.closed])
    }

    @Test("Perder o foco durante a transcrição não descarta o texto")
    func losingFocusWhileFinalizingKeepsTheText() async {
        let (model, provider, delegate) = make()
        provider.holdFinish = true
        #expect(await model.begin())

        #expect(model.handle(KeyStroke(code: KeyCode.returnKey, modifiers: .control)))
        await until { model.state == .finalizing }

        // É o que o painel faz ao deixar de ser a janela com o foco de teclado.
        model.cancelIfRecording()
        #expect(model.state == .finalizing)

        provider.releaseFinish(with: "não pode sumir")
        await until { delegate.transcribed != nil }

        #expect(delegate.transcribed?.text == "não pode sumir")
    }

    @Test("Perder o foco durante a gravação cancela")
    func losingFocusWhileRecordingCancels() async {
        let (model, provider, delegate) = make()
        #expect(await model.begin())

        model.cancelIfRecording()

        #expect(provider.didCancel)
        #expect(model.state == .idle)
        #expect(delegate.closed)
    }

    @Test("Cancelar sem sessão ativa não fecha nada")
    func cancelWhileIdleIsIgnored() {
        let (model, provider, delegate) = make()

        model.cancel()

        #expect(provider.didCancel == false)
        #expect(delegate.closed == false)
    }

    // MARK: - Teclado

    @Test("Enter sem ⌃ não é consumido")
    func plainReturnIsNotConsumed() async {
        let (model, _, _) = make()
        #expect(await model.begin())

        #expect(!model.handle(KeyStroke(code: KeyCode.returnKey)))
        #expect(!model.handle(KeyStroke(code: KeyCode.returnKey, modifiers: .command)))
        #expect(model.state == .recording)
    }

    @Test("⌃↵ e Esc são consumidos")
    func voiceShortcutsAreConsumed() async {
        let (model, _, _) = make()
        #expect(await model.begin())

        #expect(model.handle(KeyStroke(code: KeyCode.returnKey, modifiers: .control)))
        #expect(model.handle(KeyStroke(code: KeyCode.escape)))
    }

    @Test("Tecla desconhecida não é consumida")
    func unknownKeyIsNotConsumed() async {
        let (model, _, _) = make()
        #expect(await model.begin())

        #expect(!model.handle(KeyStroke(code: KeyCode.tab)))
    }

    // MARK: - Tempo

    @Test("O timer conta sem zero à esquerda no minuto")
    func timeLabelMatchesMockup() {
        #expect(VoiceInsertViewModel.timeLabel(seconds: 0) == "0:00")
        #expect(VoiceInsertViewModel.timeLabel(seconds: 8) == "0:08")
        #expect(VoiceInsertViewModel.timeLabel(seconds: 65) == "1:05")
        #expect(VoiceInsertViewModel.timeLabel(seconds: 600) == "10:00")
    }

    @Test("No limite de duração a gravação se encerra e insere")
    func maximumDurationFinishesOnItsOwn() async {
        let (model, provider, delegate) = make()
        provider.transcription = "ditado longo"
        #expect(await model.begin())

        for _ in 0..<VoiceInsertViewModel.maximumSeconds {
            model.tock()
        }

        // `tock` dispara a confirmação numa tarefa; esperar o modelo sair de
        // `recording` é o que diz que ela rodou.
        await until { model.state != .recording }

        #expect(delegate.transcribed?.text == "ditado longo")
        #expect(delegate.transcribed?.mode == .insert)
    }

    @Test("O timer não corre fora da gravação")
    func tickOnlyCountsWhileRecording() {
        let (model, _, _) = make()

        model.tock()

        #expect(model.elapsedSeconds == 0)
    }

    // MARK: - Waveform

    @Test("A waveform guarda só as barras que cabem na tela")
    func waveformKeepsRecentLevelsOnly() async {
        let (model, provider, _) = make()
        #expect(await model.begin())

        // Cada barra resume quatro blocos do microfone.
        for _ in 0..<(VoiceInsertViewModel.waveformBars * 8) {
            provider.emit(level: 0.5)
        }

        await until { model.levels.count == VoiceInsertViewModel.waveformBars }
        #expect(model.levels.count == VoiceInsertViewModel.waveformBars)
    }

    @Test("Parciais alimentam o feedback, não a inserção")
    func partialResultsNeverReachTheTarget() async {
        let (model, provider, delegate) = make()
        provider.transcription = "revise a implementação dessa story"
        #expect(await model.begin())

        provider.emit(partial: "revise a")
        #expect(model.partial == "revise a")

        provider.emit(partial: "revise a implementação")
        #expect(model.partial == "revise a implementação")
        #expect(delegate.transcribed == nil)

        await model.confirm(mode: .insert)

        // O reconhecedor corrige hipóteses anteriores: só o final é inserido.
        #expect(delegate.transcribed?.text == "revise a implementação dessa story")
    }

    // MARK: - Apoio

    private func make(
        denying permission: VoicePermission? = nil
    ) -> (VoiceInsertViewModel, TranscriptionProviderStub, VoiceInsertDelegateSpy) {
        let provider = TranscriptionProviderStub()
        let model = VoiceInsertViewModel(
            provider: provider,
            permissions: VoicePermissionsStub(denied: permission)
        )
        let delegate = VoiceInsertDelegateSpy()
        model.delegate = delegate
        return (model, provider, delegate)
    }

    /// Espera uma condição que depende de uma tarefa já enfileirada na main actor.
    ///
    /// `Task.yield()` sozinho não basta: entre o disparo e o efeito há mais de um
    /// salto de ator. Um teto evita que uma regressão vire um teste travado.
    private func until(
        _ condition: () -> Bool,
        attempts: Int = 100
    ) async {
        for _ in 0..<attempts {
            if condition() { return }
            await Task.yield()
        }
    }
}

// MARK: - Dublês

@MainActor
final class TranscriptionProviderStub: TranscriptionProvider {

    var onPartialResult: ((String) -> Void)?

    var transcription = ""
    var startFailure: Error?
    var finishFailure: Error?

    private(set) var startCount = 0
    private(set) var didFinish = false
    private(set) var didCancel = false

    var didStart: Bool { startCount > 0 }

    /// Segura `finish()` até `releaseFinish(with:)`.
    var holdFinish = false

    private var levels: AsyncStream<Float>.Continuation?
    private var held: CheckedContinuation<Void, Never>?

    func start() async throws -> AsyncStream<Float> {
        if let startFailure { throw startFailure }

        startCount += 1
        let (stream, continuation) = AsyncStream<Float>.makeStream()
        levels = continuation
        return stream
    }

    func finish() async throws -> String {
        levels?.finish()

        // Reproduz o intervalo real entre o ⌃↵ e o resultado final, que é onde
        // um Esc pode chegar no meio.
        if holdFinish {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                held = continuation
            }
        }

        if let finishFailure { throw finishFailure }

        didFinish = true
        return transcription
    }

    func cancel() {
        didCancel = true
        levels?.finish()
    }

    func emit(partial: String) { onPartialResult?(partial) }
    func emit(level: Float) { levels?.yield(level) }

    func releaseFinish(with text: String) {
        transcription = text
        held?.resume()
        held = nil
    }
}

@MainActor
struct VoicePermissionsStub: VoicePermissions {

    let denied: VoicePermission?

    func authorize(_ permission: VoicePermission) async -> Bool {
        permission != denied
    }
}

@MainActor
final class VoiceInsertDelegateSpy: VoiceInsertViewModelDelegate {

    enum Event: Equatable {
        case transcribed
        case closed
        case permission
    }

    private(set) var events: [Event] = []
    private(set) var transcribed: (text: String, mode: InsertMode)?
    private(set) var requiredPermission: VoicePermission?

    var closed: Bool { events.contains(.closed) }

    func voiceInsertDidTranscribe(_ text: String, mode: InsertMode) {
        transcribed = (text, mode)
        events.append(.transcribed)
    }

    func voiceInsertDidRequestClose() {
        events.append(.closed)
    }

    func voiceInsertDidRequirePermission(_ permission: VoicePermission) {
        requiredPermission = permission
        events.append(.permission)
    }
}
