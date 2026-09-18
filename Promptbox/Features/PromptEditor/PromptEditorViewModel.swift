import AppKit
import Foundation

@MainActor
@Observable
final class PromptEditorViewModel {

    var title: String = ""
    var category: PromptCategory?
    var content: String = ""
    var symbol: String?

    /// A edição reaproveita o mesmo componente (PRD §15): muda só o rótulo.
    private(set) var editingID: UUID?

    var onSave: ((Prompt) -> Void)?
    var onCancel: (() -> Void)?
    var onDelete: ((Prompt) -> Void)?

    var heading: String { isEditing ? "Editar Prompt" : "Salvar Prompt" }

    var isEditing: Bool { editingID != nil }

    /// Ícone mostrado no cabeçalho e na lista: o escolhido, senão o da categoria.
    var displaySymbol: String {
        symbol ?? category?.symbol ?? "plus"
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var characterCount: Int { content.count }

    func load(_ prompt: Prompt?) {
        editingID = prompt?.id
        title = prompt?.title ?? ""
        category = prompt?.category
        content = prompt?.content ?? ""
        symbol = prompt?.symbol
    }

    func build() -> Prompt {
        Prompt(
            id: editingID ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content,
            category: category,
            symbol: symbol
        )
    }

    func reset() {
        load(nil)
    }

    // MARK: - Teclado

    /// Chamado pelo painel antes dos campos verem o evento.
    func handleKey(_ event: NSEvent) -> Bool {
        // Enter sem ⌘ pertence ao conteúdo: quebra de linha.
        if event.keyCode == KeyCode.returnKey, event.modifierFlags.contains(.command) {
            save()
            return true
        }

        if event.keyCode == KeyCode.escape {
            cancel()
            return true
        }

        return false
    }

    func save() {
        guard canSave else { return }
        let prompt = build()
        reset()
        onSave?(prompt)
    }

    func cancel() {
        reset()
        onCancel?()
    }

    func delete() {
        guard isEditing else { return }
        onDelete?(build())
    }
}
