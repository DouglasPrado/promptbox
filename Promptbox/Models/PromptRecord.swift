import Foundation
import SwiftData

/// Forma persistida do prompt (PRD §34). O app continua trabalhando com o struct
/// `Prompt`; este modelo existe só na fronteira com o SwiftData.
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

    init(prompt: Prompt, now: Date = .now) {
        id = prompt.id
        createdAt = now
        updatedAt = now
        apply(prompt, now: now)
    }

    func apply(_ prompt: Prompt, now: Date = .now) {
        title = prompt.title
        summary = prompt.description
        content = prompt.content
        categoryRaw = prompt.category?.rawValue
        symbol = prompt.symbol
        updatedAt = now
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

    /// Ordem do launcher: o que foi usado ou criado mais recentemente vem primeiro
    /// (PRD §9 e §44).
    var touchedAt: Date {
        max(lastUsedAt ?? .distantPast, updatedAt)
    }
}
