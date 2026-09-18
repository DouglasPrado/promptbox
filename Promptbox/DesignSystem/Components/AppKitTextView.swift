import AppKit
import SwiftUI

/// Área de texto multilinha em AppKit, monoespaçada, para o conteúdo do prompt
/// (PRD §20). Mesmo motivo do `AppKitTextField`: dentro de um painel borderless
/// o foco precisa ser pedido explicitamente.
struct AppKitTextView: NSViewRepresentable {

    @Binding var text: String
    var focusToken: Int = 0

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor(Palette.textPrimary)
        textView.insertionPointColor = NSColor(Palette.textPrimary)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isRichText = false
        textView.allowsUndo = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        guard context.coordinator.lastFocusToken != focusToken else { return }
        context.coordinator.lastFocusToken = focusToken

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {

        var lastFocusToken = -1
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
