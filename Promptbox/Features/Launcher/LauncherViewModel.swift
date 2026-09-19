import Foundation

/// Quem recebe as intenções do launcher. Um protocolo em vez de closures soltas:
/// esquecer de ligar uma ação passa a ser erro de compilação, não feature morta.
@MainActor
protocol LauncherViewModelDelegate: AnyObject {
    func launcherDidInsert(_ prompt: Prompt, mode: InsertMode)
    func launcherDidRequestNewPrompt()
    func launcherDidRequestEdit(_ prompt: Prompt)
    func launcherDidRequestDelete(_ prompt: Prompt)
    func launcherDidRequestClose()
}

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

    weak var delegate: LauncherViewModelDelegate?

    private let store: PromptStore

    /// Filtrar é caro (`localizedStandardContains` é sensível a locale) e `results`
    /// é lido várias vezes por evento. O cache é invalidado pelo termo e pela
    /// revisão do store. Fora da observação para não disparar mudança ao ler.
    @ObservationIgnored
    private var cache: (term: String, revision: Int, results: [Prompt])?

    init(store: PromptStore) {
        self.store = store
    }

    /// Busca por título, descrição, conteúdo e categoria (PRD §9.1).
    /// `localizedStandardContains` em vez de `localizedCaseInsensitiveContains`:
    /// o segundo diferencia acentos, então "cod" não encontraria "Código".
    var results: [Prompt] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if let cache, cache.term == term, cache.revision == store.revision {
            return cache.results
        }

        let computed = Self.matches(term, in: store.prompts)
        cache = (term, store.revision, computed)
        return computed
    }

    static func matches(_ term: String, in prompts: [Prompt]) -> [Prompt] {
        guard !term.isEmpty else { return prompts }

        return prompts.filter { prompt in
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
        // Fechar vem primeiro de propósito: a inserção devolve o foco ao app
        // anterior, e isso é mais confiável com o painel já fora da tela e o
        // Promptbox de volta ao segundo plano.
        reset()
        delegate?.launcherDidRequestClose()
        delegate?.launcherDidInsert(prompt, mode: mode)
    }

    func edit(_ prompt: Prompt) {
        reset()
        delegate?.launcherDidRequestEdit(prompt)
    }

    func delete(_ prompt: Prompt) {
        delegate?.launcherDidRequestDelete(prompt)
    }

    func newPrompt() {
        reset()
        delegate?.launcherDidRequestNewPrompt()
    }

    func close() {
        reset()
        delegate?.launcherDidRequestClose()
    }

    /// Depois de excluir, a lista encolhe e o índice pode ficar fora do intervalo.
    func clampSelection() {
        selectedIndex = min(selectedIndex, max(0, results.count - 1))
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }

    // MARK: - Teclado

    /// Chamado pelo painel antes do campo de busca ver o evento.
    /// Retorna `true` quando consome a tecla.
    func handle(_ key: KeyStroke) -> Bool {
        switch key.code {
        case KeyCode.arrowDown:
            moveSelection(by: 1)
            return true

        case KeyCode.arrowUp:
            moveSelection(by: -1)
            return true

        case KeyCode.returnKey:
            guard let prompt = selectedPrompt else { return false }
            insert(prompt, mode: key.hasCommand ? .insertAndSend : .insert)
            return true

        case KeyCode.escape:
            close()
            return true

        default:
            break
        }

        guard key.hasCommand else { return false }

        // ⌘N novo (PRD §16), ⌘E edita (PRD §15), ⌘⌫ exclui.
        if key.matches("n") {
            newPrompt()
            return true
        }

        if key.matches("e") {
            guard let prompt = selectedPrompt else { return false }
            edit(prompt)
            return true
        }

        if key.code == KeyCode.delete {
            guard let prompt = selectedPrompt else { return false }
            delete(prompt)
            return true
        }

        // ⌘1…⌘9 inserem diretamente a linha correspondente.
        if let digit = key.digit {
            let index = digit - 1
            guard results.indices.contains(index) else { return false }
            insert(results[index], mode: .insert)
            return true
        }

        return false
    }
}
