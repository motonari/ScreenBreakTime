import AVFoundation
import SwiftUI

private class Delegate: NSObject, AVSpeechSynthesizerDelegate {
    private var continuations = [AVSpeechUtterance: CheckedContinuation<Void, Never>]()
    func register(
        _ continuation: CheckedContinuation<Void, Never>, for utterance: AVSpeechUtterance
    ) {
        continuations[utterance] = continuation
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance
    ) {
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
    ) {
        if let continuation = continuations.removeValue(forKey: utterance) {
            continuation.resume()
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
    ) {
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
