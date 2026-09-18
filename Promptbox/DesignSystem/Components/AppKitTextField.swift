import AppKit
import SwiftUI

/// Campo de texto de uma linha em AppKit.
///
/// `@FocusState` não torna um campo SwiftUI primeiro respondedor dentro de um
/// `NSPanel` borderless — o painel permanece como respondedor e nada é digitado.
/// O foco é pedido por token: cada incremento é um novo pedido, o que permite
/// refocar quando o painel é reexibido sem recriar a view.
struct AppKitTextField: NSViewRepresentable {

    @Binding var text: String
    var placeholder: String = ""
    var fontSize: CGFloat = 13.5
    var focusToken: Int = 0

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: fontSize, weight: .regular)
        field.textColor = NSColor(Palette.textPrimary)
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        applyPlaceholder(to: field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }

        guard context.coordinator.lastFocusToken != focusToken else { return }
        context.coordinator.lastFocusToken = focusToken

        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    private func applyPlaceholder(to field: NSTextField) {
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: NSColor(Palette.textTertiary)
            ]
        )
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {

        var lastFocusToken = -1
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
