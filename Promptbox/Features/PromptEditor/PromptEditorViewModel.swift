import Foundation

@MainActor
protocol PromptEditorViewModelDelegate: AnyObject {
    func editorDidSave(_ prompt: Prompt)
    func editorDidCancel()
    func editorDidRequestDelete(_ prompt: Prompt)
}

@MainActor
@Observable
final class PromptEditorViewModel {

    var title: String = ""
    var category: PromptCategory?
    var content: String = ""
    var symbol: String?

    weak var delegate: PromptEditorViewModelDelegate?

    /// O prompt original em edição. Guardado inteiro, e não só o id, porque a
    /// exclusão precisa se referir ao que está salvo — não ao que está sendo
    /// digitado no formulário.
    private(set) var editing: Prompt?

    var isEditing: Bool { editing != nil }

    var heading: String { isEditing ? Strings.Editor.editHeading : Strings.Editor.createHeading }

    /// Ícone mostrado no cabeçalho: o escolhido, senão o da categoria.
    var displaySymbol: String {
        symbol ?? category?.symbol ?? "plus"
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty && !trimmedContent.isEmpty
    }

    var characterCount: Int { content.count }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func load(_ prompt: Prompt?) {
        editing = prompt
        title = prompt?.title ?? ""
        category = prompt?.category
        content = prompt?.content ?? ""
        symbol = prompt?.symbol
    }

    func build() -> Prompt {
        Prompt(
            id: editing?.id ?? UUID(),
            title: trimmedTitle,
            description: editing?.description,
            content: trimmedContent,
            category: category,
            symbol: symbol
        )
    }

    func reset() {
        load(nil)
    }

    // MARK: - Ações

    func save() {
        guard canSave else { return }
        let prompt = build()
        reset()
        delegate?.editorDidSave(prompt)
    }

    func cancel() {
        reset()
        delegate?.editorDidCancel()
    }

    func delete() {
        guard let editing else { return }
        delegate?.editorDidRequestDelete(editing)
    }

    // MARK: - Teclado

    func handle(_ key: KeyStroke) -> Bool {
        // Enter sem ⌘ pertence ao conteúdo: quebra de linha.
        if key.code == KeyCode.returnKey, key.hasCommand {
            save()
            return true
        }

        if key.code == KeyCode.escape {
            cancel()
            return true
        }

        return false
    }
}
