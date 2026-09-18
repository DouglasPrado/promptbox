import AppKit
import Foundation

@MainActor
@Observable
final class LauncherViewModel {

    var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            selectedIndex = 0
        }
    }

    private(set) var selectedIndex: Int = 0

    private let store: PromptStore

    var onInsert: ((Prompt, InsertMode) -> Void)?
    var onNewPrompt: (() -> Void)?
    var onEditPrompt: ((Prompt) -> Void)?
    var onDeletePrompt: ((Prompt) -> Void)?
    var onClose: (() -> Void)?

    init(store: PromptStore) {
        self.store = store
    }

    /// Busca por título, descrição, conteúdo e categoria (PRD §9.1).
    /// `localizedStandardContains` em vez de `localizedCaseInsensitiveContains`:
    /// o segundo diferencia acentos, então "cod" não encontraria "Código" e
    /// "documentacao" não encontraria "Documentação".
    var results: [Prompt] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return store.prompts }

        return store.prompts.filter { prompt in
            prompt.title.localizedStandardContains(term)
                || prompt.description?.localizedStandardContains(term) == true
                || prompt.content.localizedStandardContains(term)
                || prompt.category?.title.localizedStandardContains(term) == true
        }
    }

    var selectedPrompt: Prompt? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    var isEmpty: Bool { results.isEmpty }

    func moveSelection(by offset: Int) {
        let count = results.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + offset + count) % count
    }

    func select(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
    }

    func insert(_ prompt: Prompt, mode: InsertMode) {
        onInsert?(prompt, mode)
        reset()
        onClose?()
    }

    func edit(_ prompt: Prompt) {
        reset()
        onEditPrompt?(prompt)
    }

    func delete(_ prompt: Prompt) {
        onDeletePrompt?(prompt)
    }

    /// Depois de excluir, a lista encolhe e o índice pode ficar fora do intervalo.
    func clampSelection() {
        selectedIndex = min(selectedIndex, max(0, results.count - 1))
    }

    func newPrompt() {
        reset()
        onNewPrompt?()
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }

    // MARK: - Teclado

    /// Chamado pelo painel antes do campo de busca ver o evento.
    func handleKey(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)

        switch event.keyCode {
        case KeyCode.arrowDown:
            moveSelection(by: 1)
            return true

        case KeyCode.arrowUp:
            moveSelection(by: -1)
            return true

        case KeyCode.returnKey:
            guard let prompt = selectedPrompt else { return true }
            insert(prompt, mode: command ? .insertAndSend : .insert)
            return true

        case KeyCode.escape:
            reset()
            onClose?()
            return true

        default:
            break
        }

        // ⌘N abre o editor de prompt (PRD §16).
        if command, event.charactersIgnoringModifiers?.lowercased() == "n" {
            newPrompt()
            return true
        }

        // ⌘⌫ exclui o selecionado. A confirmação fica a cargo de quem recebe.
        if command, event.keyCode == KeyCode.delete {
            guard let prompt = selectedPrompt else { return true }
            delete(prompt)
            return true
        }

        // ⌘E edita o prompt selecionado (PRD §15).
        if command, event.charactersIgnoringModifiers?.lowercased() == "e" {
            guard let prompt = selectedPrompt else { return true }
            edit(prompt)
            return true
        }

        // ⌘1…⌘9 inserem diretamente a linha correspondente.
        if command, let number = Int(event.charactersIgnoringModifiers ?? ""), (1...9).contains(number) {
            let index = number - 1
            guard results.indices.contains(index) else { return true }
            insert(results[index], mode: .insert)
            return true
        }

        return false
    }
}
