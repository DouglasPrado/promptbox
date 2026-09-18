import SwiftUI

struct LauncherFooter: View {

    var body: some View {
        HStack(spacing: Metrics.spacingL) {
            hint(keys: ["↵"], label: Strings.Launcher.insert)
            hint(keys: ["⌘", "↵"], label: Strings.Launcher.insertAndSend)
            hint(keys: ["⌘", "E"], label: Strings.Launcher.edit)

            Spacer(minLength: Metrics.spacingM)

            hint(keys: ["↑", "↓"], label: Strings.Launcher.navigate)
            hint(keys: ["esc"], label: Strings.Launcher.close)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(keys.joined())")
    }
}
