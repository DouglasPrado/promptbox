import SwiftUI

/// O overlay do Voice Insert: uma barra estreita, translúcida e sem título
/// (VOICE-INSERT §Interface).
///
/// Deve se parecer com um atalho de voz, não com um gravador — daí não haver
/// campo de texto, botão de play nem nada que peça clique.
struct VoiceOverlayView: View {

    let model: VoiceInsertViewModel

    @State private var isPulsing = false

    var body: some View {
        content
            .padding(.horizontal, Metrics.spacingXL)
            .frame(width: Metrics.voiceOverlayWidth, height: Metrics.voiceOverlayHeight)
            .background {
                VisualEffectBackground()
                    .overlay(Palette.panel.opacity(0.78))
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.voiceOverlayCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.voiceOverlayCornerRadius, style: .continuous)
                    .stroke(Palette.border, lineWidth: Metrics.panelBorderWidth)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            // A hipótese parcial não é desenhada (o mockup mostra a barra em uma
            // linha só), mas é o que o VoiceOver tem a dizer enquanto se fala.
            .accessibilityValue(model.partial)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .recording:
            recording

        case .failed(let failure):
            message(failure == .noSpeech ? Strings.Voice.noSpeech : Strings.Voice.failed)

        default:
            transcribing
        }
    }

    // MARK: - Gravando

    private var recording: some View {
        HStack(spacing: Metrics.spacingM) {
            Circle()
                .fill(Palette.recording)
                .frame(width: Metrics.recordingDotSize, height: Metrics.recordingDotSize)
                .opacity(isPulsing ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear { isPulsing = true }
                .onDisappear { isPulsing = false }

            Text(Strings.Voice.recording)
                .font(Typography.voiceStatus)
                .foregroundStyle(Palette.textPrimary)

            Text(model.timeLabel)
                .font(Typography.voiceTimer)
                .foregroundStyle(Palette.textSecondary)

            WaveformView(levels: model.levels)
                .padding(.leading, Metrics.spacingXS)

            Spacer(minLength: Metrics.spacingM)

            Rectangle()
                .fill(Palette.voiceDivider)
                .frame(width: Metrics.panelBorderWidth, height: Metrics.voiceDividerHeight)

            hints
        }
    }

    /// `⌃↵` sai como glifo puro e `Esc` como tecla desenhada, seguindo o mockup:
    /// a ação que se quer que o usuário use fica leve, a saída fica marcada.
    private var hints: some View {
        HStack(spacing: Metrics.spacingL) {
            HStack(spacing: Metrics.spacingS) {
                Text(verbatim: "⌃↵")
                    .font(Typography.voiceGlyph)
                    .foregroundStyle(Palette.textSecondary)
                Text(Strings.Voice.insert)
                    .font(Typography.voiceHint)
                    .foregroundStyle(Palette.textPrimary)
            }

            HStack(spacing: Metrics.spacingS) {
                ShortcutBadge(keys: ["Esc"])
                Text(Strings.Voice.cancel)
                    .font(Typography.voiceHint)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - Demais estados

    private var transcribing: some View {
        HStack(spacing: Metrics.spacingM) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)

            Text(Strings.Voice.transcribing)
                .font(Typography.voiceStatus)
                .foregroundStyle(Palette.textPrimary)

            Spacer(minLength: 0)
        }
    }

    private func message(_ text: String) -> some View {
        HStack(spacing: Metrics.spacingM) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Palette.textSecondary)

            Text(text)
                .font(Typography.voiceStatus)
                .foregroundStyle(Palette.textPrimary)

            Spacer(minLength: 0)
        }
    }

    private var accessibilityLabel: String {
        switch model.state {
        case .recording: "\(Strings.Voice.overlayLabel): \(Strings.Voice.recording) \(model.timeLabel)"
        case .failed(let failure): failure == .noSpeech ? Strings.Voice.noSpeech : Strings.Voice.failed
        default: Strings.Voice.transcribing
        }
    }
}
