import Foundation

#if canImport(AVFoundation)
import AVFoundation

@MainActor
public final class SpeechReader: NSObject, ObservableObject {
    public enum State: Sendable {
        case idle
        case speaking
        case paused
        case stopped
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var progress: Double = 0

    private let synthesizer = AVSpeechSynthesizer()
    private var chunks: [String] = []
    private var currentIndex: Int = 0

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func load(text: String, chunkSize: Int = 1600) {
        stop()
        chunks = TextChunker.chunk(text: text, maxCharacters: chunkSize)
        currentIndex = 0
        progress = chunks.isEmpty ? 0 : 0
        state = .idle
    }

    public func speak() {
        guard !chunks.isEmpty else { return }
        if state == .paused {
            synthesizer.continueSpeaking()
            state = .speaking
            return
        }

        if synthesizer.isSpeaking {
            return
        }

        state = .speaking
        enqueueFromCurrentIndex()
    }

    public func pause() {
        guard synthesizer.isSpeaking else { return }
        if synthesizer.pauseSpeaking(at: .word) {
            state = .paused
        }
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        state = .stopped
        progress = 0
        currentIndex = 0
    }

    private func enqueueFromCurrentIndex() {
        guard currentIndex < chunks.count else {
            state = .idle
            progress = 1
            return
        }

        // Queue a couple utterances ahead; keep memory bounded.
        let endIndex = min(currentIndex + 3, chunks.count)
        for idx in currentIndex..<endIndex {
            let utterance = AVSpeechUtterance(string: chunks[idx])
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }
    }

    private func handleDidFinish() {
        // This fires once per utterance; approximate progress.
        if currentIndex < chunks.count {
            currentIndex += 1
        }
        progress = chunks.isEmpty ? 0 : min(1, Double(currentIndex) / Double(chunks.count))

        if currentIndex >= chunks.count {
            state = .idle
            return
        }

        if synthesizer.isSpeaking == false, state == .speaking {
            enqueueFromCurrentIndex()
        }
    }

    // Chunking implemented in TextChunker.
}

extension SpeechReader: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .speaking
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.handleDidFinish()
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.state = .stopped
        }
    }
}

#endif
