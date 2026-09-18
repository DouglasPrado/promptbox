import Foundation
import SwiftData

/// Prompts persistidos localmente com SwiftData (PRD §34). Nenhum servidor,
/// nenhuma conta: tudo fica no Mac (PRD §4.4).
@MainActor
@Observable
final class PromptStore {

    private(set) var prompts: [Prompt] = []

    private let container: ModelContainer?
    private static let seedKey = "com.oialbert.promptbox.didSeedMocks"

    init() {
        // Caminho próprio: o padrão do SwiftData é
        // ~/Library/Application Support/default.store, compartilhado com qualquer
        // outro app não-sandboxed que também use o padrão.
        let folder = URL.applicationSupportDirectory.appending(path: "Promptbox", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let configuration = ModelConfiguration(url: folder.appending(path: "promptbox.store"))
        container = try? ModelContainer(for: PromptRecord.self, configurations: configuration)

        guard container != nil else {
            // Sem banco o protótipo ainda roda, só não guarda nada entre execuções.
            NSLog("[Promptbox] Não foi possível abrir o banco; usando dados em memória.")
            prompts = MockPrompts.all
            return
        }

        seedIfNeeded()
        reload()
    }

    /// Prompt novo entra na lista; prompt editado é atualizado no lugar.
    func save(_ prompt: Prompt) {
        guard let context else {
            if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
                prompts[index] = prompt
            } else {
                prompts.insert(prompt, at: 0)
            }
            return
        }

        if let record = record(for: prompt.id) {
            record.apply(prompt)
        } else {
            context.insert(PromptRecord(prompt: prompt))
        }

        persist()
        reload()
    }

    func delete(_ prompt: Prompt) {
        guard let context, let record = record(for: prompt.id) else {
            prompts.removeAll { $0.id == prompt.id }
            return
        }

        context.delete(record)
        persist()
        reload()
    }

    /// A inserção real acontece no `PromptInserter`; aqui fica só o registro de uso,
    /// que alimenta a ordenação por recentes.
    func record(_ mode: InsertMode, prompt: Prompt) {
        print("[Promptbox] \(mode.logLabel): \(prompt.title)")

        guard let context, let record = record(for: prompt.id) else { return }
        record.lastUsedAt = .now
        persist()
        _ = context
        reload()
    }

    // MARK: - SwiftData

    private var context: ModelContext? { container?.mainContext }

    private func record(for id: UUID) -> PromptRecord? {
        guard let context else { return nil }
        let descriptor = FetchDescriptor<PromptRecord>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func reload() {
        guard let context else { return }
        let records = (try? context.fetch(FetchDescriptor<PromptRecord>())) ?? []
        prompts = records
            .sorted { $0.touchedAt > $1.touchedAt }
            .map(\.prompt)
    }

    /// Os 8 prompts do PRD §17 entram apenas na primeira execução. A flag evita
    /// que eles voltem depois de o usuário apagar tudo.
    private func seedIfNeeded() {
        guard let context else { return }
        guard !UserDefaults.standard.bool(forKey: Self.seedKey) else { return }

        let existing = (try? context.fetchCount(FetchDescriptor<PromptRecord>())) ?? 0
        if existing == 0 {
            let now = Date.now
            for (offset, prompt) in MockPrompts.all.enumerated() {
                // Mantém a ordem do mock: o primeiro item é o mais "recente".
                let record = PromptRecord(prompt: prompt, now: now.addingTimeInterval(Double(-offset)))
                context.insert(record)
            }
            persist()
        }

        UserDefaults.standard.set(true, forKey: Self.seedKey)
    }

    private func persist() {
        do {
            try context?.save()
        } catch {
            NSLog("[Promptbox] Falha ao salvar: \(error.localizedDescription)")
        }
    }
}

enum InsertMode: Sendable {
    case insert
    case insertAndSend

    var logLabel: String {
        switch self {
        case .insert: "insert"
        case .insertAndSend: "insert+send"
        }
    }
}
