import AppKit
import SwiftUI

struct LauncherView: View {

    @Bindable var model: LauncherViewModel
    @State private var focusToken = 0

    var body: some View {
        VStack(spacing: 0) {
            LauncherSearchField(
                query: $model.query,
                focusToken: focusToken,
                onNewPrompt: { model.newPrompt() }
            )

            Divider().overlay(Palette.separator)

            if model.isEmpty {
                emptyState
            } else {
                results
            }

            Divider().overlay(Palette.separator)

            LauncherFooter()
        }
        .frame(width: Metrics.launcherWidth)
        .background {
            VisualEffectBackground()
                .overlay(Palette.panel.opacity(0.82))
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .stroke(Palette.border, lineWidth: Metrics.panelBorderWidth)
        }
        .onAppear { focusToken += 1 }
        // O painel é reaproveitado entre aberturas, então `onAppear` só cobre a
        // primeira vez. A cada nova exibição o campo de busca recebe o foco.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let panel = notification.object as? FloatingPanel,
                  panel.identifier?.rawValue == PanelID.launcher else { return }
            focusToken += 1
        }
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, prompt in
                        PromptRow(
                            prompt: prompt,
                            isSelected: index == model.selectedIndex,
                            shortcutNumber: index < 9 ? index + 1 : nil
                        )
                        .id(prompt.id)
                        .onTapGesture {
                            model.select(index)
                            model.insert(prompt, mode: .insert)
                        }
                        .contextMenu {
                            Button(Strings.Launcher.insert) { model.insert(prompt, mode: .insert) }
                            Button(Strings.Launcher.insertAndSend) { model.insert(prompt, mode: .insertAndSend) }
                            Divider()
                            Button(Strings.Launcher.edit) { model.edit(prompt) }
                            Button(Strings.Launcher.delete) { model.delete(prompt) }
                        }
                    }
                }
                .padding(.horizontal, Metrics.spacingS)
                .padding(.vertical, Metrics.spacingS)
            }
            .scrollIndicators(.never)
            .frame(height: listHeight)
            .accessibilityLabel(Strings.Launcher.listLabel)
            .onChange(of: model.selectedIndex) { _, index in
                guard model.results.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(model.results[index].id, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Metrics.spacingS) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Palette.textTertiary)
            Text(Strings.Launcher.emptyTitle)
                .font(Typography.rowTitle)
                .foregroundStyle(Palette.textSecondary)
            Button { model.newPrompt() } label: {
                HStack(spacing: Metrics.spacingS) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text(Strings.Launcher.emptyAction)
                        .font(Typography.rowSubtitle)
                    ShortcutBadge(keys: ["⌘", "N"])
                }
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, Metrics.spacingM)
                .frame(height: 30)
                .background(Palette.tile, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    private var listHeight: CGFloat {
        let content = CGFloat(model.results.count) * (Metrics.rowHeight + 2) + Metrics.spacingL
        return min(content, Metrics.listMaxHeight)
    }
}
