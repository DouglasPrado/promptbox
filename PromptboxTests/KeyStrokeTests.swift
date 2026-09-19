import Testing

@testable import Promptbox

@Suite("KeyStroke")
struct KeyStrokeTests {

    @Test("Dígitos vêm do código físico, não do caractere")
    func digitsComeFromKeyCode() {
        // Num layout onde o dígito exige Shift, o caractere seria "&" e não "7".
        let seven = KeyStroke(code: KeyCode.digits[6], modifiers: .command, characters: "&")
        #expect(seven.digit == 7)

        let first = KeyStroke(code: KeyCode.digits[0], modifiers: .command, characters: "1")
        #expect(first.digit == 1)
    }

    @Test("Tecla sem dígito não vira número")
    func nonDigitHasNoNumber() {
        #expect(KeyStroke(code: KeyCode.escape).digit == nil)
    }

    @Test("Comparação de letra ignora caixa")
    func letterMatchIsCaseInsensitive() {
        let key = KeyStroke(code: 45, modifiers: .command, characters: "N")
        #expect(key.matches("n"))
        #expect(!key.matches("e"))
    }

    @Test("Modificadores são independentes")
    func modifiersAreIndependent() {
        #expect(KeyStroke(code: 0, modifiers: [.shift]).hasCommand == false)
        #expect(KeyStroke(code: 0, modifiers: [.command, .shift]).hasCommand)
    }

    @Test("⌃ e ⇧ são lidos separadamente de ⌘")
    func controlAndShiftAreDistinct() {
        // ⌃↵ e ⌃⇧↵ só se distinguem por isso (VOICE-INSERT §Atalhos).
        let control = KeyStroke(code: KeyCode.returnKey, modifiers: .control)
        #expect(control.hasControl)
        #expect(!control.hasShift)
        #expect(!control.hasCommand)

        let controlShift = KeyStroke(code: KeyCode.returnKey, modifiers: [.control, .shift])
        #expect(controlShift.hasControl)
        #expect(controlShift.hasShift)
    }
}
