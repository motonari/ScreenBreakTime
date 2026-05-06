import AVFoundation
import SwiftUI
import Synchronization

private class Delegate: NSObject, AVSpeechSynthesizerDelegate {
    private let continuations = Mutex<[AVSpeechUtterance: CheckedContinuation<Void, Never>]>([:])

    func register(
        _ continuation: CheckedContinuation<Void, Never>, for utterance: AVSpeechUtterance
    ) {
        continuations.withLock {
            $0[utterance] = continuation
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
    ) {
        let continuation = continuations.withLock {
            $0.removeValue(forKey: utterance)
        }
        continuation?.resume()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
    ) {
        let continuation = continuations.withLock {
            $0.removeValue(forKey: utterance)
        }
        continuation?.resume()
    }
}

struct SpeechManager {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private let delegate = Delegate()

    init() {
        synthesizer.delegate = delegate
    }

    func speak(_ text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.prefersAssistiveTechnologySettings = true

        await withCheckedContinuation { continuation in
            delegate.register(continuation, for: utterance)
            synthesizer.speak(utterance)
        }
    }

    func cancel() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
