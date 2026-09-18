import Foundation
import SwiftData

/// Forma persistida do prompt (PRD §34). O app trabalha com o struct `Prompt`;
/// este modelo existe só na fronteira com o SwiftData.
@Model
final class PromptRecord {

    #Unique<PromptRecord>([\.id])

    var id: UUID = UUID()
    var title: String = ""
    var summary: String?
    var content: String = ""
    var categoryRaw: String?
    var symbol: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var lastUsedAt: Date?

    /// Ordem do launcher: o mais recentemente usado ou editado vem primeiro
    /// (PRD §9 e §44).
    ///
    /// Guardado em vez de calculado para que a ordenação aconteça no banco, e não
    /// carregando a tabela inteira na memória a cada leitura.
    var touchedAt: Date = Date.now

    init(prompt: Prompt, now: Date = .now) {
        id = prompt.id
        createdAt = now
        updatedAt = now
        touchedAt = now
        apply(prompt, now: now)
    }

    func apply(_ prompt: Prompt, now: Date = .now) {
        title = prompt.title
        summary = prompt.description
        content = prompt.content
        categoryRaw = prompt.category?.rawValue
        symbol = prompt.symbol
        updatedAt = now
        touchedAt = max(now, lastUsedAt ?? .distantPast)
    }

    func markUsed(_ now: Date = .now) {
        lastUsedAt = now
        touchedAt = now
    }

    var prompt: Prompt {
        Prompt(
            id: id,
            title: title,
            description: summary,
            content: content,
            category: categoryRaw.flatMap(PromptCategory.init(rawValue:)),
            symbol: symbol
        )
    }
}

/// Versão atual do schema. Existe para que a próxima mudança de propriedade tenha
/// um degrau de migração declarado em vez de depender de sorte.
enum PromptSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [PromptRecord.self] }
}

enum PromptMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [PromptSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
