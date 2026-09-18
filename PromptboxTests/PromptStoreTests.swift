import Foundation
import Testing

@testable import Promptbox

@MainActor
@Suite("PromptStore")
struct PromptStoreTests {

    @Test("Primeira execução semeia os prompts de exemplo")
    func seedsOnFirstLaunch() throws {
        let store = try PromptStore.inMemory(seeded: true)
        #expect(store.prompts.count == MockPrompts.all.count)
    }

    @Test("Sem semeadura o store nasce vazio")
    func startsEmptyWithoutSeeding() throws {
        let store = try PromptStore.inMemory()
        #expect(store.prompts.isEmpty)
    }

    @Test("Salvar insere um prompt novo")
    func saveInsertsNewPrompt() throws {
        let store = try PromptStore.inMemory()
        store.save(Prompt(title: "Novo", content: "conteúdo"))

        #expect(store.prompts.count == 1)
        #expect(store.prompts.first?.title == "Novo")
    }

    @Test("Salvar o mesmo id atualiza no lugar, sem duplicar")
    func saveUpdatesInPlace() throws {
        let store = try PromptStore.inMemory()
        let prompt = Prompt(title: "Antigo", content: "conteúdo")
        store.save(prompt)

        var edited = prompt
        edited.title = "Atualizado"
        store.save(edited)

        #expect(store.prompts.count == 1)
        #expect(store.prompts.first?.title == "Atualizado")
    }

    @Test("Excluir remove o prompt")
    func deleteRemovesPrompt() throws {
        let store = try PromptStore.inMemory()
        let prompt = Prompt(title: "Some", content: "conteúdo")
        store.save(prompt)
        store.delete(prompt)

        #expect(store.prompts.isEmpty)
    }

    @Test("Prompt usado vai para o topo")
    func usingAPromptMovesItToTheTop() throws {
        let store = try PromptStore.inMemory()
        store.save(Prompt(title: "Primeiro", content: "a"))
        store.save(Prompt(title: "Segundo", content: "b"))
        store.save(Prompt(title: "Terceiro", content: "c"))

        let oldest = try #require(store.prompts.last)
        store.markUsed(oldest)

        #expect(store.prompts.first?.id == oldest.id)
    }

    @Test("Cada mutação avança a revisão")
    func everyMutationBumpsRevision() throws {
        let store = try PromptStore.inMemory()
        let start = store.revision

        let prompt = Prompt(title: "Um", content: "a")
        store.save(prompt)
        let afterSave = store.revision
        #expect(afterSave > start)

        store.delete(prompt)
        #expect(store.revision > afterSave)
    }

    @Test("Usar um prompt que não existe não quebra")
    func markingUnknownPromptIsSafe() throws {
        let store = try PromptStore.inMemory()
        store.markUsed(Prompt(title: "Fantasma", content: "x"))
        #expect(store.prompts.isEmpty)
    }
}
