import Foundation

/// Textos da interface em um lugar só.
///
/// `String(localized:)` mantém tudo extraível para um catálogo de tradução em vez
/// de espalhar literais pelas views.
nonisolated enum Strings {

    enum Launcher {
        static let searchPlaceholder = String(localized: "Buscar prompts...")
        static let newPrompt = String(localized: "Novo")
        static let newPromptHelp = String(localized: "Novo prompt (⌘N)")
        static let emptyTitle = String(localized: "Nenhum prompt encontrado")
        static let emptyAction = String(localized: "Criar prompt novo")
        static let insert = String(localized: "Inserir")
        static let insertAndSend = String(localized: "Inserir e enviar")
        static let navigate = String(localized: "Navegar")
        static let close = String(localized: "Fechar")
        static let edit = String(localized: "Editar")
        static let delete = String(localized: "Excluir")
        static let listLabel = String(localized: "Lista de prompts")
    }

    enum Editor {
        static let createHeading = String(localized: "Salvar Prompt")
        static let editHeading = String(localized: "Editar Prompt")
        static let subtitle = String(localized: "Seu prompt, sempre à mão")
        static let titleField = String(localized: "Título")
        static let titlePlaceholder = String(localized: "Implementar Story")
        static let categoryField = String(localized: "Categoria")
        static let noCategory = String(localized: "Sem categoria")
        static let symbolField = String(localized: "Ícone")
        static let contentField = String(localized: "Conteúdo")
        static let cancel = String(localized: "Cancelar")
        static let save = String(localized: "Salvar Prompt")
        static let delete = String(localized: "Excluir")

        static func characterCount(_ count: Int) -> String {
            String(localized: "\(count) caracteres")
        }
    }

    enum Menu {
        static let search = String(localized: "Buscar Prompt")
        static let searchHotkeyTaken = String(localized: "Buscar Prompt (⌥Space em uso por outro app)")
        static let newPrompt = String(localized: "Novo Prompt")
        static let launchAtLogin = String(localized: "Abrir ao iniciar o Mac")
        static let quit = String(localized: "Sair do Promptbox")
    }

    enum DeleteAlert {
        static func title(_ prompt: String) -> String {
            String(localized: "Excluir \"\(prompt)\"?")
        }

        static let message = String(localized: "Esta ação não pode ser desfeita.")
        static let confirm = String(localized: "Excluir")
        static let cancel = String(localized: "Cancelar")
    }

    enum PermissionAlert {
        static let title = String(localized: "Promptbox precisa de permissão de Acessibilidade")
        static let message = String(localized: """
        Para inserir o prompt no app anterior, o Promptbox precisa ser autorizado em:

        Ajustes do Sistema → Privacidade e Segurança → Acessibilidade

        Depois de autorizar, tente novamente.
        """)
        static let openSettings = String(localized: "Abrir Ajustes")
        static let later = String(localized: "Depois")
    }
}
