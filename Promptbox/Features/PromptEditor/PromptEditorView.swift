import AppKit
import SwiftUI

struct PromptEditorView: View {

    @Bindable var model: PromptEditorViewModel
    @State private var focusToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingL) {
            header
            field(label: "Título") {
                AppKitTextField(
                    text: $model.title,
                    placeholder: "Implementar Story",
                    focusToken: focusToken
                )
                .padding(.horizontal, Metrics.spacingM)
                .frame(height: Metrics.fieldHeight)
                .background(fieldBackground)
            }
            field(label: "Categoria") { categoryPicker }
            field(label: "Ícone") { symbolPicker }
            field(label: "Conteúdo") { contentEditor }
            actions
        }
        .padding(Metrics.spacingXL)
        .frame(width: Metrics.editorWidth)
        .background {
            VisualEffectBackground()
                .overlay(Palette.panel.opacity(0.88))
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .stroke(Palette.border, lineWidth: Metrics.panelBorderWidth)
        }
        .onAppear { focusToken += 1 }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let panel = notification.object as? FloatingPanel,
                  panel.identifier?.rawValue == PanelID.editor else { return }
            focusToken += 1
        }
    }

    private var header: some View {
        HStack(spacing: Metrics.spacingM) {
            RoundedRectangle(cornerRadius: Metrics.iconTileCornerRadius, style: .continuous)
                .fill(Palette.accent)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: model.displaySymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.textOnAccent)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(model.heading)
                    .font(Typography.modalTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text("Seu prompt, sempre à mão")
                    .font(Typography.modalSubtitle)
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer(minLength: Metrics.spacingM)

            ShortcutBadge(keys: ["esc"])
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            Text(label)
                .font(Typography.sectionTitle)
                .foregroundStyle(Palette.textSecondary)
            content()
        }
    }

    /// O `Menu` do macOS ignora background e frame aplicados ao seu label, então
    /// o campo é desenhado aqui e o menu fica por cima, transparente, só para
    /// capturar o clique e abrir a lista nativa.
    private var categoryPicker: some View {
        HStack(spacing: Metrics.spacingS) {
            Image(systemName: model.category?.symbol ?? "tag")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(model.category?.tint ?? Palette.textTertiary)
            Text(model.category?.title ?? "Sem categoria")
                .font(Typography.field)
                .foregroundStyle(model.category == nil ? Palette.textTertiary : Palette.textPrimary)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, Metrics.spacingM)
        .frame(height: Metrics.fieldHeight)
        .background(fieldBackground)
        .overlay {
            Menu {
                Button("Sem categoria") { model.category = nil }
                Divider()
                ForEach(PromptCategory.allCases) { category in
                    Button {
                        model.category = category
                    } label: {
                        Label(category.title, systemImage: category.symbol)
                    }
                }
            } label: {
                Color.clear.contentShape(.rect)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    /// Grade curta de SF Symbols. Tocar no ícone já selecionado volta ao ícone
    /// da categoria — sem opção extra de "automático" na interface.
    private var symbolPicker: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.spacingS), count: 8),
            spacing: Metrics.spacingS
        ) {
            ForEach(PromptSymbols.all, id: \.self) { symbol in
                let isSelected = model.symbol == symbol

                Button {
                    model.symbol = isSelected ? nil : symbol
                } label: {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Palette.accent : Palette.tile)
                        .frame(height: 30)
                        .overlay {
                            Image(systemName: symbol)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSelected ? Palette.textOnAccent : Palette.textSecondary)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var contentEditor: some View {
        VStack(alignment: .trailing, spacing: Metrics.spacingXS) {
            AppKitTextView(text: $model.content)
                .frame(height: 180)
                .padding(.horizontal, Metrics.spacingS)
                .padding(.vertical, Metrics.spacingXS)
                .background(fieldBackground)

            Text("\(model.characterCount) caracteres")
                .font(Typography.counter)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var actions: some View {
        HStack(spacing: Metrics.spacingM) {
            if model.isEditing {
                Button { model.delete() } label: {
                    HStack(spacing: Metrics.spacingXS + 2) {
                        Image(systemName: "trash")
                        Text("Excluir")
                    }
                    .font(Typography.button)
                    .foregroundStyle(Palette.categoryRed)
                    .padding(.horizontal, Metrics.spacingM)
                    .frame(height: Metrics.buttonHeight)
                    .background(Palette.tile, in: RoundedRectangle(cornerRadius: Metrics.buttonCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button { model.cancel() } label: {
                Text("Cancelar")
                    .font(Typography.button)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, Metrics.spacingL)
                    .frame(height: Metrics.buttonHeight)
                    .background(Palette.tile, in: RoundedRectangle(cornerRadius: Metrics.buttonCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { model.save() } label: {
                HStack(spacing: Metrics.spacingS) {
                    Text("Salvar Prompt")
                    ShortcutBadge(keys: ["⌘", "↵"], style: .onAccent)
                }
                .font(Typography.button)
                .foregroundStyle(Palette.textOnAccent)
                .padding(.horizontal, Metrics.spacingL)
                .frame(height: Metrics.buttonHeight)
                .background(
                    (model.canSave ? Palette.accent : Palette.accent.opacity(0.35)),
                    in: RoundedRectangle(cornerRadius: Metrics.buttonCornerRadius, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!model.canSave)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: Metrics.fieldCornerRadius, style: .continuous)
            .fill(Palette.tile)
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.fieldCornerRadius, style: .continuous)
                    .stroke(Palette.border, lineWidth: Metrics.panelBorderWidth)
            }
    }

}
