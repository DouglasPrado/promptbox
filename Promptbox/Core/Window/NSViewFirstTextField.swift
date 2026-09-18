import AppKit

extension NSView {

    /// Primeiro `NSTextField` da hierarquia, em profundidade.
    /// Usado para dar o foco inicial ao painel sem depender do SwiftUI.
    func firstTextField() -> NSTextField? {
        if let field = self as? NSTextField { return field }

        for subview in subviews {
            if let field = subview.firstTextField() { return field }
        }

        return nil
    }
}
