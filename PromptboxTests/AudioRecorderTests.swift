import Testing

@testable import Promptbox

@Suite("AudioRecorder")
struct AudioRecorderTests {

    @Test("Silêncio absoluto não move a waveform")
    func silenceIsZero() {
        #expect(AudioRecorder.normalized(rms: 0) == 0)
    }

    @Test("Abaixo do piso de −50 dBFS nada é desenhado")
    func belowFloorIsZero() {
        // −60 dBFS.
        #expect(AudioRecorder.normalized(rms: 0.001) == 0)
    }

    @Test("Escala máxima chega em 1")
    func fullScaleIsOne() {
        #expect(AudioRecorder.normalized(rms: 1) == 1)
    }

    @Test("A escala é logarítmica, não linear")
    func scaleIsLogarithmic() {
        // −20 dBFS: num mapeamento linear daria 0,1; na escala em decibéis, 0,6.
        let level = AudioRecorder.normalized(rms: 0.1)
        #expect(level > 0.55 && level < 0.65)
    }

    @Test("Níveis intermediários crescem de forma monotônica")
    func levelsAreMonotonic() {
        let quiet = AudioRecorder.normalized(rms: 0.01)
        let medium = AudioRecorder.normalized(rms: 0.1)
        let loud = AudioRecorder.normalized(rms: 0.5)

        #expect(quiet < medium)
        #expect(medium < loud)
        #expect(loud <= 1)
    }
}
