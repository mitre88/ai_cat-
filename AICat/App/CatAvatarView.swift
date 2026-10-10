import SwiftUI
import AICatCore

/// Portrait of AI CAT for menus, boards and result overlays (44–140 pt).
///
/// Vector shapes only, lit from the top left: a soft fur sheen on the forehead, a cool rim light on the
/// lower right and one soft drop shadow. Every `CatEmotion` changes the eyelids, pupils, ears, mouth and
/// blush, so each mood reads at a glance. The portrait is decorative: the name, title or speech bubble
/// next to it carries the meaning for VoiceOver.
struct CatAvatarView: View {
    var emotion: CatEmotion = .happy
    var size: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pose = AvatarPose(emotion)
        ZStack {
            ear(tilt: pose.leftEar, side: -1, drop: pose.earDrop)
            ear(tilt: pose.rightEar, side: 1, drop: pose.earDrop)
            head
            face(pose)
        }
        .rotationEffect(.degrees(pose.headTilt))
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: emotion)
        .accessibilityHidden(true)
    }

    // MARK: Palette (key light top left, cool fill bottom right)

    private var furDark: Color { Color(red: 0.02, green: 0.02, blue: 0.035) }
    private var furMid: Color { Theme.catBlack }
    private var furLit: Color { Color(red: 0.27, green: 0.27, blue: 0.33) }
    private var rimLight: Color { Color(red: 0.55, green: 0.86, blue: 0.95) }
    private var innerEar: Color { Color(red: 0.93, green: 0.47, blue: 0.58) }
    private var irisLight: Color { Color(red: 0.62, green: 0.97, blue: 0.84) }
    private var irisDark: Color { Color(red: 0.04, green: 0.40, blue: 0.32) }
    private var noseTop: Color { Color(red: 1.0, green: 0.64, blue: 0.72) }
    private var noseBottom: Color { Color(red: 0.86, green: 0.32, blue: 0.44) }
    private var mouthLine: Color { Color(red: 0.95, green: 0.52, blue: 0.62) }
    private var mouthInside: Color { Color(red: 0.36, green: 0.05, blue: 0.13) }
    private var tongue: Color { Color(red: 0.98, green: 0.50, blue: 0.60) }

    // MARK: Head and ears

    private var head: some View {
        ZStack {
            CatHead().fill(RadialGradient(colors: [furLit, furMid, furDark], center: UnitPoint(x: 0.34, y: 0.24),
                                          startRadius: size * 0.02, endRadius: size * 0.62))
            sheen
            CatHead()
                .stroke(LinearGradient(colors: [.clear, .clear, rimLight.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: size * 0.05)
                .blur(radius: size * 0.012)
        }
        .frame(width: size * 0.86, height: size * 0.76)
        .clipShape(CatHead())
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.22), radius: size * 0.045, x: 0, y: size * 0.035)
        .offset(y: size * 0.07)
    }

    /// Broad, soft highlight where the key light grazes the forehead fur.
    private var sheen: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0)], center: .center,
                                 startRadius: 0, endRadius: size * 0.24))
            .frame(width: size * 0.46, height: size * 0.28)
            .rotationEffect(.degrees(-24))
            .offset(x: -size * 0.13, y: -size * 0.16)
    }

    /// `side` is -1 for the left ear and 1 for the right one; `tilt` leans the ear outward from its base.
    private func ear(tilt: Double, side: CGFloat, drop: CGFloat) -> some View {
        ZStack {
            Ear().fill(LinearGradient(colors: [furLit, furMid], startPoint: .top, endPoint: .bottom))
            Ear().fill(LinearGradient(colors: [innerEar, innerEar.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.15, height: size * 0.20)
        }
        .frame(width: size * 0.30, height: size * 0.34)
        .rotationEffect(.degrees(tilt * Double(side)), anchor: .bottom)
        .offset(x: size * 0.25 * side, y: -size * 0.26 + size * drop)
    }

    // MARK: Face

    private func face(_ pose: AvatarPose) -> some View {
        ZStack {
            blush(pose)
            Whiskers()
                .stroke(Color(white: 0.92).opacity(0.8), style: StrokeStyle(lineWidth: max(0.75, size * 0.01), lineCap: .round))
                .frame(width: size * 0.80, height: size * 0.14)
                .offset(y: size * 0.19)
            eye(pose, side: -1).offset(x: -size * 0.165, y: size * 0.03)
            eye(pose, side: 1).offset(x: size * 0.165, y: size * 0.03)
            nose.offset(y: size * 0.155)
            mouth(pose).offset(y: size * 0.215)
        }
    }

    private func blush(_ pose: AvatarPose) -> some View {
        ZStack {
            Ellipse().fill(innerEar).frame(width: size * 0.12, height: size * 0.065).offset(x: -size * 0.26)
            Ellipse().fill(innerEar).frame(width: size * 0.12, height: size * 0.065).offset(x: size * 0.26)
        }
        .blur(radius: size * 0.015)
        .opacity(pose.blush)
        .offset(y: size * 0.15)
    }

    private func eye(_ pose: AvatarPose, side: CGFloat) -> some View {
        let width = size * 0.155
        let height = size * 0.17
        return ZStack {
            if pose.eyesClosed {
                HappyEyeArc()
                    .stroke(Theme.eyeGreen, style: StrokeStyle(lineWidth: max(1.2, size * 0.026), lineCap: .round))
                    .frame(width: width * 0.9, height: height * 0.32)
            } else {
                openEye(pose, side: side, width: width, height: height)
            }
        }
        .frame(width: width, height: height)
    }

    /// Iris, pupil and catch-lights under an upper lid that closes and slants with the mood.
    private func openEye(_ pose: AvatarPose, side: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Ellipse().fill(RadialGradient(colors: [irisLight, Theme.eyeGreen, irisDark], center: UnitPoint(x: 0.4, y: 0.35),
                                          startRadius: 0, endRadius: width * 0.62))
            Capsule()
                .fill(furDark)
                .frame(width: width * pose.pupilWidth, height: height * 0.8)
                .offset(x: width * pose.gaze.width, y: height * pose.gaze.height)
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: width * 0.3, height: width * 0.3)
                .offset(x: -width * 0.17 + width * pose.gaze.width * 0.4, y: -height * 0.2 + height * pose.gaze.height * 0.4)
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: width * 0.12, height: width * 0.12)
                .offset(x: width * 0.17, y: height * 0.2)
        }
        .frame(width: width, height: height)
        .clipShape(Ellipse())
        // The lid is the fur itself: everything above the lid line is masked away, so the head shows through.
        .mask {
            Rectangle()
                .frame(width: width * 1.8, height: height)
                .offset(y: height * pose.lid)
                .rotationEffect(.degrees(pose.lidSlant * Double(side)))
        }
    }

    private var nose: some View {
        RoundedTriangle()
            .fill(noseGradient)
            .overlay(noseHighlight)
            .frame(width: size * 0.1, height: size * 0.072)
    }

    private var noseGradient: LinearGradient {
        LinearGradient(colors: [noseTop, noseBottom], startPoint: .top, endPoint: .bottom)
    }

    private var noseHighlight: some View {
        Ellipse()
            .fill(Color.white.opacity(0.5))
            .frame(width: size * 0.035, height: size * 0.018)
            .offset(x: size * -0.015, y: size * -0.017)
    }

    @ViewBuilder
    private func mouth(_ pose: AvatarPose) -> some View {
        switch pose.mouth {
        case .smile:
            catSmile
        case .frown:
            catSmile.scaleEffect(x: 1, y: -1)
        case .flat:
            Capsule()
                .fill(mouthLine)
                .frame(width: size * 0.07, height: max(1, size * 0.016))
        case .small:
            Ellipse()
                .fill(mouthInside)
                .overlay(Ellipse().stroke(mouthLine, lineWidth: max(0.8, size * 0.012)))
                .frame(width: size * 0.045, height: size * 0.05)
        case .open:
            OpenMouth()
                .fill(mouthInside)
                .overlay(
                    Ellipse()
                        .fill(tongue)
                        .frame(width: size * 0.06, height: size * 0.04)
                        .offset(y: size * 0.025)
                )
                .clipShape(OpenMouth())
                .frame(width: size * 0.1, height: size * 0.075)
                .offset(y: size * 0.01)
        }
    }

    /// The "w" cat mouth: one half and its mirror image.
    private var catSmile: some View {
        HStack(spacing: -size * 0.01) {
            smileHalf
            smileHalf.scaleEffect(x: -1, y: 1)
        }
    }

    private var smileHalf: some View {
        Smile()
            .stroke(mouthLine, style: StrokeStyle(lineWidth: max(0.8, size * 0.018), lineCap: .round))
            .frame(width: size * 0.09, height: size * 0.04)
    }
}

/// What an emotion changes: ears and lids in degrees, the rest as fractions of the avatar or of one eye.
private struct AvatarPose {
    enum Mouth { case smile, open, frown, flat, small }

    var leftEar: Double = 10
    var rightEar: Double = 10
    var earDrop: CGFloat = 0
    /// Upper lid: 0 open, 1 closed.
    var lid: CGFloat = 0.16
    /// Lowers the outer corners of the lids (sad).
    var lidSlant: Double = 0
    var pupilWidth: CGFloat = 0.36
    var gaze = CGSize.zero
    var eyesClosed = false
    var mouth = Mouth.smile
    var blush: Double = 0
    var headTilt: Double = 0

    init(_ emotion: CatEmotion) {
        switch emotion {
        case .happy:
            break
        case .curious:
            leftEar = 2; rightEar = 18
            lid = 0; pupilWidth = 0.6; gaze = CGSize(width: 0.1, height: -0.06)
            mouth = .small; headTilt = -7
        case .proud:
            leftEar = 6; rightEar = 6
            eyesClosed = true; blush = 0.5
        case .thinking:
            leftEar = 6; rightEar = 16
            lid = 0.22; gaze = CGSize(width: 0.16, height: -0.18)
            mouth = .flat; headTilt = 5
        case .sleepy:
            leftEar = 22; rightEar = 22; earDrop = 0.015
            lid = 0.62; gaze = CGSize(width: 0, height: 0.12)
            mouth = .flat
        case .excited:
            leftEar = 0; rightEar = 0
            lid = 0; pupilWidth = 0.64
            mouth = .open; blush = 0.45
        case .sad:
            leftEar = 34; rightEar = 34; earDrop = 0.03
            lid = 0.26; lidSlant = 16; pupilWidth = 0.6; gaze = CGSize(width: 0, height: 0.1)
            mouth = .frown
        }
    }
}

/// Head a little wider than tall, fullest at the cheeks.
private struct CatHead: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var p = Path()
        p.move(to: point(0.5, 0))
        p.addCurve(to: point(1, 0.58), control1: point(0.8, 0), control2: point(1, 0.25))
        p.addCurve(to: point(0.5, 1), control1: point(1, 0.88), control2: point(0.78, 1))
        p.addCurve(to: point(0, 0.58), control1: point(0.22, 1), control2: point(0, 0.88))
        p.addCurve(to: point(0.5, 0), control1: point(0, 0.25), control2: point(0.2, 0))
        p.closeSubpath()
        return p
    }
}

/// Ear with a softly rounded tip and a flared base.
private struct Ear: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX - w * 0.07, y: rect.minY + h * 0.07),
                       control: CGPoint(x: rect.minX + w * 0.12, y: rect.minY + h * 0.3))
        p.addQuadCurve(to: CGPoint(x: rect.midX + w * 0.07, y: rect.minY + h * 0.07),
                       control: CGPoint(x: rect.midX, y: rect.minY - h * 0.03))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX - w * 0.12, y: rect.minY + h * 0.3))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.maxY - h * 0.1))
        p.closeSubpath()
        return p
    }
}

/// Downward-pointing nose with soft corners.
private struct RoundedTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.15))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.15),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.1))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.8))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.15),
                       control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.8))
        p.closeSubpath()
        return p
    }
}

/// One half of the "w" cat mouth; mirrored for the other side.
private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2),
                       control: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

/// Closed, smiling eye: an upward arc that spans the rect.
private struct HappyEyeArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        return p
    }
}

/// Open mouth: flat top, round bottom.
private struct OpenMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                   control1: CGPoint(x: rect.maxX, y: rect.maxY), control2: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Three gently curved whiskers on each side of the muzzle.
private struct Whiskers: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let sides: [CGFloat] = [-1, 1]
        let rows: [CGFloat] = [-1, 0, 1]
        for side in sides {
            for row in rows {
                p.move(to: CGPoint(x: rect.midX + side * rect.width * 0.16, y: rect.midY + row * rect.height * 0.12))
                p.addQuadCurve(to: CGPoint(x: rect.midX + side * rect.width * 0.5,
                                           y: rect.midY + row * rect.height * 0.42 - rect.height * 0.08),
                               control: CGPoint(x: rect.midX + side * rect.width * 0.34,
                                                y: rect.midY + row * rect.height * 0.22 - rect.height * 0.22))
            }
        }
        return p
    }
}

/// The bubble where AI CAT's current line appears.
struct CatSpeechBubble: View {
    let line: CatLine?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: Theme.symbol(for: line?.emotion ?? .happy))
                .font(.title3)
                .foregroundStyle(Theme.eyeGreen)
            Text(line?.text ?? "")
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .opacity((line?.text.isEmpty ?? true) ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: line?.text ?? "")
        .accessibilityElement(children: .combine)
    }
}
