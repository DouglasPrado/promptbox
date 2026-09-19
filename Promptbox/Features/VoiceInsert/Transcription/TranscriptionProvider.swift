import Foundation

/// Motor de reconhecimento de fala, atrás de um contrato mínimo
/// (VOICE-INSERT §Provider de transcrição).
///
/// Trocar Apple Speech por Whisper local ou por um serviço em nuvem não deve
/// mexer na UX: o overlay, os atalhos e a inserção falam só com este protocolo.
@MainActor
protocol TranscriptionProvider: AnyObject {

    /// Hipóteses parciais, para feedback visual.
    ///
    /// O reconhecedor corrige o que já disse, então parcial nunca é inserido —
    /// só o resultado de `finish()` chega ao app de destino
    /// (VOICE-INSERT §Transcrição parcial).
    var onPartialResult: ((String) -> Void)? { get set }

    /// Começa a ouvir. Devolve o nível de entrada (0…1) para a waveform.
    func start() async throws -> AsyncStream<Float>

    /// Encerra a captura e devolve a transcrição final, que pode ser vazia
    /// quando ninguém falou.
    ///
    /// Chamado `finish` e não `stop` porque existe ao lado de `cancel()`:
    /// encerrar e descartar são caminhos diferentes, e um nome ambíguo entre os
    /// dois convida ao engano.
    func finish() async throws -> String

    /// Para tudo e descarta. Não lança: cancelar é a saída de quando algo já
    /// deu errado.
    func cancel()
}

/// Por que uma transcrição não aconteceu.
enum TranscriptionFailure: Error, Equatable {
    /// Nenhum reconhecedor para o idioma pedido, ou indisponível agora.
    case recognizerUnavailable
    /// O microfone não pôde ser aberto.
    case audioUnavailable
    /// O reconhecedor falhou sem produzir texto algum.
    case recognitionFailed
}
