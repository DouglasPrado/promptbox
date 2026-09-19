<p align="center">
  <img src="./assets/promptbox-logo.png" width="420" alt="Promptbox" />
</p>

<p align="center">
  <strong>Reusable prompts, one keystroke away from whatever you are typing in.</strong>
</p>

<p align="center">
  Promptbox is a native macOS launcher that stores the prompts you keep rewriting and
  inserts them straight into the app you were already working in — Claude Code, Codex,
  OpenCode, Ghostty, iTerm, Warp, Cursor or VS Code. Press <code>⌥V</code> and it does
  the same with your voice.
</p>

<p align="center">
  Built with <strong>Swift 6, SwiftUI and AppKit</strong>.
</p>

<p align="center">
  <a href="https://github.com/DouglasPrado/promptbox/actions/workflows/ci.yml">
    <img src="https://github.com/DouglasPrado/promptbox/actions/workflows/ci.yml/badge.svg" alt="CI" />
  </a>
</p>

---

<p align="center">
  <img src="./assets/promptbox-launcher.png" alt="Promptbox launcher running on macOS" width="720" />
</p>

## What is Promptbox?

Promptbox is a floating launcher for text you reuse.

It is not an IDE, an AI client, a workflow engine or a terminal. It does one loop:

```text
Save text  →  Find text  →  Insert text
```

Press `⌥Space` anywhere, type a few letters, press `↵`. The panel disappears, the app
you came from gets focus back, and the prompt is pasted where your cursor already was.

Promptbox never talks to Claude, Codex or any model. It is an independent layer between
you and whatever app is in front.

---

## Why Promptbox?

Prompts you use every day end up scattered across Markdown files, notes, shell history,
chat threads, the clipboard and memory. Reusing one looks like this:

```text
remember where the prompt is
↓
open the file
↓
find the text
↓
select
↓
copy
↓
switch back to the terminal
↓
paste
```

Promptbox turns that into:

```text
⌥Space
↓
type
↓
↵
```

The context you were in is never lost. The panel floats above the current app and
vanishes as soon as it has done its job.

---

# Features

### Global launcher

`⌥Space` opens and closes the launcher from any application. The hotkey is registered
through Carbon `RegisterEventHotKey`, so it does not require Accessibility permission
and it consumes the combination instead of leaking it to the app in front.

If another app already owns `⌥Space`, the menu bar says so instead of pretending the
shortcut exists.

### Search that forgives accents

Typing filters by **title, description, content and category**. Matching is
case- *and* diacritic-insensitive, which matters in Portuguese: `cod` finds `Código`
and `documentacao` finds `Documentação`.

Recently used prompts come first.

### Insert into the app you came from

The panel records which application was in front before it opened. On `↵` it:

```text
save the current clipboard
↓
copy the prompt
↓
give focus back to the previous app
↓
send ⌘V
↓
restore the original clipboard
```

The clipboard you had is preserved, including non-text items.

`⌘↵` does the same and then sends `↵`, for when you want the prompt to run immediately.
Plain insert is the default on purpose: you get to read the text before Claude, Codex or
your shell receives it.

### Voice Insert

<p align="center">
  <img src="./assets/promptbox-voice.png" alt="Promptbox Voice Insert overlay" width="620" />
</p>

`⌥V` starts recording immediately. Speak, press `⌃↵`, and the transcription lands in the
field you were already typing in. `⌃⇧↵` inserts and sends. `esc` stops, discards and
closes — no confirmation, no draft, no clipboard change.

It is a voice shortcut for the focused field, not a recorder. The overlay is a thin
translucent bar with a timer and a live waveform, and nothing else: no text area, no
play button, nothing to click.

Transcription runs through `SFSpeechRecognizer` in pt-BR, with a list of technical terms
(`Claude Code`, `Context7`, `Next.js`, `pnpm`, `TypeScript`…) fed in as context so they
survive a Portuguese recognizer. On-device recognition is preferred; when it is not
usable the same session continues through Apple's servers without you noticing.

Partial results drive the feedback only. The recognizer revises what it already said, so
nothing reaches the target app until the final transcription is ready. Audio is never
written to disk, and silence inserts nothing.

The mechanism sits behind a `TranscriptionProvider` protocol, so swapping Apple Speech
for a local Whisper or a cloud service does not touch the overlay, the shortcuts or the
insertion.

> [!NOTE]
> On-device recognition needs **Dictation** enabled in
> `System Settings → Keyboard → Dictation`. With it off, the local recognizer fails
> immediately (`kLSRErrorDomain 201`) even when the language model is installed, and
> Promptbox falls back to server recognition for that session.

### Prompt editor

<p align="center">
  <img src="./assets/promptbox-editor.png" alt="Promptbox prompt editor" width="560" />
</p>

A small floating form: title, category, icon and content. The content field is
monospaced, with a live character count. `⌘↵` saves, `esc` cancels, and plain `↵`
stays a line break inside the content.

The same component handles editing, so a prompt you already saved opens prefilled.

### Icons and categories

Each prompt carries an SF Symbol picked from a short grid, or inherits the icon of its
category. Categories are plain labels — Desenvolvimento, Review, Documentação,
Planejamento, Git, DevOps, Design, Outros — used for filtering and color.

No external icon library: SF Symbols only.

### Menu bar app

<p align="center">
  <img src="./assets/promptbox-menubar-icon.png" width="28" alt="Promptbox menu bar icon" />
</p>

Promptbox runs in the background with no Dock icon. The menu bar item offers Buscar
Prompt, Novo Prompt, an **Abrir ao iniciar o Mac** toggle and Sair.

### Local-first storage

Prompts live in SwiftData, on your Mac:

```text
~/Library/Application Support/Promptbox/promptbox.store
```

No account, no server, no sync, no telemetry. The first launch seeds eight example
prompts; after that the file is yours.

---

# Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌥Space` | Open or close the launcher, from anywhere |
| `⌥V` | Start Voice Insert, from anywhere (again to cancel) |
| `⇧⌘P` | Open the prompt editor, from anywhere |
| `↑` `↓` | Move the selection |
| `↵` | Insert into the previous app |
| `⌘↵` | Insert and send |
| `⌘1`…`⌘9` | Insert the nth result directly |
| `⌘N` | New prompt |
| `⌘E` | Edit the selected prompt |
| `⌘⌫` | Delete the selected prompt (asks for confirmation) |
| `esc` | Close |

While Voice Insert is recording:

| Shortcut | Action |
| --- | --- |
| `⌃↵` | Finish and insert |
| `⌃⇧↵` | Finish, insert and send |
| `esc` | Cancel and discard |

Right-clicking a row opens a context menu with the same actions.

---

# Permissions

Inserting text into another application requires **Accessibility**:

```text
System Settings → Privacy & Security → Accessibility → Promptbox
```

Promptbox asks for it the first time an insert is attempted and offers to open the right
settings pane. Search, editing and storage all work without it — only the paste needs it.

Voice Insert additionally requires **Microphone** and **Speech Recognition**:

```text
System Settings → Privacy & Security → Microphone → Promptbox
System Settings → Privacy & Security → Speech Recognition → Promptbox
```

Both are asked for on the first `⌥V`, before the overlay appears. If either is denied,
Promptbox says which one and opens the matching pane. Everything else keeps working.

> [!NOTE]
> macOS derives the Accessibility grant from the code signature. Xcode signs local builds
> ad-hoc, which produces a different identity on every build — the toggle stays on in
> System Settings while pointing at the previous binary.
>
> `./scripts/sign-local.sh build/Promptbox.app` creates a local signing certificate once
> and reuses it, so the grant survives rebuilds. Run it after each build, or grant the
> permission again every time.

---

# Architecture

```text
Promptbox/
├── App/
│   ├── PromptboxApp.swift      MenuBarExtra, the only SwiftUI scene
│   ├── AppDelegate.swift       activation policy, global hotkeys
│   └── AppEnvironment.swift    owns the models and both panels
│
├── Core/
│   ├── Window/                 FloatingPanel, controller, activation policy
│   ├── Input/                  KeyStroke, the AppKit-free keyboard type
│   ├── Hotkey/                 Carbon global hotkey
│   ├── Insertion/              clipboard, focus handoff, ⌘V
│   ├── Permissions/            microphone and speech recognition
│   ├── Dialogs.swift           modal alerts
│   ├── Log.swift               os.Logger channels
│   └── LoginItem.swift         launch at login
│
├── Features/
│   ├── Launcher/               search field, rows, footer, view model
│   ├── PromptEditor/           form, icon grid, view model
│   └── VoiceInsert/            overlay, waveform, audio capture, transcription
│
├── Models/                     Prompt, PromptStore, PromptRecord (SwiftData)
├── Mocks/                      the eight seeded prompts
├── DesignSystem/               Palette, Typography, Metrics, components
└── Resources/                  asset catalog, strings

PromptboxTests/                 view models, store and keyboard logic
```

`AppCoordinator` owns navigation and nothing else: services never reach into the
UI, alerts live in `Dialogs`, and the activation policy has a single owner. View
models talk to it through delegate protocols, so a missing wire is a compile
error instead of a silently dead feature.

There is **no main window**. The interface is an `NSPanel` hosting SwiftUI through
`NSHostingController`, which is what gives the launcher its Spotlight-like behaviour:
borderless, floating, blurred, centered above the current app.

Key events are intercepted in `FloatingPanel.sendEvent(_:)` rather than through a global
event monitor, so each panel routes keys to its own view model without depending on
SwiftUI lifecycle callbacks.

---

# Requirements

For users:

```text
macOS 15 or later
```

For development:

```text
Xcode 16 or later
Swift 6
```

---

# Development

Open the project in Xcode:

```bash
open Promptbox.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project Promptbox.xcodeproj \
           -scheme Promptbox \
           -configuration Debug \
           build
```

Run the tests:

```bash
xcodebuild test \
  -project Promptbox.xcodeproj \
  -scheme Promptbox \
  -destination 'platform=macOS'
```

The app target has no external dependencies — SwiftUI, AppKit, SwiftData, Carbon and
ApplicationServices only.

The view models take a plain `KeyStroke` value instead of `NSEvent`, so search
matching, selection wrap-around, shortcut dispatch and store CRUD are all covered
by unit tests that need no window server. CI runs them on every pull request.

---

# Design decisions

### A non-activating panel, not a window

The launcher is an `NSPanel` with `.borderless` and `.nonactivatingPanel`. It becomes
key without the app ever owning a normal window, and the activation policy flips to
`.regular` only while the panel is open, so keyboard events reach it on macOS 14+, where
a background app cannot activate itself.

### AppKit text fields inside a SwiftUI panel

`@FocusState` does not make a SwiftUI `TextField` first responder inside a borderless
panel — the panel stays the responder and typing goes nowhere. The search field and the
editor fields are `NSTextField` and `NSTextView` wrapped for SwiftUI, and the panel picks
the first responder explicitly when it opens.

### Paste through `cghidEventTap`

The `⌘V` is posted at HID level, the same path a physical keyboard takes. Terminals
ignore events posted at higher taps.

### Its own store path

SwiftData defaults to `~/Library/Application Support/default.store`, which every
non-sandboxed SwiftData app shares. Promptbox writes to its own folder instead.

### Digits by key code, not by character

`⌘1`…`⌘9` read the physical key code. Reading the typed character breaks on
layouts where a digit requires Shift, such as French AZERTY.

### Audio setup never touches the main thread

`AVAudioNode.inputFormat(forBus:)` and `AVAudioEngine.start()` `dispatch_sync` into
CoreAudio and sit in a `mach_msg` until `coreaudiod` answers. With an aggregate audio
device, enumerating sub-devices takes *seconds*. Run from the main actor, that froze the
whole app — including `⌥Space`, which has nothing to do with voice. `AudioRecorder` owns
a serial queue and nothing else talks to the engine.

### No sandbox

Reading the frontmost application, posting keyboard events and restoring the clipboard
are incompatible with the App Sandbox.

---

# Status

Promptbox is a working prototype. The full loop — hotkey, search, insert, save, edit,
delete, persistence — is implemented and working end to end. Voice Insert is in, with
Apple Speech as the first transcription provider.

Not built yet:

```text
tags
favorites
prompt variables and templates
import / export
configurable shortcuts
local Whisper provider
voice prompt (speech → LLM → structured prompt)
iCloud or any kind of sync
```

The product boundary is deliberate:

> Open. Search. Insert.
>
> Or: speak. Insert.
