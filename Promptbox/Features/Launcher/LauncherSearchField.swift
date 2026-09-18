import SwiftUI

struct LauncherSearchField: View {

    @Binding var query: String
    /// Cada incremento é um pedido de foco. Um `Bool` não serviria: reexibir o
    /// painel não muda o valor e o SwiftUI não reavaliaria a view.
    let focusToken: Int
    let onNewPrompt: () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Palette.textTertiary)

            AppKitTextField(
                text: $query,
                placeholder: "Buscar prompts...",
                fontSize: 20,
                focusToken: focusToken
            )

            newPromptButton
        }
        .padding(.horizontal, Metrics.spacingXL)
        .frame(height: Metrics.searchFieldHeight)
    }

    /// PRD §16: um botão visível para criar prompt, além do atalho.
    private var newPromptButton: some View {
        Button(action: onNewPrompt) {
            HStack(spacing: Metrics.spacingXS + 2) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Novo")
                    .font(Typography.shortcut)
                ShortcutBadge(keys: ["\u{2318}", "N"])
            }
            .foregroundStyle(Palette.textSecondary)
            .padding(.leading, Metrics.spacingS)
            .padding(.trailing, Metrics.spacingXS)
            .frame(height: 26)
            .background(Palette.tile, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Novo prompt (\u{2318}N)")
    }
}
