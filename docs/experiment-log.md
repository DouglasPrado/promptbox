# Experiment Log — Promptbox

Registro curto por story: o que foi feito, o que foi decidido e o que ficou de fora.

---

## M01 / S01 — Shell da aplicação

**Data:** 2026-09-18
**Escopo:** PRD §28 (Milestone 1) e §51, item 1.

### Entregue

- Projeto Xcode `Promptbox.xcodeproj` (target macOS nativo, Debug/Release, scheme compartilhado).
- Ciclo de vida SwiftUI (`App` + `Window`) com dark mode forçado.
- Integração AppKit via `NSApplicationDelegateAdaptor` (`AppDelegate` define activation policy e foco).
- Janela principal temporária (`ShellView`) — será substituída pelo FloatingPanel no M02.
- Estrutura de diretórios conforme PRD §26: `App/`, `DesignSystem/`, `Models/`, `Mocks/`, `Resources/`.
- Tokens iniciais do design system: `Palette`, `Typography`, `Metrics`.
- Modelo `Prompt` + `PromptCategory` e os 8 prompts mockados do PRD §17.

### Verificação

- `xcodebuild -scheme Promptbox -configuration Debug build` → **BUILD SUCCEEDED**, sem warnings.
- App aberto e capturado: janela 780×560 renderizando SwiftUI em dark mode, 8 prompts mockados carregados.

### Decisões

- **Toolchain:** Xcode 26.5 / Swift 6.3.2. Target `MACOSX_DEPLOYMENT_TARGET = 15.0`, `SWIFT_VERSION = 6.0`,
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- **Projeto sem App Sandbox.** As fases 4 e 5 (clipboard, Accessibility API, injeção de texto) exigem
  execução fora do sandbox; habilitá-lo agora criaria retrabalho.
- **`PBXFileSystemSynchronizedRootGroup`** (objectVersion 77): arquivos novos dentro de `Promptbox/`
  entram no target automaticamente, sem editar o `project.pbxproj`.
- **Ícones:** SF Symbols, conforme PRD §21. Nenhuma biblioteca externa de ícones.
- **Campo `symbol` em `Prompt`** (opcional, com fallback para o símbolo da categoria): os mockups em
  `docs/` mostram ícones distintos para prompts da mesma categoria. Sem esse campo o launcher não
  reproduziria a referência visual aprovada.
- **Paleta derivada dos mockups**, não de um `design.md` — este repositório não possui um.

### Fora de escopo nesta story

- FloatingPanel / NSPanel, blur e transparência (M02).
- Launcher, busca, navegação por teclado (M03).
- Editor de prompt (M04).
- Hotkey global, SwiftData, clipboard, Accessibility, menu bar (Fases 2 a 5).

### Checkpoint

Aguardando aprovação visual antes de iniciar o M02.

---

## M02 + M03 — Floating Panel e Launcher

**Data:** 2026-09-18
**Escopo:** PRD §23–24 (Milestone 2) e §29–30 (Milestone 3).

Os dois milestones foram entregues juntos porque o critério de aceite do M02
("painel visualmente próximo da referência aprovada") só pode ser julgado com o
conteúdo do launcher dentro do painel.

### Entregue

- `FloatingPanel`: `NSPanel` borderless e não-ativante, nível flutuante, sombra,
  fundo transparente, ESC via `cancelOperation`.
- `FloatingPanelController`: `show()`, `hide()`, `toggle()`, `center()`, `focus()`.
  Altura acompanha o conteúdo via `NSHostingController.sizingOptions = .preferredContentSize`.
- `VisualEffectBackground`: blur `behindWindow` real sobre o app de trás.
- Launcher completo: busca, lista, seleção, navegação por teclado, footer de atalhos,
  estado vazio, atalhos ⌘1…⌘9, clique no item.
- Janela de controle (`ShellView`) com botão e atalho local ⌘K, já que a Fase 1 não
  tem hotkey global (PRD §25). Mostra a última ação registrada.

### Verificação (app rodando, não só compilando)

- Build Debug sem warnings.
- ⌘K abre o painel centralizado, 680 pt de largura.
- Digitar `cod` filtra para os três prompts de "Código" e o painel encolhe de 582 → 292 pt.
- ↓ move a seleção; ⌘↵ registrou `Inserir e enviar · Explicar Código`; o painel fechou.
- ⌘K reabre; ESC fecha; o botão da janela de controle volta a "Abrir launcher".

### Decisões

- **Busca com `localizedStandardContains`**, não `localizedCaseInsensitiveContains`
  como sugere o PRD §9.1. O segundo diferencia acentos: `cod` não encontrava
  `Código` e `documentacao` não encontrava `Documentação`. Inaceitável em pt-BR.
- **Campo de busca em AppKit (`NSTextField`)**, não `TextField` + `@FocusState`.
  Dentro de um `NSPanel` borderless o `@FocusState` não torna o campo primeiro
  respondedor — o painel permanece como respondedor e nada é digitado.
  O foco é pedido por token a cada exibição.
- **`NSApp.activate` antes de `makeKeyAndOrderFront`.** Na ordem inversa a ativação
  devolve o foco de teclado para a janela principal.
- **Monitor local de `keyDown`** em vez de `onKeyPress`: as setas e o Enter precisam
  navegar na lista mesmo com o cursor dentro do campo de texto.
- **`isRestorable = false` no painel.** O macOS restaurava a janela do painel na
  execução seguinte, fora de tela, dessincronizando o estado.
- **Estado de visibilidade lido do painel**, não de um booleano espelhado.
- **Sem seleção por hover.** O mouse é opcional (PRD §9); clique ainda insere.
- **`hidesOnDeactivate = false`** durante a Fase 1, para inspecionar o protótipo.
  Revisitar na Fase 4, quando o painel precisa sumir ao perder o foco.

### Fora de escopo nesta story

- Editor de prompt (M04) — incluindo o botão "+ Novo Prompt" do PRD §16.
- Prompts recentes no topo (PRD §44).
- Hotkey global, SwiftData, clipboard, Accessibility, menu bar.

### Checkpoint

Aguardando aprovação visual antes do M04 — Prompt Editor.

---

## M04 — Prompt Editor (e correção de arquitetura do teclado)

**Data:** 2026-09-18
**Escopo:** PRD §12–15, §16 e §31.

### Entregue

- `PromptEditorView` + `PromptEditorViewModel`: título, categoria, conteúdo
  monoespaçado, contador de caracteres, Cancelar e Salvar.
- Salvar habilita só com título e conteúdo preenchidos; ⌘↵ salva, ESC cancela.
  Enter sem ⌘ é quebra de linha no conteúdo.
- `⌘N` dentro do launcher e item de menu "Novo Prompt" (⌘⇧P, PRD §35) abrem o editor.
- O editor substitui o launcher na tela; ao fechar, o launcher volta.
- Prompt salvo entra no topo da lista e aparece imediatamente no launcher (PRD §31).
- O modelo já aceita edição (`editingID`, rótulo "Editar Prompt"), mas a entrada
  para editar um prompt existente (PRD §15) ainda não foi ligada.

### Janela de controle removida

A janela "Promptbox — Protótipo" era andaime meu, não produto: existia para abrir
o launcher sem hotkey global e para mostrar a última ação. O app agora não tem
janela principal — a interface é o painel. Entradas: abrir o app, clicar no ícone
do Dock (`applicationShouldHandleReopen`) e ⌘K com o app ativo.

### Correção de arquitetura: teclado

O monitor global (`NSEvent.addLocalMonitorForEvents`) instalado pelo ciclo de vida
do SwiftUI **não estava instalado na primeira exibição do painel** — `onAppear` não
dispara de forma confiável para uma view hospedada em `NSHostingController` dentro
de um `NSPanel`. Sintoma: ⌘↵ não salvava na primeira vez que o editor abria.

O tratamento de teclas passou para `FloatingPanel.sendEvent(_:)`, que é chamado pelo
AppKit para todo evento destinado àquele painel. Consequências:

- Não depende de ciclo de vida de view.
- Escopo por painel é estrutural: cada painel roteia para o seu próprio modelo,
  sem filtro por identificador.
- A lógica de teclado saiu das views e foi para os view models, que passaram a ser
  criados pelo `AppEnvironment` em vez de `@State` dentro da view.

### Verificação (app rodando)

- Menu "Novo Prompt" abre o editor com o campo Título já focado.
- Tab leva ao conteúdo; contador acompanha ("35 caracteres").
- ⌘↵ salva: o editor fecha, o launcher volta e "Revisar PR" está no topo, selecionado.
- No launcher, ↓ + ↵ insere e fecha — teclado íntegro depois da refatoração.
- Build Debug sem warnings.

### Decisões

- **Categoria com `Menu` transparente por cima do campo desenhado à mão.** O `Menu`
  do macOS ignora `background`/`frame` aplicados ao seu label, e o campo saía sem
  moldura e sem chevron.
- **Campos de texto em AppKit** (`AppKitTextField`, `AppKitTextView`) pelo mesmo
  motivo do campo de busca: `@FocusState` não funciona em painel borderless.
- **`Settings { EmptyView() }`** como única cena SwiftUI: um `App` exige ao menos
  uma cena, e nenhuma janela é aberta por ela.

### Fora de escopo nesta story

- Entrada para editar prompt existente (PRD §15).
- Prompts recentes no topo (PRD §44).
- Hotkey global, SwiftData, clipboard, Accessibility, menu bar.

---

## M05 — Menu Bar (fora de ordem, a pedido)

**Data:** 2026-09-18
**Escopo:** PRD §42. Adiantado em relação à ordem do PRD §51 (seria Fase 5).

### Entregue

- `MenuBarExtra` com ícone `bolt.fill` e o menu: Buscar Prompt (⌘K),
  Novo Prompt (⇧⌘P), separador, Sair do Promptbox (⌘Q).
- Política de ativação `.accessory`: o app sai do Dock e roda em background,
  como o PRD §42 pede. A barra de menus vira a porta de entrada.
- `MenuBarExtra` é a única cena SwiftUI — a cena `Settings` foi removida.

### Verificação (app rodando)

- O item aparece na barra de menus e o menu abre com os três comandos.
- "Buscar Prompt" abre e fecha o painel.
- Com o app sem ícone no Dock, digitar `doc` no launcher ainda filtra
  (582 → 234 pt): o painel continua recebendo foco de teclado em `.accessory`.

### Decisões

- **"Configurações" ficou fora do menu.** O PRD §42 lista o item, mas não há nada
  para configurar ainda; a primeira preferência real é Launch at Login (§43).
  Um item que abre uma janela vazia é pior que a ausência dele.

### Ainda pendente para a Fase 5 completa

- Hotkey global ⌥Space (Fase 3, PRD §35) — hoje o launcher só abre pela barra de
  menus ou reabrindo o app.
- Launch at Login (§43).
- Persistência com SwiftData (Fase 2) — os prompts ainda vivem em memória e se
  perdem ao sair.

---

## Fases 2, 3 e 4 — protótipo completo

**Data:** 2026-09-18
**Escopo:** PRD §34 (persistência), §35 (hotkey global), §36–41 (inserção real),
§15 (edição), §43 (Launch at Login), §9/§44 (recentes no topo).

### Entregue

- **Hotkey global** via Carbon `RegisterEventHotKey`: ⌥Space abre/fecha a busca,
  ⇧⌘P abre o editor. Se a combinação estiver tomada, o menu avisa em vez de
  fingir que funciona.
- **Inserção real**: guarda o app anterior, copia o prompt, devolve o foco,
  envia ⌘V e — no modo enviar — Enter, e restaura o clipboard original.
- **Permissão de Acessibilidade** (§41) com alerta em pt-BR e atalho para os Ajustes.
- **Persistência com SwiftData**: os prompts sobrevivem ao encerramento.
- **Edição** (⌘E) reaproveitando o editor, e **recentes no topo**.
- **Launch at Login** no menu da barra.
- **Ícones do produto**: `docs/icone-dock.png` como ícone do app e
  `docs/icone-menubar.png` como imagem template da barra de menus.

### Bugs reais encontrados rodando o app

1. **Teclado não chegava ao painel.** Teclas do sistema só vão ao app em primeiro
   plano e, desde o macOS 14, um app `.accessory` não se ativa sozinho. O painel
   passa a `.regular` enquanto está aberto e volta a `.accessory` ao fechar.
2. **Foco do campo dependia do ciclo de vida do SwiftUI.** O painel agora escolhe
   explicitamente o primeiro `NSTextField` como primeiro respondedor, repetindo no
   ciclo seguinte do runloop.
3. **A busca não era limpa ao esconder o painel**: reabrir mostrava o termo antigo.
4. **Banco no caminho genérico do SwiftData** (`~/Library/Application Support/default.store`),
   compartilhado com qualquer outro app não-sandboxed. Movido para
   `~/Library/Application Support/Promptbox/promptbox.store`.
5. **Eventos de teclado em `cgSessionEventTap`** trocados por `cghidEventTap`, que
   entrega no nível do teclado físico — o que apps de terminal esperam.

### Verificado com o app rodando

- ⌥Space abre e fecha o launcher com outro app em primeiro plano.
- Digitar filtra a lista (painel encolhe de 582 → 176 pt com um resultado).
- Prompt criado sobrevive a encerrar e reabrir o app.
- O clipboard original é restaurado após a inserção (sentinela intacta).
- O alerta de permissão aparece quando a Acessibilidade não está autorizada.

### Não verificado de ponta a ponta

A colagem no app de destino não pôde ser confirmada por automação: o ambiente
disputava foco durante os testes e a permissão de Acessibilidade é revogada a cada
novo build (assinatura ad-hoc). Precisa de uma passada manual.

### Ainda fora

- Apagar prompt (não está no PRD).
- Hotkeys configuráveis (PRD §35 prevê "posteriormente").
- Import/Export (§47).

---

## Ajustes pós-uso real

**Data:** 2026-09-18

- **Botão "+ Novo" visível** no campo de busca do launcher, além do atalho ⌘N
  (PRD §16). O estado vazio também ganhou um botão "Criar prompt novo".
  Motivo: o usuário precisou perguntar como criar um prompt — a dica no rodapé
  não bastava. O rodapé voltou a mostrar "↑↓ Navegar", como na referência.
- **Ícone do app corrigido.** A primeira tentativa de gerar os tamanhos usou um
  laço `for` com `set --`, que não separa palavras no zsh: nenhum arquivo foi
  escrito com o nome certo e o app continuou com o ícone provisório.
  Agora os dez tamanhos saem de `docs/icone-dock.png`.

### Nota sobre permissão de Acessibilidade

Sem certificado de assinatura na keychain, o app é assinado em modo ad-hoc e cada
build muda a identidade que o TCC reconhece — a autorização precisa ser refeita a
cada compilação. Um certificado autoassinado resolveria, ao custo de um prompt de
senha de administrador.

---

## Ícone por prompt e exclusão

**Data:** 2026-09-18

### Entregue

- **Seletor de ícone no editor**: grade de 16 SF Symbols (`PromptSymbols`), gravada
  em `Prompt.symbol`. Tocar no ícone já selecionado volta ao ícone da categoria —
  sem uma opção extra de "automático" na interface. O ícone do cabeçalho do editor
  reflete a escolha na hora.
- **Exclusão** por ⌘⌫ no launcher e por botão "Excluir" no editor em modo edição,
  ambos com confirmação. O botão padrão do alerta é **Cancelar** e o Excluir é
  marcado como destrutivo: um Enter distraído não apaga prompt.
- Depois de excluir, a seleção é reajustada para não ficar fora do intervalo.

### Decisão: menu de contexto em vez de mais atalhos no rodapé

Com Editar e Excluir no rodapé, os rótulos quebravam em duas linhas a 680 pt.
As duas ações foram para um menu de contexto na linha do prompt (Inserir, Inserir
e enviar, Editar, Excluir), que é o caminho nativo do macOS e mostra os atalhos.
O rodapé voltou aos quatro itens da referência.

### Verificado

- O editor abre com a grade de ícones e o campo Título já focado.
- ⌘⌫ abre a confirmação e, sem confirmar, nenhum prompt é removido.
- Rodapé sem quebra de linha, igual ao mockup.

### Correção: confirmação abria atrás do painel

O launcher e o editor ficam no nível `.floating`. Um `NSAlert` nasce no nível
normal, então a confirmação de exclusão (e o alerta de permissão) abriam **atrás**
do painel. `NSAlert.runAbovePanels()` eleva a janela do alerta para `.modalPanel`
antes de exibir.

Não consegui validar por automação: com a máquina em uso, o foco de teclado não
chega ao painel durante os testes roteirizados. Precisa de uma passada manual
(⌘⌫ com um prompt selecionado).

---

## Passada de qualidade

**Data:** 2026-09-18
**Escopo:** os 25 pontos levantados na revisão de arquitetura e código.

### Bugs corrigidos

1. **Semeadura marcava sucesso sem ter salvado.** A flag em `UserDefaults` era
   gravada fora da verificação de sucesso: uma falha na primeira gravação deixaria
   o app permanentemente vazio. Agora a flag só entra depois do `save()` dar certo,
   e uma falha faz `rollback()` para tentar de novo na próxima execução.
2. **Excluir pelo editor usava o prompt digitado.** O `delete()` montava um prompt
   a partir do formulário, então renomear e clicar Excluir mostrava o título novo
   na confirmação enquanto apagava o registro antigo. O view model passou a guardar
   o prompt original inteiro.
3. **Fechar o editor sempre abria o launcher.** Agora a origem é registrada: aberto
   por ⇧⌘P de fora, fechar não abre nada.
4. **O painel não sumia ao trocar de app** (PRD §4.3). O launcher some quando o app
   perde o foco; o editor fica, porque pode ter texto não salvo.
5. **Corrida na restauração do clipboard.** Duas inserções em menos de 800 ms
   disputavam o mesmo backup. A inserção em voo agora é cancelada e o clipboard
   original é preservado até a última restauração.
6. **Temporização cega.** Os `sleep` fixos deram lugar a espera pela ativação real
   do app de destino, com timeout, e o retorno de `activate()` é verificado.

### Arquitetura

- `AppEnvironment` virou `AppCoordinator`, com `Dialogs` (alertas) e
  `ActivationPolicy` (política de ativação) como donos próprios.
- Os view models deixaram de conhecer AppKit: recebem `KeyStroke`, um valor puro.
- Closures opcionais viraram protocolos de delegate — contrato verificado pelo compilador.
- `PromptRecord` ganhou `VersionedSchema` e plano de migração.
- `touchedAt` virou coluna: a ordenação por recentes acontece no banco.

### Qualidade

- **Target de testes** com 25 testes (busca, seleção, atalhos, editor, store).
- **CI no GitHub Actions**: testes e build Release a cada PR.
- `os.Logger` no lugar de `print`/`NSLog`, com dados do usuário marcados `.private`.
- Strings de interface centralizadas com `String(localized:)` e catálogo criado.
- Rótulos de acessibilidade nas linhas, botões e campos.
- `⌘1…⌘9` passaram a ler o código físico da tecla, não o caractere.
- Removido código morto (`_ = context`, `toggle()` sem uso, `@State` só escrito),
  renomeado `record` ambíguo, cache de resultados por revisão do store.

### Achado durante a verificação

**O build Release estava quebrado** — e ninguém saberia sem CI. O otimizador SIL do
Swift 6.3 quebra ao compilar o destrutor de `FloatingPanelController` quando a
classe é genérica (`EarlyPerfInliner`). Só o inicializador precisava do parâmetro
de tipo; a classe deixou de ser genérica e o Release voltou a compilar.

### Verificado

- 25 testes passando; build Debug e Release sem warnings.
- App rodando com os dados reais do usuário: a migração de schema com a coluna nova
  preservou os 4 prompts existentes.
- ⌥Space, busca e inserção continuam funcionando depois da refatoração.

### Portabilidade de toolchain (descoberto pelo CI)

O runner do GitHub usa Xcode 16.4 / Swift 6.1, e o projeto dependia de
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, ajuste que só existe a partir do
Swift 6.2. O app compilava nesta máquina (Xcode 26.5) e quebrava lá.

A correção foi tornar o isolamento explícito em vez de exigir um toolchain novo:
`AppDelegate` ganhou `@MainActor` — os demais tipos já declaravam o seu. Com o
ajuste fora, as marcações `nonisolated` nos tipos de valor puderam sair: elas
existiam apenas para desfazer o isolamento imposto pelo projeto.

Decisão: o Promptbox compila de Swift 6.1 em diante, sem depender de recursos
do toolchain mais recente.

### Regressão: o launcher se escondia sozinho ao abrir

O "sumir ao trocar de app" foi implementado reagindo a `applicationDidResignActive`.
Só que trocar a política de ativação de `.accessory` para `.regular` — necessário
para o painel receber teclado — faz o app piscar inativo. O resultado: o painel
abria e se escondia no mesmo instante, e nada era inserido no app de destino.

Duas correções:

- a política passa a ser ajustada **antes** de exibir o painel, ordem que já
  existia antes da refatoração;
- o gatilho deixou de ser "este app perdeu o foco" e passou a ser
  `NSWorkspace.didActivateApplicationNotification` filtrando o próprio bundle —
  ou seja, "**outro** app assumiu o primeiro plano". O piscar da troca de política
  não ativa outro app, então não há falso positivo.

Uma primeira tentativa, de confirmar `NSApp.isActive` no ciclo seguinte, não
resolveu: no momento da checagem o app ainda constava inativo.

Lição: reagir à perda de foco é ambíguo, porque o próprio app provoca perdas de
foco transitórias. Reagir à ativação de outro app é o evento que de fato descreve
a intenção do usuário.
