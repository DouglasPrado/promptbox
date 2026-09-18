import SwiftUI

struct PromptRow: View {

    let prompt: Prompt
    let isSelected: Bool
    /// Posição na lista, quando entre as nove primeiras: atalho ⌘1…⌘9.
    let shortcutNumber: Int?

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            icon

            VStack(alignment: .leading, spacing: 1) {
                Text(prompt.title)
                    .font(Typography.rowTitle)
                    .foregroundStyle(isSelected ? Palette.textOnAccent : Palette.textPrimary)

                if let description = prompt.description {
                    Text(description)
                        .font(Typography.rowSubtitle)
                        .foregroundStyle(isSelected ? Palette.textOnAccentSecondary : Palette.textSecondary)
                }
            }
            .lineLimit(1)

            Spacer(minLength: Metrics.spacingM)

            trailing
        }
        .padding(.horizontal, Metrics.spacingM)
        .frame(height: Metrics.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rowCornerRadius, style: .continuous)
                .fill(isSelected ? Palette.accent : .clear)
        )
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabel: String {
        [prompt.title, prompt.description, prompt.category?.title]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var icon: some View {
        RoundedRectangle(cornerRadius: Metrics.iconTileCornerRadius, style: .continuous)
            .fill(isSelected ? Color.white.opacity(0.20) : Palette.tile)
            .frame(width: Metrics.iconTileSize, height: Metrics.iconTileSize)
            .overlay {
                Image(systemName: prompt.displaySymbol)
                    .font(.system(size: Metrics.iconGlyphSize, weight: .medium))
                    .foregroundStyle(isSelected ? Palette.textOnAccent : prompt.displayTint)
            }
    }

    @ViewBuilder
    private var trailing: some View {
        if isSelected {
            ShortcutBadge(keys: ["↵"], style: .onAccent)
        } else if let shortcutNumber {
            ShortcutBadge(keys: ["⌘", "\(shortcutNumber)"])
        }
    }
}
