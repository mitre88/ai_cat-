import Foundation
import AVFoundation
import ImageIO
import Vision
import UIKit
import Observation

/// Live, on-device image classification with Vision's built-in classifier on frames from the back camera.
/// Frames are analysed about once per second and thrown away; nothing is stored or sent anywhere.
@MainActor
@Observable
final class CameraClassifier {
    struct Guess: Equatable, Identifiable, Sendable {
        let id: String
        let label: String
        let confidence: Double
    }

    private(set) var guesses: [Guess] = []
    private(set) var isRunning = false
    private(set) var isDenied = false
    let session = AVCaptureSession()

    @ObservationIgnored private let output = AVCaptureVideoDataOutput()
    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "aicat.camera.session")
    @ObservationIgnored private let frameQueue = DispatchQueue(label: "aicat.camera.frames")
    @ObservationIgnored private var analyzer: FrameAnalyzer?
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var errorObserver: NSObjectProtocol?

    static var isSupported: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// Starts the session on its own queue; `isRunning` reflects what the session reports afterwards.
    func start() async {
        guard !isRunning else { return }
        guard await requestAccess() else {
            isDenied = true
            return
        }
        if !configured { configure() }
        let session = self.session
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if !session.isRunning { session.startRunning() }
                continuation.resume()
            }
        }
        isRunning = session.isRunning
    }

    func stop() {
        let session = self.session
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
        isRunning = false
        guesses = []
    }

    private func configure() {
        configured = true
        let analyzer = FrameAnalyzer { [weak self] guesses in
            Task { @MainActor in self?.guesses = guesses }
        }
        self.analyzer = analyzer
        session.beginConfiguration()
        session.sessionPreset = .medium
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(analyzer, queue: frameQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        errorObserver = NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
                self?.guesses = []
            }
        }
    }

    /// Keeps Vision's idea of "up" in sync with the interface orientation (the preview reports it).
    func setVisionOrientation(_ orientation: CGImagePropertyOrientation) {
        analyzer?.setOrientation(orientation)
    }

    /// Classifies a sample picture drawn from an emoji (used when there is no camera or access was refused).
    static func classifySample(emoji: String) async -> [Guess] {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 320))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 220)]
            let text = emoji as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (320 - size.width) / 2, y: (320 - size.height) / 2), withAttributes: attributes)
        }
        guard let cgImage = image.cgImage else { return [] }
        return await Task.detached(priority: .userInitiated) {
            FrameAnalyzer.classify(cgImage: cgImage)
        }.value
    }
}

/// Receives camera frames off the main actor, throttles them and runs Vision's classifier.
final class FrameAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var lastAnalysis = Date.distantPast
    private var orientation: CGImagePropertyOrientation = .right
    private let onGuesses: @Sendable ([CameraClassifier.Guess]) -> Void

    init(onGuesses: @escaping @Sendable ([CameraClassifier.Guess]) -> Void) {
        self.onGuesses = onGuesses
    }

    func setOrientation(_ value: CGImagePropertyOrientation) {
        lock.lock()
        orientation = value
        lock.unlock()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        lock.lock()
        let now = Date()
        let due = now.timeIntervalSince(lastAnalysis) > 1
        if due { lastAnalysis = now }
        let orientation = self.orientation
        lock.unlock()
        guard due, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try? handler.perform([request])
        onGuesses(Self.top(from: request.results ?? []))
    }

    static func classify(cgImage: CGImage) -> [CameraClassifier.Guess] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([request])
        return top(from: request.results ?? [])
    }

    static func top(from observations: [VNClassificationObservation]) -> [CameraClassifier.Guess] {
        observations
            .filter { $0.confidence > 0.05 }
            .prefix(3)
            .map { CameraClassifier.Guess(id: $0.identifier, label: $0.identifier.replacingOccurrences(of: "_", with: " "), confidence: Double($0.confidence)) }
    }
}
