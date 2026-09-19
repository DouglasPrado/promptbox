import SwiftUI

/// Barras espelhadas acompanhando o nível do microfone.
///
/// É o que diferencia "ninguém falou" de "o microfone está mudo": sem ela, os
/// dois casos só apareceriam depois que a transcrição voltasse vazia.
struct WaveformView: View {

    /// Do mais antigo ao mais novo. Menos que `barCount` desenha o resto na
    /// altura mínima, então a waveform cresce da direita para a esquerda.
    let levels: [Float]

    var barCount: Int = VoiceInsertViewModel.waveformBars

    var body: some View {
        HStack(spacing: Metrics.waveformBarSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Palette.waveform)
                    .frame(width: Metrics.waveformBarWidth, height: height(at: index))
            }
        }
        // Alinhamento central é o que espelha: a barra cresce para cima e para
        // baixo a partir da linha do meio, como um medidor de áudio.
        .frame(height: Metrics.waveformHeight)
        .animation(.easeOut(duration: 0.12), value: levels)
    }

    private func height(at index: Int) -> CGFloat {
        let offset = barCount - levels.count
        guard index >= offset, levels.indices.contains(index - offset) else {
            return Metrics.waveformMinBar
        }

        let level = CGFloat(levels[index - offset])
        let range = Metrics.waveformHeight - Metrics.waveformMinBar

        return Metrics.waveformMinBar + level * range
    }
}
