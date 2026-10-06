import AVFoundation
import SanguoshaCore

@MainActor
final class CardVoicePlayer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var queue = SerialPlaybackQueue<ObjectIdentifier>()
    private var utterances: [ObjectIdentifier: AVSpeechUtterance] = [:]
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    var onSpeakingChanged: ((Bool) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func enqueue(_ lines: [String]) {
        let ids = lines.map { line in
            let utterance = makeUtterance(line)
            let id = ObjectIdentifier(utterance)
            utterances[id] = utterance
            return id
        }
        queue.enqueue(ids)
        if let next = queue.startNext() { play(next) }
    }

    func waitUntilIdle() async {
        guard !queue.isIdle else { return }
        await withCheckedContinuation { idleWaiters.append($0) }
    }

    func stop() {
        queue.clear()
        utterances.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        completeWaiters()
        onSpeakingChanged?(false)
    }

    private func makeUtterance(_ line: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: line)
        utterance.voice = AVSpeechSynthesisVoice.speechVoices().first { $0.name == "Meijia" }
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.88
        utterance.pitchMultiplier = 1.16
        utterance.volume = 0.92
        return utterance
    }

    private func play(_ id: ObjectIdentifier) {
        guard let utterance = utterances[id] else { return }
        onSpeakingChanged?(true)
        synthesizer.speak(utterance)
    }

    private func finishCurrentUtterance(_ id: ObjectIdentifier) {
        guard queue.current == id else { return }
        utterances.removeValue(forKey: id)
        if let next = queue.finishCurrent(matching: id) {
            play(next)
        } else {
            onSpeakingChanged?(false)
            completeWaiters()
        }
    }

    private func completeWaiters() {
        let waiters = idleWaiters
        idleWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finishCurrentUtterance(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.finishCurrentUtterance(id) }
    }
}
