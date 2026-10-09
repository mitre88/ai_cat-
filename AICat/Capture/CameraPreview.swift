import AVFoundation
import ImageIO
import SwiftUI
import UIKit

/// The live camera image, shown only while the level is open. Follows the interface orientation and
/// tells the classifier which way is up.
struct CameraPreview: UIViewRepresentable {
    let classifier: CameraClassifier

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var onLayout: (() -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?()
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = classifier.session
        view.previewLayer.videoGravity = .resizeAspectFill
        let classifier = self.classifier
        view.onLayout = { [weak view] in
            guard let view else { return }
            Self.applyOrientation(to: view, classifier: classifier)
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        Self.applyOrientation(to: uiView, classifier: classifier)
    }

    @MainActor
    private static func applyOrientation(to view: PreviewView, classifier: CameraClassifier) {
        let interface = view.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        let angle: CGFloat
        let vision: CGImagePropertyOrientation
        switch interface {
        case .landscapeRight: (angle, vision) = (0, .up)
        case .landscapeLeft: (angle, vision) = (180, .down)
        case .portraitUpsideDown: (angle, vision) = (270, .left)
        default: (angle, vision) = (90, .right)
        }
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        classifier.setVisionOrientation(vision)
    }
}
