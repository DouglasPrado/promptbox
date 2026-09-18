# PRD — Promptbox para macOS

## 1. Visão geral

Promptbox é uma aplicação nativa para macOS focada em armazenar textos reutilizáveis e inseri-los rapidamente em qualquer terminal ou aplicação focada.

O principal caso de uso é reutilizar prompts em ferramentas como:

* Claude Code
* Codex
* OpenCode
* Terminal
* Ghostty
* iTerm
* Warp
* Cursor
* VS Code

O produto não deve integrar diretamente com Claude Code ou Codex.

Ele funciona como uma camada independente entre o usuário e o aplicativo atualmente focado.

A experiência desejada é semelhante a:

* Spotlight
* Raycast
* Command Palette

O aplicativo deve ser extremamente simples, rápido e orientado a teclado.

---

# 2. Problema

Prompts utilizados frequentemente acabam armazenados em:

* arquivos Markdown;
* notas;
* histórico do terminal;
* chats;
* clipboard;
* documentos;
* memória do usuário.

Isso gera atrito sempre que o mesmo prompt precisa ser reutilizado.

O fluxo atual normalmente é:

```text
lembrar onde está o prompt
↓
abrir arquivo
↓
localizar texto
↓
selecionar
↓
copiar
↓
voltar ao terminal
↓
colar
```

Promptbox deve transformar isso em:

```text
atalho
↓
buscar
↓
Enter
```

---

# 3. Objetivo

Permitir que um prompt previamente salvo seja encontrado e inserido em poucos segundos sem que o usuário precise sair do contexto atual.

Objetivo central:

> Tornar prompts reutilizáveis tão rápidos de acessar quanto comandos do Spotlight.

---

# 4. Princípios do produto

## 4.1. Simplicidade

Promptbox não é:

* IDE;
* cliente de IA;
* workflow engine;
* gerenciador de agentes;
* terminal;
* editor Markdown avançado;
* ferramenta de automação.

É apenas:

```text
Salvar texto
+
Encontrar texto
+
Inserir texto
```

---

## 4.2. Keyboard First

Todas as ações principais devem ser executáveis pelo teclado.

Exemplo:

```text
⌥ Space
→ abrir launcher

digitar
→ buscar

↑ ↓
→ navegar

Enter
→ inserir

⌘ Enter
→ inserir e enviar

Esc
→ fechar
```

---

## 4.3. Contexto preservado

Promptbox não deve substituir a aplicação atual.

Quando aberto, deve aparecer como uma camada flutuante sobre:

```text
Terminal
Claude Code
Codex
IDE
Editor
qualquer outra aplicação
```

Ao terminar a ação, deve desaparecer imediatamente.

---

## 4.4. Local First

Todos os prompts devem ficar localmente no Mac.

O MVP não terá:

* login;
* conta;
* servidor;
* API;
* cloud sync;
* telemetria;
* backend.

---

# 5. Estratégia de desenvolvimento

A implementação será dividida em duas grandes etapas.

```text
ETAPA 1
Protótipo funcional de interface

↓

Validação da experiência

↓

ETAPA 2
Integrações reais com macOS
```

A prioridade absoluta é construir e validar o protótipo antes da infraestrutura.

---

# 6. Fase 1 — Protótipo

## 6.1. Objetivo

Construir a experiência completa visualmente antes de implementar:

* hotkeys globais;
* Accessibility API;
* injeção no terminal;
* clipboard;
* SwiftData;
* Launch at Login;
* permissões do sistema.

Nesta fase, todos os dados podem ser mockados.

---

# 7. Protótipo — Fluxo principal

O protótipo deverá demonstrar três fluxos.

## Fluxo A — Buscar prompt

```text
Usuário abre Promptbox
        ↓
Launcher aparece
        ↓
Campo de busca recebe foco
        ↓
Usuário digita
        ↓
Lista é filtrada
        ↓
Usuário seleciona prompt
        ↓
Pressiona Enter
        ↓
Launcher fecha
```

Nesta primeira fase, o prompt não precisa ser realmente inserido em outro aplicativo.

Pode simplesmente executar:

```text
print(prompt.content)
```

ou registrar a ação internamente.

---

# 8. Tela 1 — Prompt Launcher

Esta é a interface principal do produto.

Ela deve ser uma janela flutuante central.

Referência visual:

```text
┌──────────────────────────────────────────────────────┐
│ ⚡ Buscar prompts...                           ⌘ K   │
├──────────────────────────────────────────────────────┤
│                                                      │
│ </>  Implementar Story                         ↵     │
│      Implementa uma story seguindo o padrão.         │
│                                                      │
│ □    Revisar Código                           ⌘ 2    │
│      Analisa o código e sugere melhorias.             │
│                                                      │
│ 🐞   Corrigir Bug                             ⌘ 3    │
│      Identifica e corrige o problema.                 │
│                                                      │
│ □    Criar Documentação                       ⌘ 4    │
│      Gera documentação clara e objetiva.              │
│                                                      │
├──────────────────────────────────────────────────────┤
│ ↵ Inserir   ⌘↵ Inserir e enviar   ↑↓ Navegar   ESC  │
└──────────────────────────────────────────────────────┘
```

---

# 9. Comportamento do Launcher

Ao abrir:

* campo de busca recebe foco automaticamente;
* os prompts recentes aparecem primeiro;
* primeiro item já aparece selecionado;
* navegação deve funcionar por teclado;
* mouse deve ser opcional.

---

## 9.1. Busca

A busca deve considerar inicialmente:

* título;
* descrição;
* conteúdo;
* categoria.

Exemplo:

```text
review
```

pode retornar:

```text
Revisar Código
Review de Implementação
Review de Arquitetura
```

Não é necessário fuzzy search avançado no protótipo.

Busca simples com:

```text
localizedCaseInsensitiveContains
```

é suficiente.

---

# 10. Seleção

O item selecionado deve possuir destaque visual forte.

Exemplo:

```text
┌───────────────────────────────────────────────┐
│ </> Implementar Story                        │
│     Implementa uma story seguindo o padrão.  │
└───────────────────────────────────────────────┘
```

Características:

* fundo azul;
* texto principal branco;
* descrição com menor contraste;
* cantos arredondados.

---

# 11. Ações do launcher

## Enter

No protótipo:

```text
Enter
→ simula "Inserir"
→ fecha launcher
```

Posteriormente:

```text
Enter
→ insere prompt na aplicação anterior
```

---

## Command + Enter

No protótipo:

```text
⌘ Enter
→ simula "Inserir e enviar"
```

Posteriormente:

```text
⌘ Enter
→ insere prompt
→ envia Enter
```

---

## ESC

```text
ESC
→ fecha launcher
```

---

## Arrow Up / Down

```text
↑
↓
```

navegam entre os prompts.

---

# 12. Tela 2 — Salvar Prompt

O segundo componente central é o modal de criação.

Deve ser pequeno e flutuante.

Referência:

```text
┌──────────────────────────────────────────────┐
│  ▣  Salvar Prompt                     ESC   │
│     Seu prompt, sempre à mão                 │
│                                              │
│  Implementar Story                           │
│                                              │
│  🏷 Desenvolvimento                      ⌄   │
│                                              │
│ ┌──────────────────────────────────────────┐ │
│ │ Leia completamente a story atual.       │ │
│ │                                          │ │
│ │ Antes de começar:                        │ │
│ │ - leia DESIGN.md                         │ │
│ │ - leia CLAUDE.md                         │ │
│ │ - use Context7                           │ │
│ │ - execute os testes                      │ │
│ │                                          │ │
│ │                                    242   │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│                     Cancelar     Salvar ↵    │
└──────────────────────────────────────────────┘
```

---

# 13. Campos do prompt

O protótipo terá apenas:

## Título

Exemplo:

```text
Implementar Story
```

Obrigatório.

---

## Categoria

Exemplo:

```text
Desenvolvimento
```

Categorias mockadas:

```text
Desenvolvimento
Review
Documentação
Planejamento
Git
DevOps
Design
Outros
```

Opcional.

---

## Conteúdo

Textarea principal.

Exemplo:

```text
Leia completamente a story atual.

Antes de começar:
- leia DESIGN.md
- leia CLAUDE.md
- use Context7
- implemente o mínimo necessário
- execute os testes
```

Obrigatório.

---

# 14. O que NÃO existirá no protótipo

Não implementar inicialmente:

* tags;
* favoritos;
* variáveis;
* templates;
* Markdown preview;
* syntax highlighting;
* IA;
* autocomplete;
* attachments;
* arquivos;
* agentes;
* Claude SDK;
* Codex SDK.

Esses recursos só devem ser considerados depois da validação do fluxo principal.

---

# 15. Tela 3 — Editar Prompt

A edição deve reutilizar exatamente o mesmo componente de criação.

Diferença:

```text
Salvar Prompt
```

passa a ser:

```text
Editar Prompt
```

Os campos chegam preenchidos.

---

# 16. Gerenciamento de prompts

Não será criada uma dashboard tradicional.

O launcher também será o ponto de gerenciamento.

Uma alternativa simples:

```text
⌘ ,
```

abre uma pequena janela de gerenciamento.

Mas isso não é prioridade da primeira versão do protótipo.

Inicialmente poderá existir apenas um botão:

```text
+ Novo Prompt
```

dentro do launcher.

---

# 17. Dados mockados

O protótipo deve nascer com aproximadamente 8 prompts.

Exemplo:

```text
Implementar Story
Revisar Código
Corrigir Bug
Criar Documentação
Explicar Código
Criar Testes
Refatorar Código
Criar README
```

Modelo:

```swift
struct Prompt: Identifiable {
    let id: UUID
    var title: String
    var description: String?
    var content: String
    var category: PromptCategory?
}
```

---

# 18. Mock inicial

Exemplo:

```swift
Prompt(
    id: UUID(),
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
)
```

---

# 19. Design

## 19.1. Direção visual

O aplicativo deve parecer parte do macOS.

Referências:

* Spotlight;
* Raycast;
* Alfred;
* Arc Command Bar;
* Linear Command Menu.

---

## 19.2. Características

Utilizar:

* dark mode inicialmente;
* transparência;
* blur;
* bordas discretas;
* sombras suaves;
* pouco contraste estrutural;
* bastante espaço;
* tipografia nativa do macOS.

Evitar:

* cards excessivos;
* sidebar;
* tabelas;
* dashboard;
* muitas cores;
* gradientes excessivos;
* botões grandes;
* interface estilo SaaS.

---

# 20. Tipografia

Utilizar fontes do sistema.

Para interface:

```text
SF Pro
```

Para conteúdo de prompt:

```text
SF Mono
```

ou fonte monoespaçada equivalente do sistema.

---

# 21. Ícones

Utilizar:

```text
SF Symbols
```

Exemplos:

```text
bolt.fill
chevron.down
doc.text
ladybug
hammer
terminal
code
tag
plus
```

Não utilizar biblioteca externa de ícones no MVP.

---

# 22. Tecnologia do protótipo

Stack:

```text
Swift 6
SwiftUI
AppKit
```

O protótipo já deve ser feito na stack final.

Não utilizar Figma como etapa obrigatória.

O próprio aplicativo será o protótipo interativo.

---

# 23. Janela flutuante

Mesmo durante o protótipo, deve ser utilizada uma implementação próxima da arquitetura final:

```text
NSPanel
↓
NSHostingView
↓
SwiftUI
```

Isso permite validar:

* dimensões;
* blur;
* posicionamento;
* foco;
* ESC;
* aparência;
* comportamento sobre outros apps.

---

# 24. Componente FloatingPanel

Estrutura sugerida:

```text
Core/
└── Window/
    ├── FloatingPanel.swift
    └── FloatingPanelController.swift
```

Responsável por:

```text
show()
hide()
center()
focus()
closeOnEscape()
```

---

# 25. Prototipagem da interação

Durante a Fase 1, não implementar hotkey global.

Utilizar inicialmente:

* botão na aplicação;
* menu;
* atalhos locais.

Depois que o comportamento estiver validado, transformar em hotkey global.

Isso evita introduzir problemas de permissões antes da validação da UI.

---

# 26. Arquitetura inicial

```text
Promptbox/
│
├── App/
│   ├── PromptboxApp.swift
│   └── AppDelegate.swift
│
├── Features/
│   │
│   ├── Launcher/
│   │   ├── LauncherView.swift
│   │   ├── LauncherViewModel.swift
│   │   └── PromptRow.swift
│   │
│   └── PromptEditor/
│       ├── PromptEditorView.swift
│       └── PromptEditorViewModel.swift
│
├── Core/
│   └── Window/
│       ├── FloatingPanel.swift
│       └── FloatingPanelController.swift
│
├── Models/
│   └── Prompt.swift
│
├── Mocks/
│   └── MockPrompts.swift
│
└── DesignSystem/
    ├── Components/
    ├── Typography.swift
    └── Metrics.swift
```

---

# 27. Estado do protótipo

Pode ser mantido simplesmente em memória:

```swift
@Observable
final class PromptStore {

    var prompts: [Prompt] = MockPrompts.all

}
```

Nenhum banco será necessário neste momento.

---

# 28. Milestone 1 — Shell da aplicação

Objetivo:

Criar a base macOS.

Entregas:

* projeto Xcode;
* SwiftUI;
* AppKit integration;
* dark mode;
* janela principal temporária;
* estrutura de diretórios.

Critério de conclusão:

```text
Aplicação abre e renderiza SwiftUI corretamente.
```

---

# 29. Milestone 2 — Floating Panel

Objetivo:

Construir o container visual definitivo.

Entregas:

* NSPanel;
* centralização;
* transparência;
* blur;
* bordas;
* sombra;
* ESC fecha;
* foco correto.

Critério:

```text
Painel visualmente próximo da referência aprovada.
```

---

# 30. Milestone 3 — Launcher

Objetivo:

Construir a experiência principal.

Entregas:

* busca;
* lista mockada;
* seleção;
* teclado;
* Enter;
* Command + Enter;
* ESC;
* footer com atalhos.

Critério:

O usuário deve conseguir executar:

```text
abrir
↓
digitar
↓
navegar
↓
selecionar
↓
Enter
```

sem utilizar o mouse.

---

# 31. Milestone 4 — Prompt Editor

Objetivo:

Criar a experiência de salvar prompts.

Entregas:

* título;
* categoria;
* textarea;
* contador;
* salvar;
* cancelar;
* teclado.

Critério:

Um prompt criado deve aparecer imediatamente no launcher durante a mesma execução da aplicação.

---

# 32. Milestone 5 — Ajustes de experiência

Validar:

* tamanho do modal;
* velocidade das animações;
* contraste;
* spacing;
* tipografia;
* foco;
* comportamento do teclado;
* estados vazios;
* resultados sem busca.

Nenhuma integração do sistema deve ser adicionada antes dessa etapa estar aprovada.

---

# 33. Gate do protótipo

A Fase 1 só será considerada concluída quando for possível responder positivamente:

### Launcher

* Abre rápido?
* A busca é clara?
* A seleção visual é óbvia?
* É possível operar tudo por teclado?
* A janela tem tamanho adequado?
* O usuário entende Enter?
* O usuário entende Command + Enter?
* Esc funciona de forma natural?

### Editor

* É rápido salvar um prompt?
* Existem campos desnecessários?
* O textarea é grande o suficiente?
* A categoria realmente agrega valor?
* O usuário consegue salvar sem usar mouse?

### Produto

* O aplicativo parece mais rápido que procurar o prompt manualmente?
* A interface parece parte do macOS?
* O usuário consegue aprender sem tutorial?

---

# 34. Fase 2 — Persistência

Somente depois da aprovação do protótipo.

Adicionar:

```text
SwiftData
```

Modelo:

```swift
@Model
final class Prompt {

    var id: UUID

    var title: String

    var content: String

    var category: String?

    var createdAt: Date

    var updatedAt: Date

    var lastUsedAt: Date?

}
```

---

# 35. Fase 3 — Global Hotkey

Adicionar:

```text
⌥ Space
```

para abrir o launcher.

E:

```text
⌘ ⇧ P
```

para criar um prompt.

Esses atalhos devem ser configuráveis posteriormente.

---

# 36. Fase 4 — Injeção

Implementar o fluxo real:

```text
usuário está no terminal
↓
abre Promptbox
↓
Promptbox registra app anterior
↓
usuário escolhe prompt
↓
Promptbox fecha
↓
app anterior recebe foco
↓
prompt é colocado no clipboard
↓
Cmd + V
```

Tecnologias:

```text
NSWorkspace
NSRunningApplication
NSPasteboard
CGEvent
Accessibility API
```

---

# 37. Insert

Comportamento:

```text
Enter
```

faz:

```text
colar prompt
```

sem enviar.

---

# 38. Insert and Send

Comportamento:

```text
⌘ Enter
```

faz:

```text
colar prompt
↓
Enter
```

---

# 39. Segurança de uso

A ação padrão deve ser:

```text
Insert
```

e não:

```text
Insert + Send
```

Isso permite ao usuário revisar o texto antes que Claude, Codex ou qualquer outro terminal receba o comando.

---

# 40. Clipboard

Processo:

```text
salvar clipboard atual
↓
copiar prompt
↓
colar
↓
restaurar clipboard anterior
```

O conteúdo original do clipboard não deve ser perdido.

---

# 41. Accessibility

Promptbox deverá verificar:

```swift
AXIsProcessTrusted()
```

Caso a permissão não exista, exibir orientação para:

```text
System Settings
→ Privacy & Security
→ Accessibility
→ Promptbox
```

---

# 42. Fase 5 — Menu Bar

Promptbox deverá funcionar predominantemente em background.

Menu:

```text
Promptbox

Buscar Prompt
Novo Prompt

──────────────

Configurações

──────────────

Sair
```

---

# 43. Launch at Login

Adicionar opção:

```text
☑ Abrir Promptbox ao iniciar o Mac
```

Não precisa estar habilitada por padrão.

---

# 44. Recentes

Depois da primeira versão funcional:

```text
lastUsedAt
```

poderá ser utilizado para colocar prompts recentemente utilizados no topo.

---

# 45. Favoritos

Feature futura.

Não faz parte do MVP inicial.

---

# 46. Tags

Feature futura.

A busca por título e conteúdo é suficiente inicialmente.

---

# 47. Import / Export

Posteriormente:

```text
Exportar prompts
→ prompts.json
```

e:

```text
Importar prompts
← prompts.json
```

---

# 48. Fora do escopo

Não construir no MVP:

* conta de usuário;
* autenticação;
* backend;
* cloud;
* sincronização;
* equipes;
* colaboração;
* marketplace;
* Claude API;
* OpenAI API;
* Codex integration;
* Claude Code integration;
* terminal integrado;
* workflows;
* agentes;
* prompt generation;
* prompt optimization;
* IA dentro do Promptbox.

---

# 49. Métrica principal de sucesso

A métrica conceitual mais importante é:

```text
tempo entre desejar usar um prompt
e o prompt estar no terminal
```

Objetivo futuro:

```text
< 3 segundos
```

para prompts conhecidos.

---

# 50. Fluxo ideal final

```text
Claude Code

> █

⌥ Space

"impl"

↓


┌────────────────────────────┐
│ Implementar Story          │
└────────────────────────────┘

Enter

↓

Promptbox desaparece

↓

Claude Code

> Leia completamente a story atual.

  Antes de começar:
  - leia DESIGN.md
  - leia CLAUDE.md
  - use Context7
  ...
█
```

O usuário continua exatamente no mesmo contexto onde estava.

---

# 51. Ordem obrigatória de implementação

A ordem de trabalho deve ser:

```text
1. Estrutura do projeto

2. Design visual

3. Floating panel

4. Launcher mockado

5. Prompt editor mockado

6. Navegação por teclado

7. Ajustes de UX

──────── GATE DO PROTÓTIPO ────────

8. SwiftData

9. Hotkey global

10. Clipboard

11. App anterior / foco

12. Text injection

13. Accessibility permission

14. Menu bar

15. Launch at Login
```

A implementação não deve pular diretamente para integrações de sistema.

---

# 52. Regra para agentes de desenvolvimento

Ao utilizar Claude Code, Codex ou outro agente para construir o projeto:

> Sempre priorize primeiro a experiência visual e a interação mockada. Não implemente integrações nativas, persistência ou automações antes que o protótipo atual esteja funcional e visualmente aprovado.

O objetivo é evitar construir infraestrutura para um fluxo que ainda pode mudar.

---

# 53. Definição de MVP

O MVP é considerado concluído quando:

```text
Promptbox roda como aplicação macOS nativa

+

⌥ Space abre launcher

+

prompts podem ser criados e editados

+

prompts persistem localmente

+

busca funciona

+

navegação funciona por teclado

+

Enter insere prompt no aplicativo anterior

+

⌘ Enter insere e envia

+

ESC fecha

+

aplicação funciona em background
```

Não é necessário nada além disso para a primeira versão pública.

---

# 54. Visão resumida

```text
                    Promptbox

                        │
          ┌─────────────┴─────────────┐
          │                           │

     Criar Prompt                Usar Prompt

          │                           │

   Floating Editor             Quick Launcher

          │                           │

        Save                      Search

                                      │

                                   Select

                                      │

                                   Insert

                                      │

                              Terminal / Claude
                               / Codex / IDE
```

A essência do produto deve permanecer:

> Abrir. Buscar. Inserir.
