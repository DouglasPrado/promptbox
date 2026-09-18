import Foundation

/// Dados mockados da Fase 1 (PRD §17). Nenhuma persistência nesta etapa.
nonisolated enum MockPrompts {

    static let all: [Prompt] = [
        Prompt(
            title: "Implementar Story",
            description: "Implementa uma story seguindo o padrão do projeto.",
            content: """
            Leia completamente a story atual.

            Antes de começar:
            - leia DESIGN.md
            - leia CLAUDE.md
            - use Context7
            - implemente o mínimo necessário
            - execute os testes
            """,
            category: .development
        ),
        Prompt(
            title: "Revisar Código",
            description: "Analisa o código e sugere melhorias.",
            content: """
            Revise o código alterado.

            Aponte:
            - erros de lógica
            - duplicação desnecessária
            - nomes pouco claros
            - casos de borda não tratados
            """,
            category: .review,
            symbol: "doc.text.magnifyingglass"
        ),
        Prompt(
            title: "Corrigir Bug",
            description: "Identifica e corrige o problema.",
            content: """
            Reproduza o bug descrito.

            Em seguida:
            - explique a causa raiz
            - aplique a menor correção possível
            - adicione um teste que falharia antes da correção
            """,
            category: .development,
            symbol: "ladybug.fill"
        ),
        Prompt(
            title: "Criar Documentação",
            description: "Gera documentação clara e objetiva.",
            content: """
            Documente o módulo indicado.

            Inclua:
            - o que ele faz
            - como usar
            - exemplos curtos
            - limitações conhecidas
            """,
            category: .documentation,
            symbol: "book.fill"
        ),
        Prompt(
            title: "Explicar Código",
            description: "Explica este código de forma simples.",
            content: """
            Explique o código selecionado em linguagem direta.

            Descreva o fluxo principal, as decisões relevantes
            e os pontos que mais confundem quem lê pela primeira vez.
            """,
            category: .review,
            symbol: "sparkles"
        ),
        Prompt(
            title: "Criar Testes",
            description: "Cria testes unitários e de integração.",
            content: """
            Escreva testes para o comportamento atual.

            Cubra:
            - caminho feliz
            - casos de borda
            - erros esperados
            """,
            category: .development,
            symbol: "testtube.2"
        ),
        Prompt(
            title: "Refatorar Código",
            description: "Refatora o código mantendo a funcionalidade.",
            content: """
            Refatore mantendo o comportamento externo idêntico.

            Regras:
            - sem mudança de API pública
            - sem novas dependências
            - testes devem continuar passando
            """,
            category: .development,
            symbol: "arrow.triangle.2.circlepath"
        ),
        Prompt(
            title: "Criar README",
            description: "Gera um README completo para o projeto.",
            content: """
            Gere um README para este projeto.

            Estrutura:
            - o que é
            - como instalar
            - como rodar
            - como contribuir
            """,
            category: .documentation,
            symbol: "doc.text.fill"
        )
    ]
}
