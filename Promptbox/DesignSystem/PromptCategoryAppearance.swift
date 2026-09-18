import SwiftUI

/// Cor de cada categoria. Fica na camada visual para que o modelo continue
/// livre de SwiftUI — e, com isso, utilizável fora da main actor (SwiftData).
extension PromptCategory {

    var tint: Color {
        switch self {
        case .development: Palette.categoryBlue
        case .review: Palette.categoryGray
        case .documentation: Palette.categoryGreen
        case .planning: Palette.categoryYellow
        case .git: Palette.categoryOrange
        case .devops: Palette.categoryPurple
        case .design: Palette.categoryRed
        case .other: Palette.categoryGray
        }
    }
}

extension Prompt {

    var displayTint: Color {
        category?.tint ?? Palette.categoryGray
    }
}
