import AVFoundation
import Speech
import Observation

/// On-device speech recognition for scenario 8. Audio is transcribed on the device only
/// (`requiresOnDeviceRecognition`), never recorded, and the microphone closes after each sentence.
/// `listen` always returns: on a recogniser error, on the timer, or when `stop()` is called.
@MainActor
@Observable
final class SpeechListener {
    private(set) var isListening = false
    private(set) var partialText = ""
    private(set) var isDenied = false

    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var pending: ResumeOnce?
    @ObservationIgnored private var tapInstalled = false
    @ObservationIgnored private var sessionID = 0

    static func isSupported(language: L10n.Language) -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: language.locale) else { return false }
        return recognizer.supportsOnDeviceRecognition
    }

    func requestAccess() async -> Bool {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { return false }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in continuation.resume(returning: granted) }
        }
    }

    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        private let continuation: CheckedContinuation<String?, Never>
        init(_ continuation: CheckedContinuation<String?, Never>) { self.continuation = continuation }
        func resume(_ value: String?) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            continuation.resume(returning: value)
        }
    }

    /// Listens for one sentence (up to `seconds`) and returns the transcription, or nil.
    func listen(language: L10n.Language, seconds: Double = 7) async -> String? {
        guard !isListening else { return nil }
        guard await requestAccess() else {
            isDenied = true
            return nil
        }
        guard let recognizer = SFSpeechRecognizer(locale: language.locale), recognizer.isAvailable else { return nil }
        self.recognizer = recognizer
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            restoreAudioSession()   // another app or a call holds the microphone
            return nil
        }
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {   // an invalid format would make installTap throw an NSException
            restoreAudioSession()
            return nil
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        if tapInstalled { input.removeTap(onBus: 0) }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            restoreAudioSession()
            return nil
        }
        sessionID += 1
        let mySession = sessionID
        isListening = true
        partialText = ""
        self.request = request
        let text: String? = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            let once = ResumeOnce(continuation)
            pending = once
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let transcript = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let failed = error != nil
                Task { @MainActor in
                    guard let self, self.sessionID == mySession else {
                        once.resume(transcript)
                        return
                    }
                    if let transcript { self.partialText = transcript }
                    if isFinal { once.resume(transcript) }
                    if failed { once.resume(self.partialText.isEmpty ? nil : self.partialText) }
                }
            }
            timer?.cancel()
            timer = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled, let self, self.sessionID == mySession else { return }
                request.endAudio()   // this session's request, never a later one
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled, self.sessionID == mySession else { return }
                once.resume(self.partialText.isEmpty ? nil : self.partialText)
            }
        }
        pending = nil
        stop()
        return text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? text : nil
    }

    /// Ends the current session (idempotent). A pending `listen` returns with whatever was heard so far.
    func stop() {
        timer?.cancel()
        timer = nil
        if let pending {
            self.pending = nil
            pending.resume(partialText.isEmpty ? nil : partialText)
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
        isListening = false
        restoreAudioSession()
    }

    private func restoreAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? audioSession.setActive(true)
    }
}
