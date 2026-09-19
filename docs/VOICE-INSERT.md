# Voice Insert — PromptBox

## Visão geral

O **Voice Insert** permite falar um prompt e inserir a transcrição diretamente no campo que estava focado no macOS.

Fluxo principal:

```text
Claude Code / Codex / Terminal com input focado
↓
⌥ V
↓
PromptBox começa a gravar imediatamente
↓
usuário fala
↓
⌃ Enter
↓
transcrição é finalizada
↓
overlay fecha
↓
texto é inserido no input anterior
```

Cancelamento:

```text
Esc
↓
parar gravação
↓
descartar transcrição
↓
fechar overlay
↓
não inserir nada
```

A funcionalidade deve ser percebida como um **atalho de voz para o campo atualmente focado**, não como um gravador de áudio.

---

## Objetivo

Reduzir o caminho entre pensar em um comando e colocá-lo no Claude Code, Codex ou qualquer outro input.

```text
pensar
↓
falar
↓
inserir
```

Sem abrir editor, copiar manualmente ou trocar de aplicação.

---

## Atalhos

| Atalho | Ação |
|---|---|
| `⌥ V` | Iniciar Voice Insert e começar a gravar |
| `⌃ Enter` | Finalizar e inserir o texto |
| `⌃ ⇧ Enter` | Finalizar, inserir e enviar |
| `Esc` | Cancelar e descartar tudo |

`⌃ Enter` deve ser a ação padrão de confirmação. O texto é inserido, mas não enviado automaticamente.

---

## Interface

O overlay deve ser pequeno e discreto.

```text
┌─────────────────────────────────────────────┐
│ ● Gravando...  00:08  ▂▄▆▃▇▅   ⌃↵ Inserir │
│                                   Esc       │
└─────────────────────────────────────────────┘
```

Características:

- janela flutuante;
- fundo translúcido;
- blur nativo do macOS;
- sem título;
- sem textarea grande;
- sem modal central pesado;
- timer;
- waveform discreta;
- indicação de confirmar e cancelar.

### Estado processando

Depois de `⌃ Enter`:

```text
┌────────────────────────────┐
│ ◌ Transcrevendo...         │
└────────────────────────────┘
```

### Estado de erro

```text
┌──────────────────────────────────────┐
│ Não foi possível transcrever o áudio │
└──────────────────────────────────────┘
```

---

## Stack

### Captura de áudio

Usar:

```text
AVFoundation
```

Principalmente:

```text
AVAudioEngine
AVAudioInputNode
```

### Transcrição

A primeira versão usará o framework nativo:

```text
Speech
```

Com:

```text
SFSpeechRecognizer
SFSpeechAudioBufferRecognitionRequest
SFSpeechRecognitionTask
```

Fluxo:

```text
Microfone
↓
AVAudioEngine
↓
Speech
↓
Transcrição
↓
TextInjector
↓
Input focado
```

---

## Provider de transcrição

A implementação deve ser desacoplada.

```swift
protocol TranscriptionProvider {
    func start() throws
    func stop() async throws -> String
    func cancel()
}
```

Primeiro provider:

```text
AppleSpeechProvider
```

Arquitetura preparada para:

```text
TranscriptionProvider
├── AppleSpeechProvider
├── WhisperLocalProvider
└── CloudTranscriptionProvider
```

Isso permite trocar o mecanismo de reconhecimento sem alterar a UX.

---

## Apple Speech

Configuração inicial:

```text
Idioma: pt-BR
Resultados parciais: habilitados
On-device: preferencial quando suportado
```

Quando disponível, o reconhecimento local deve ser preferido.

O app não deve assumir que o reconhecimento on-device está disponível em todos os Macs ou idiomas.

---

## Vocabulário técnico

Como o uso principal envolve desenvolvimento, o reconhecimento deve receber termos contextuais quando possível.

Exemplos:

```text
Claude
Claude Code
Codex
Context7
Next.js
NestJS
SwiftUI
AppKit
Prisma
Postgres
pnpm
npm
GitHub
Docker
TypeScript
```

Exemplo:

```swift
request.contextualStrings = [
    "Claude",
    "Claude Code",
    "Codex",
    "Context7",
    "Next.js",
    "NestJS",
    "SwiftUI",
    "AppKit",
    "Prisma",
    "Postgres",
    "pnpm",
    "GitHub"
]
```

---

## Transcrição parcial

Resultados parciais podem ser usados somente para feedback visual.

```text
"revise a..."
↓
"revise a implementação..."
↓
"revise a implementação dessa story..."
```

O texto **não deve ser inserido em tempo real no app externo**.

O reconhecedor pode corrigir hipóteses anteriores, então a inserção deve acontecer apenas quando a transcrição final estiver pronta.

---

## Overlay nativo

Usar:

```text
NSPanel
```

Preferencialmente:

```text
.nonactivatingPanel
```

Objetivo: mostrar o overlay sem transformar o PromptBox em uma janela convencional.

Estrutura:

```text
VoiceOverlayPanel
↓
NSHostingView
↓
VoiceOverlayView
```

---

## Contexto do destino

Antes da gravação, registrar onde o texto deverá ser inserido.

```swift
struct TargetContext {
    let application: NSRunningApplication
    let focusedElement: AXUIElement?
}
```

Capturar:

- aplicação atualmente ativa;
- elemento focado quando disponível.

Isso é especialmente importante em:

- Terminal;
- Ghostty;
- iTerm;
- Cursor;
- VS Code;
- terminais integrados;
- aplicações com múltiplos campos.

---

## Injeção de texto

A estratégia principal deve ser colagem.

```text
texto final
↓
salvar clipboard atual
↓
colocar transcrição no clipboard
↓
reativar app de destino
↓
Cmd + V
↓
restaurar clipboard
```

Tecnologias:

```text
NSPasteboard
NSRunningApplication
CGEvent
Accessibility API
```

O Voice Insert deve reutilizar o mesmo `TextInjector` dos prompts salvos.

---

## TextInjector compartilhado

```text
Prompt salvo ─────┐
                  │
Voice Insert ─────┼──→ TextInjector
                  │
futuras ações ────┘
```

Interface sugerida:

```swift
protocol TextInjecting {
    func insert(
        _ text: String,
        into context: TargetContext
    ) async throws

    func insertAndSend(
        _ text: String,
        into context: TargetContext
    ) async throws
}
```

---

## Comportamento do Esc

`Esc` deve ter prioridade durante a gravação.

Não deve:

- perguntar confirmação;
- salvar rascunho;
- modificar clipboard;
- inserir texto;
- manter áudio.

Deve apenas:

```text
parar
+
descartar
+
fechar
```

---

## Permissões

O recurso exige:

```text
Microphone
Speech Recognition
Accessibility
```

### Microfone

Necessário para capturar áudio.

### Speech Recognition

Necessário para usar o reconhecimento do framework Speech.

### Accessibility

Necessário para inserir texto e restaurar corretamente o contexto em outros aplicativos.

---

## Privacidade

Princípios:

- não armazenar áudio por padrão;
- não criar gravações persistentes;
- descartar áudio após reconhecimento;
- não manter histórico de voz;
- não enviar transcrição para backend próprio;
- não usar áudio para analytics;
- não exigir conta.

Se um provider cloud for adicionado futuramente, isso deverá ser informado explicitamente.

---

## Estados

```swift
enum VoiceInsertState {
    case idle
    case requestingPermission
    case recording
    case finalizing
    case inserting
    case completed
    case cancelled
    case failed(Error)
}
```

Fluxo normal:

```text
idle
↓
recording
↓
finalizing
↓
inserting
↓
completed
```

Cancelamento:

```text
recording
↓
cancelled
↓
idle
```

---

## Estrutura de código

```text
Features/
└── VoiceInsert/
    ├── VoiceInsertController.swift
    ├── VoiceInsertViewModel.swift
    │
    ├── UI/
    │   ├── VoiceOverlayPanel.swift
    │   ├── VoiceOverlayView.swift
    │   └── WaveformView.swift
    │
    ├── Audio/
    │   └── AudioRecorder.swift
    │
    └── Transcription/
        ├── TranscriptionProvider.swift
        └── AppleSpeechProvider.swift
```

Compartilhado:

```text
Core/
├── Hotkeys/
│   └── GlobalHotkeyManager.swift
├── Injection/
│   └── TextInjector.swift
├── Clipboard/
│   └── ClipboardManager.swift
└── Accessibility/
    └── AccessibilityManager.swift
```

---

## VoiceInsertController

Responsável por coordenar:

```text
Global Hotkey
↓
VoiceInsertController
├── TargetContext
├── AudioRecorder
├── TranscriptionProvider
├── Overlay
└── TextInjector
```

Exemplo conceitual:

```swift
func startVoiceInsert() async {
    target = captureCurrentTarget()
    showOverlay()
    try transcription.start()
}

func confirm() async {
    let text = try await transcription.stop()
    hideOverlay()
    try await textInjector.insert(text, into: target)
}

func cancel() {
    transcription.cancel()
    hideOverlay()
    target = nil
}
```

---

## Casos especiais

### Nenhuma fala detectada

```text
⌥ V
↓
silêncio
↓
⌃ Enter
```

Não inserir texto vazio.

Feedback:

```text
Nenhuma fala detectada
```

### Duração máxima

Sugestão inicial:

```text
5 minutos
```

Voice Insert é para ditado rápido, não gravação longa.

### Múltiplos monitores

O overlay deve aparecer no monitor onde está a aplicação atualmente focada.

### Fullscreen / Spaces

O overlay deve conseguir aparecer sobre a aplicação ativa e acompanhar o contexto correto.

---

## Fases de implementação

### Fase 1 — Protótipo visual

Implementar apenas:

- overlay;
- timer;
- waveform simulada;
- estados;
- atalhos locais;
- `Esc`;
- `⌃ Enter`;
- texto mockado.

Objetivo: validar UX.

### Fase 2 — Captura real

Adicionar:

```text
AVAudioEngine
```

Validar início, parada, cancelamento e erros do microfone.

### Fase 3 — Apple Speech

Adicionar:

```text
AppleSpeechProvider
```

Validar:

- pt-BR;
- resultados parciais;
- resultado final;
- vocabulário técnico;
- reconhecimento local quando disponível.

### Fase 4 — Text Injection

Integrar:

```text
TargetContext
+
TextInjector
```

Fluxo completo:

```text
⌥ V
↓
falar
↓
⌃ Enter
↓
texto aparece no input anterior
```

### Fase 5 — Polish

Validar:

- latência;
- posição do overlay;
- feedback visual;
- comportamento em fullscreen;
- múltiplos monitores;
- diferentes terminais e IDEs.

---

## Casos de teste

Testar em:

```text
Terminal.app
Ghostty
iTerm2
Warp
Cursor
VS Code
TextEdit
Safari
```

Cenários:

```text
input vazio
input com texto
cursor no meio do texto
terminal integrado
fullscreen
outro Space
múltiplos monitores
clipboard com texto
clipboard com imagem
cancelamento imediato
```

---

## Critérios de aceitação

Voice Insert está pronto quando:

- `⌥ V` começa a gravação;
- overlay aparece rapidamente;
- áudio começa a ser capturado imediatamente;
- `Esc` cancela sem inserir nada;
- `⌃ Enter` finaliza a fala;
- a transcrição é gerada;
- overlay fecha;
- aplicativo anterior recupera o contexto;
- texto é inserido corretamente;
- clipboard original é restaurado;
- nenhum áudio fica persistido;
- funciona em Claude Code e Codex.

---

## Métricas

Objetivo para abertura:

```text
tempo entre ⌥ V e poder começar a falar
< 500 ms
```

Objetivo para confirmação:

```text
⌃ Enter
↓
transcrição final
↓
texto no input

percepção de resposta quase imediata
```

A latência final dependerá do mecanismo de reconhecimento.

---

## Evolução futura — Whisper local

Se Apple Speech não tiver precisão suficiente para linguagem técnica:

```text
Apple Speech
↓
avaliar precisão
↓
Whisper Local
```

A arquitetura com providers permite essa troca sem alterar o restante do Voice Insert.

---

## Evolução futura — Voice Prompt

Voice Insert permanece literal:

```text
fala
↓
transcrição
```

Um modo futuro poderá usar IA:

```text
fala natural
↓
transcrição
↓
LLM
↓
prompt estruturado
↓
inserção
```

Exemplo falado:

```text
pede pro claude revisar tudo que ele fez
e ver se não quebrou nada
```

Resultado possível:

```text
Revise completamente a implementação realizada.

- analise as alterações;
- verifique possíveis regressões;
- execute os testes relevantes;
- corrija problemas encontrados;
- apresente um resumo final.
```

Essa transformação por IA não faz parte da V1.

---

## Fora do escopo inicial

Não implementar inicialmente:

- gravações salvas;
- histórico de áudio;
- edição de áudio;
- reuniões;
- diarização;
- múltiplos speakers;
- tradução;
- geração automática de prompt;
- upload de áudio;
- sincronização cloud;
- streaming palavra por palavra para o input externo.

---

## Resumo final

```text
⌥ V
→ começar a falar

⌃ Enter
→ finalizar e inserir

⌃ ⇧ Enter
→ finalizar, inserir e enviar

Esc
→ cancelar
```

Arquitetura:

```text
GlobalHotkeyManager
        ↓
VoiceInsertController
        ↓
AudioRecorder
        ↓
TranscriptionProvider
        ↓
AppleSpeechProvider
        ↓
TextInjector
        ↓
Aplicativo focado
```

Princípio da funcionalidade:

> Falar deve ser tão simples quanto colar um texto.
