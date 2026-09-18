import Foundation
import SwiftData

/// Prompts persistidos localmente com SwiftData (PRD §34). Nenhum servidor,
/// nenhuma conta: tudo fica no Mac (PRD §4.4).
@MainActor
@Observable
final class PromptStore {

    private(set) var prompts: [Prompt] = []

    /// Sobe a cada mutação. Quem mantém cache derivado (a busca do launcher) usa
    /// isso para saber que precisa recalcular.
    private(set) var revision: Int = 0

    private let container: ModelContainer?
    private let defaults: UserDefaults
    private static let seedKey = "com.oialbert.promptbox.didSeedMocks"

    init(
        container: ModelContainer? = nil,
        defaults: UserDefaults = .standard,
        seedsIfEmpty: Bool = true
    ) {
        self.container = container ?? Self.makeContainer()
        self.defaults = defaults

        guard self.container != nil else {
            // Sem banco o app ainda roda, só não guarda nada entre execuções.
            Log.store.error("Não foi possível abrir o banco; usando dados em memória.")
            prompts = MockPrompts.all
            return
        }

        if seedsIfEmpty {
            seedIfNeeded()
        }

        reload()
    }

    /// Store isolado, sem tocar no disco. Usado por testes e previews.
    static func inMemory(seeded: Bool = false) throws -> PromptStore {
        let container = try ModelContainer(
            for: Schema(versionedSchema: PromptSchemaV1.self),
            migrationPlan: PromptMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let suite = "com.oialbert.promptbox.ephemeral"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite) ?? .standard

        return PromptStore(container: container, defaults: defaults, seedsIfEmpty: seeded)
    }

    /// Container em pasta própria: o padrão do SwiftData é
    /// `~/Library/Application Support/default.store`, compartilhado com qualquer
    /// outro app não-sandboxed que também use o padrão.
    private static func makeContainer() -> ModelContainer? {
        let folder = URL.applicationSupportDirectory.appending(path: "Promptbox", directoryHint: .isDirectory)

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            return try ModelContainer(
                for: Schema(versionedSchema: PromptSchemaV1.self),
                migrationPlan: PromptMigrationPlan.self,
                configurations: ModelConfiguration(url: folder.appending(path: "promptbox.store"))
            )
        } catch {
            Log.store.error("Falha ao abrir o container: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Prompt novo entra na lista; prompt editado é atualizado no lugar.
    func save(_ prompt: Prompt) {
        guard let context else {
            if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
                prompts[index] = prompt
            } else {
                prompts.insert(prompt, at: 0)
            }
            revision += 1
            return
        }

        if let record = fetchRecord(id: prompt.id) {
            record.apply(prompt)
        } else {
            context.insert(PromptRecord(prompt: prompt))
        }

        persist()
        reload()
    }

    func delete(_ prompt: Prompt) {
        guard let context, let record = fetchRecord(id: prompt.id) else {
            prompts.removeAll { $0.id == prompt.id }
            revision += 1
            return
        }

        context.delete(record)
        persist()
        reload()
    }

    /// A inserção real acontece no `PromptInserter`; aqui fica só o registro de uso,
    /// que alimenta a ordenação por recentes.
    func markUsed(_ prompt: Prompt) {
        guard let record = fetchRecord(id: prompt.id) else { return }
        record.markUsed()
        persist()
        reload()
    }

    // MARK: - SwiftData

    private var context: ModelContext? { container?.mainContext }

    private func fetchRecord(id: UUID) -> PromptRecord? {
        guard let context else { return nil }
        let descriptor = FetchDescriptor<PromptRecord>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    /// A ordenação acontece no banco: `touchedAt` é coluna, não valor calculado.
    private func reload() {
        guard let context else { return }

        let descriptor = FetchDescriptor<PromptRecord>(
            sortBy: [SortDescriptor(\.touchedAt, order: .reverse)]
        )

        prompts = ((try? context.fetch(descriptor)) ?? []).map(\.prompt)
        revision += 1
    }

    /// Os 8 prompts do PRD §17 entram apenas na primeira execução.
    ///
    /// A flag só é gravada quando a semeadura realmente foi salva: marcá-la antes
    /// deixaria o app permanentemente vazio caso a primeira gravação falhasse.
    private func seedIfNeeded() {
        guard let context else { return }
        guard !defaults.bool(forKey: Self.seedKey) else { return }

        let existing = (try? context.fetchCount(FetchDescriptor<PromptRecord>())) ?? 0

        guard existing == 0 else {
            defaults.set(true, forKey: Self.seedKey)
            return
        }

        let now = Date.now
        for (offset, prompt) in MockPrompts.all.enumerated() {
            // Mantém a ordem do mock: o primeiro item é o mais "recente".
            context.insert(PromptRecord(prompt: prompt, now: now.addingTimeInterval(Double(-offset))))
        }

        guard persist() else {
            context.rollback()
            Log.store.error("Semeadura inicial falhou; será tentada de novo na próxima execução.")
            return
        }

        defaults.set(true, forKey: Self.seedKey)
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            try context?.save()
            return true
        } catch {
            Log.store.error("Falha ao salvar: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
