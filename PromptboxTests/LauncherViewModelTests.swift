import Foundation
import SwiftData
import Testing

@testable import Promptbox

@MainActor
@Suite("LauncherViewModel")
struct LauncherViewModelTests {

    // MARK: - Busca

    @Test("Busca ignora acento e caixa")
    func searchIgnoresDiacritics() {
        let prompts = [
            Prompt(title: "Revisar Código", content: "..."),
            Prompt(title: "Criar Documentação", content: "...")
        ]

        #expect(LauncherViewModel.matches("cod", in: prompts).map(\.title) == ["Revisar Código"])
        #expect(LauncherViewModel.matches("DOCUMENTACAO", in: prompts).map(\.title) == ["Criar Documentação"])
    }

    @Test("Busca alcança descrição, conteúdo e categoria")
    func searchCoversEveryField() {
        let prompt = Prompt(
            title: "Título",
            description: "uma descrição",
            content: "conteúdo do prompt",
            category: .devops
        )

        #expect(LauncherViewModel.matches("descrição", in: [prompt]).count == 1)
        #expect(LauncherViewModel.matches("conteudo", in: [prompt]).count == 1)
        #expect(LauncherViewModel.matches("devops", in: [prompt]).count == 1)
        #expect(LauncherViewModel.matches("inexistente", in: [prompt]).isEmpty)
    }

    @Test("Termo vazio devolve tudo")
    func emptyTermReturnsEverything() async throws {
        let model = try await makeModel(count: 3)
        model.query = "   "
        #expect(model.results.count == 3)
    }

    // MARK: - Seleção

    @Test("Seleção dá a volta nas duas direções")
    func selectionWrapsAround() async throws {
        let model = try await makeModel(count: 3)

        model.moveSelection(by: -1)
        #expect(model.selectedIndex == 2)

        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 0)
    }

    @Test("Mudar a busca volta a seleção para o topo")
    func changingQueryResetsSelection() async throws {
        let model = try await makeModel(count: 3)
        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 1)

        model.query = "prompt"
        #expect(model.selectedIndex == 0)
    }

    @Test("Seleção fora do intervalo é corrigida após exclusão")
    func clampKeepsSelectionInsideList() async throws {
        let store = try makeStore(count: 3)
        let model = LauncherViewModel(store: store)
        model.moveSelection(by: 2)
        #expect(model.selectedIndex == 2)

        store.delete(store.prompts[2])
        model.clampSelection()

        #expect(model.selectedIndex == 1)
        #expect(model.selectedPrompt != nil)
    }

    // MARK: - Teclado

    @Test("Setas navegam")
    func arrowsNavigate() async throws {
        let model = try await makeModel(count: 3)

        #expect(model.handle(KeyStroke(code: KeyCode.arrowDown)))
        #expect(model.selectedIndex == 1)

        #expect(model.handle(KeyStroke(code: KeyCode.arrowUp)))
        #expect(model.selectedIndex == 0)
    }

    @Test("Enter insere, ⌘Enter insere e envia")
    func returnInserts() async throws {
        let (model, delegate) = try await makeModelWithDelegate(count: 2)

        _ = model.handle(KeyStroke(code: KeyCode.returnKey))
        #expect(delegate.inserted?.mode == .insert)

        _ = model.handle(KeyStroke(code: KeyCode.returnKey, modifiers: .command))
        #expect(delegate.inserted?.mode == .insertAndSend)
    }

    @Test("⌘2 insere o segundo resultado")
    func commandDigitInsertsNthResult() async throws {
        let (model, delegate) = try await makeModelWithDelegate(count: 3)
        let second = model.results[1]

        _ = model.handle(KeyStroke(code: KeyCode.digits[1], modifiers: .command, characters: "2"))

        #expect(delegate.inserted?.prompt.id == second.id)
    }

    @Test("⌘9 sem resultado suficiente não faz nada")
    func commandDigitOutOfRangeIsIgnored() async throws {
        let (model, delegate) = try await makeModelWithDelegate(count: 2)

        #expect(!model.handle(KeyStroke(code: KeyCode.digits[8], modifiers: .command, characters: "9")))
        #expect(delegate.inserted == nil)
    }

    @Test("Esc fecha e limpa a busca")
    func escapeClosesAndClears() async throws {
        let (model, delegate) = try await makeModelWithDelegate(count: 2)
        model.query = "algo"

        #expect(model.handle(KeyStroke(code: KeyCode.escape)))
        #expect(delegate.closed)
        #expect(model.query.isEmpty)
    }

    @Test("⌘N e ⌘E pedem editor")
    func commandNAndEOpenEditor() async throws {
        let (model, delegate) = try await makeModelWithDelegate(count: 2)

        _ = model.handle(KeyStroke(code: 45, modifiers: .command, characters: "n"))
        #expect(delegate.requestedNew)

        _ = model.handle(KeyStroke(code: 14, modifiers: .command, characters: "e"))
        #expect(delegate.edited != nil)
    }

    @Test("Tecla desconhecida não é consumida")
    func unknownKeyIsNotConsumed() async throws {
        let model = try await makeModel(count: 1)
        #expect(!model.handle(KeyStroke(code: KeyCode.tab)))
    }

    // MARK: - Apoio

    private func makeStore(count: Int) throws -> PromptStore {
        let store = try PromptStore.inMemory()
        for index in 0..<count {
            store.save(Prompt(title: "Prompt \(index)", content: "conteúdo \(index)"))
        }
        return store
    }

    private func makeModel(count: Int) async throws -> LauncherViewModel {
        LauncherViewModel(store: try makeStore(count: count))
    }

    private func makeModelWithDelegate(count: Int) async throws -> (LauncherViewModel, LauncherDelegateSpy) {
        let model = try await makeModel(count: count)
        let delegate = LauncherDelegateSpy()
        model.delegate = delegate
        return (model, delegate)
    }
}

@MainActor
final class LauncherDelegateSpy: LauncherViewModelDelegate {

    var inserted: (prompt: Prompt, mode: InsertMode)?
    var edited: Prompt?
    var deleted: Prompt?
    var requestedNew = false
    var closed = false

    func launcherDidInsert(_ prompt: Prompt, mode: InsertMode) { inserted = (prompt, mode) }
    func launcherDidRequestNewPrompt() { requestedNew = true }
    func launcherDidRequestEdit(_ prompt: Prompt) { edited = prompt }
    func launcherDidRequestDelete(_ prompt: Prompt) { deleted = prompt }
    func launcherDidRequestClose() { closed = true }
}
