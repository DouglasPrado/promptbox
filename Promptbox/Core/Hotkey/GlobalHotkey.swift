import AppKit
import Carbon.HIToolbox

/// Atalho global registrado via Carbon.
///
/// `NSEvent.addGlobalMonitorForEvents` exigiria permissão de Acessibilidade e
/// não consegue consumir o evento — a tecla chegaria também ao app da frente.
/// `RegisterEventHotKey` não exige permissão e consome a combinação.
@MainActor
final class GlobalHotkey {

    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private let id: UInt32
    private var reference: EventHotKeyRef?

    /// Retorna `nil` quando a combinação já está tomada por outro app.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        Self.installHandlerIfNeeded()

        id = Self.nextID
        Self.nextID += 1

        let hotKeyID = EventHotKeyID(signature: OSType(0x50_42_4F_58), id: id) // 'PBOX'
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &reference
        )

        guard status == noErr else { return nil }
        Self.actions[id] = action
    }

    /// Libera a combinação. Necessário para trocar o atalho em tempo de execução,
    /// que é o próximo passo previsto para a configuração (PRD §35).
    func unregister() {
        if let reference {
            UnregisterEventHotKey(reference)
            self.reference = nil
        }

        Self.actions[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                // O handler do Carbon roda na thread principal.
                MainActor.assumeIsolated {
                    GlobalHotkey.actions[hotKeyID.id]?()
                }
                return noErr
            },
            1,
            &spec,
            nil,
            nil
        )
    }
}

/// Combinações usadas pelo Promptbox (PRD §35).
enum Hotkey {
    static let launcherKey = UInt32(kVK_Space)
    static let launcherModifiers = UInt32(optionKey)

    static let editorKey = UInt32(kVK_ANSI_P)
    static let editorModifiers = UInt32(cmdKey | shiftKey)
}
