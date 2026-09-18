import SwiftUI

struct LauncherFooter: View {

    var body: some View {
        HStack(spacing: Metrics.spacingL) {
            hint(keys: ["↵"], label: "Inserir")
            hint(keys: ["⌘", "↵"], label: "Inserir e enviar")

            Spacer(minLength: Metrics.spacingM)

            hint(keys: ["↑", "↓"], label: "Navegar")
            hint(keys: ["esc"], label: "Fechar")
        }
        .padding(.horizontal, Metrics.spacingL)
        .frame(height: Metrics.footerHeight)
        .background(Palette.footer.opacity(0.55))
    }

    private func hint(keys: [String], label: String) -> some View {
        HStack(spacing: Metrics.spacingS) {
            ShortcutBadge(keys: keys)
            Text(label)
                .font(Typography.footer)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}
