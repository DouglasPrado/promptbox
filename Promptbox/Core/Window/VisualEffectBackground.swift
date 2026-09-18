import AppKit
import SwiftUI

/// Blur real atrás da janela. O material do SwiftUI só mistura dentro da própria
/// janela; para o efeito sobre o app que está atrás é preciso `NSVisualEffectView`
/// com `blendingMode = .behindWindow` (PRD §19.2).
struct VisualEffectBackground: NSViewRepresentable {

    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
