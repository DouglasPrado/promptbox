import Foundation
import Testing

@testable import Promptbox

@MainActor
@Suite("PromptEditorViewModel")
struct PromptEditorViewModelTests {

    @Test("Salvar exige título e conteúdo com algo além de espaço")
    func saveRequiresBothFields() {
        let model = PromptEditorViewModel()
        #expect(!model.canSave)

        model.title = "   "
        model.content = "algo"
        #expect(!model.canSave)

        model.title = "Título"
        model.content = "\n  \t "
        #expect(!model.canSave)

        model.content = "conteúdo"
        #expect(model.canSave)
    }

    @Test("Título e conteúdo são aparados ao montar o prompt")
    func buildTrimsBothFields() {
        let model = PromptEditorViewModel()
        model.title = "  Revisar PR  "
        model.content = "\n  revise o PR  \n"

        let prompt = model.build()

        #expect(prompt.title == "Revisar PR")
        #expect(prompt.content == "revise o PR")
    }

    @Test("Editar mantém o id do prompt original")
    func editingKeepsIdentity() {
        let original = Prompt(title: "Antigo", content: "conteúdo")
        let model = PromptEditorViewModel()
        model.load(original)
        model.title = "Novo"

        #expect(model.isEditing)
        #expect(model.build().id == original.id)
    }

    @Test("Excluir usa o prompt salvo, não o que está sendo digitado")
    func deleteUsesStoredPrompt() {
        let original = Prompt(title: "Nome salvo", content: "conteúdo")
        let delegate = EditorDelegateSpy()

        let model = PromptEditorViewModel()
        model.delegate = delegate
        model.load(original)
        model.title = "Nome digitado que ainda não foi salvo"

        model.delete()

        // A confirmação precisa falar do que está no banco, e apagar esse mesmo.
        #expect(delegate.deleted?.title == "Nome salvo")
        #expect(delegate.deleted?.id == original.id)
    }

    @Test("Excluir sem estar editando não faz nada")
    func deleteIsIgnoredWhenCreating() {
        let delegate = EditorDelegateSpy()
        let model = PromptEditorViewModel()
        model.delegate = delegate
        model.title = "Novo"

        model.delete()

        #expect(delegate.deleted == nil)
    }

    @Test("⌘Enter salva, Enter sozinho não")
    func commandReturnSaves() {
        let delegate = EditorDelegateSpy()
        let model = PromptEditorViewModel()
        model.delegate = delegate
        model.title = "Título"
        model.content = "conteúdo"

        #expect(!model.handle(KeyStroke(code: KeyCode.returnKey)))
        #expect(delegate.saved == nil)

        #expect(model.handle(KeyStroke(code: KeyCode.returnKey, modifiers: .command)))
        #expect(delegate.saved?.title == "Título")
    }

    @Test("Esc cancela e limpa o formulário")
    func escapeCancels() {
        let delegate = EditorDelegateSpy()
        let model = PromptEditorViewModel()
        model.delegate = delegate
        model.title = "Rascunho"

        #expect(model.handle(KeyStroke(code: KeyCode.escape)))
        #expect(delegate.cancelled)
        #expect(model.title.isEmpty)
    }

    @Test("Ícone cai para o da categoria quando nenhum foi escolhido")
    func symbolFallsBackToCategory() {
        let model = PromptEditorViewModel()
        #expect(model.displaySymbol == "plus")

        model.category = .git
        #expect(model.displaySymbol == PromptCategory.git.symbol)

        model.symbol = "bolt.fill"
        #expect(model.displaySymbol == "bolt.fill")
    }
}

@MainActor
final class EditorDelegateSpy: PromptEditorViewModelDelegate {

    var saved: Prompt?
    var deleted: Prompt?
    var cancelled = false

    func editorDidSave(_ prompt: Prompt) { saved = prompt }
    func editorDidCancel() { cancelled = true }
    func editorDidRequestDelete(_ prompt: Prompt) { deleted = prompt }
}
