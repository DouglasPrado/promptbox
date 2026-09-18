import Foundation

nonisolated struct Prompt: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var description: String?
    var content: String
    var category: PromptCategory?

    /// Símbolo específico do prompt. Quando ausente, usa o símbolo da categoria.
    var symbol: String?

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        content: String,
        category: PromptCategory? = nil,
        symbol: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.content = content
        self.category = category
        self.symbol = symbol
    }

    var displaySymbol: String {
        symbol ?? category?.symbol ?? PromptCategory.other.symbol
    }
}

nonisolated enum PromptCategory: String, CaseIterable, Identifiable, Sendable {
    case development
    case review
    case documentation
    case planning
    case git
    case devops
    case design
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .development: "Desenvolvimento"
        case .review: "Review"
        case .documentation: "Documentação"
        case .planning: "Planejamento"
        case .git: "Git"
        case .devops: "DevOps"
        case .design: "Design"
        case .other: "Outros"
        }
    }

    var symbol: String {
        switch self {
        case .development: "chevron.left.forwardslash.chevron.right"
        case .review: "checkmark.seal"
        case .documentation: "book"
        case .planning: "list.bullet.rectangle"
        case .git: "arrow.triangle.branch"
        case .devops: "server.rack"
        case .design: "paintbrush"
        case .other: "square.grid.2x2"
        }
    }
}
