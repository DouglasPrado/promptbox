import AVFoundation

/// Destino dos buffers do microfone.
///
/// É um protocolo `Sendable` em vez de um closure porque o tap do `AVAudioEngine`
/// chama de uma thread de áudio em tempo real: um closure criado na main actor
/// herdaria esse isolamento, e chamá-lo de lá seria corrida.
protocol AudioBufferSink: AnyObject, Sendable {
    func append(_ buffer: AVAudioPCMBuffer)
}

/// Captura do microfone com `AVAudioEngine` (VOICE-INSERT §Stack).
///
/// **Nada aqui pode acontecer na main actor.** `inputFormat(forBus:)` e
/// `engine.start()` fazem `dispatch_sync` para dentro do CoreAudio e ficam
/// presos num `mach_msg` até o `coreaudiod` responder — com um dispositivo
/// agregado, enumerar os sub-dispositivos leva *segundos*. Rodando na main actor
/// isso congela o app inteiro: medido com `sample`, o Promptbox parou de
/// responder até ao ⌥Space do launcher, que não tem nada a ver com voz.
///
/// Por isso todo acesso ao motor passa por `queue`, e é essa serialização que
/// justifica o `@unchecked Sendable`: o estado mutável só é tocado lá dentro.
///
/// O áudio não é acumulado em lugar nenhum: cada bloco vai direto ao reconhecedor
/// e é descartado (VOICE-INSERT §Privacidade).
final class AudioRecorder: @unchecked Sendable {

    enum Failure: Error, Equatable {
        /// Nenhuma entrada utilizável: sem microfone, ou sem permissão — nos dois
        /// casos o `AVAudioEngine` devolve um formato zerado em vez de erro.
        case noInput
        /// O motor de áudio não subiu.
        case engineDidNotStart
    }

    /// 1024 amostras ≈ 23 ms a 44,1 kHz: rápido o bastante para a waveform
    /// parecer contínua, grande o bastante para não sobrecarregar o tap.
    private static let bufferSize = AVAudioFrameCount(1024)

    /// Fila própria, e não a piscina cooperativa: o que roda aqui bloqueia a
    /// thread por tempo indeterminado, e não é isso que se faz com as threads do
    /// Swift Concurrency.
    private let queue = DispatchQueue(label: "com.oialbert.promptbox.audio")

    private let engine = AVAudioEngine()
    private var levels: AsyncStream<Float>.Continuation?
    private var isRunning = false

    /// Começa a capturar. O retorno é o nível de entrada (0…1) por bloco, que a
    /// waveform consome — é o único sinal de que o microfone está mesmo ouvindo.
    func start(sink: any AudioBufferSink) async throws -> AsyncStream<Float> {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                continuation.resume(with: Result { try startOnQueue(sink: sink) })
            }
        }
    }

    /// Não espera a parada terminar: a fila já garante a ordem contra um `start`
    /// seguinte, e quem cancela não tem o que fazer com a confirmação.
    func stop() {
        queue.async { [self] in stopOnQueue() }
    }

    // MARK: - Na fila de áudio

    private func startOnQueue(sink: any AudioBufferSink) throws -> AsyncStream<Float> {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw Failure.noInput
        }

        // `bufferingNewest`: se a interface atrasar, a waveform deve mostrar o
        // som de agora, não uma fila do que já passou.
        let (stream, continuation) = AsyncStream<Float>.makeStream(
            bufferingPolicy: .bufferingNewest(8)
        )
        levels = continuation

        // O closure captura só `sink` e `continuation`, ambos `Sendable`.
        input.installTap(onBus: 0, bufferSize: Self.bufferSize, format: format) { buffer, _ in
            sink.append(buffer)
            continuation.yield(Self.level(of: buffer))
        }

        engine.prepare()

        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish()
            levels = nil
            Log.voice.error("AVAudioEngine não iniciou: \(error.localizedDescription, privacy: .public)")
            throw Failure.engineDidNotStart
        }

        isRunning = true
        return stream
    }

    private func stopOnQueue() {
        guard isRunning else { return }
        isRunning = false

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        levels?.finish()
        levels = nil
    }

    // MARK: - Nível

    /// Valor eficaz (RMS) do bloco, já comprimido para 0…1.
    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }

        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }

        return normalized(rms: (sum / Float(count)).squareRoot())
    }

    /// Escala logarítmica, de −50 dBFS (0) a 0 dBFS (1).
    ///
    /// Numa escala linear a fala ocupa uma faixa estreita perto do fundo e as
    /// barras mal se mexeriam.
    static func normalized(rms: Float) -> Float {
        guard rms > 0 else { return 0 }

        let floor: Float = -50
        let decibels = 20 * log10(rms)
        guard decibels > floor else { return 0 }

        return min(1, (decibels - floor) / -floor)
    }
}
