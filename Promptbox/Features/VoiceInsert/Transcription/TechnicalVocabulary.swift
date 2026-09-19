/// Termos entregues ao reconhecedor como contexto (VOICE-INSERT §Vocabulário técnico).
///
/// O uso principal do Voice Insert é falar com Claude Code e Codex, e nomes de
/// ferramenta são justamente o que um reconhecedor de pt-BR erra: sem esta lista
/// "Context7" vira "contexto sete" e "pnpm" vira qualquer coisa.
///
/// `contextualStrings` enviesa o reconhecimento, não o força — palavras fora da
/// lista continuam sendo reconhecidas normalmente.
enum TechnicalVocabulary {

    static let terms = [
        "Claude",
        "Claude Code",
        "Codex",
        "Context7",
        "Cursor",
        "Ghostty",
        "Promptbox",
        "Next.js",
        "NestJS",
        "SwiftUI",
        "AppKit",
        "SwiftData",
        "Swift",
        "Xcode",
        "Prisma",
        "Postgres",
        "Redis",
        "pnpm",
        "npm",
        "GitHub",
        "Docker",
        "TypeScript",
        "JavaScript",
        "Python",
        "React",
        "Tailwind",
        "Vercel",
        "Supabase",
        "commit",
        "pull request",
        "merge",
        "rebase",
        "deploy",
        "build",
        "lint",
        "refatorar",
        "endpoint",
        "payload"
    ]
}
