import SwiftUI
import AICatCore

/// Flat, friendly 2-D portrait of AI CAT used in menus and as the stage placeholder.
struct CatAvatarView: View {
    var emotion: CatEmotion = .happy
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            // ears
            HStack(spacing: size * 0.34) {
                Triangle().fill(Theme.catBlack).frame(width: size * 0.30, height: size * 0.34)
                Triangle().fill(Theme.catBlack).frame(width: size * 0.30, height: size * 0.34)
            }
            .offset(y: -size * 0.36)
            // head
            Circle()
                .fill(Theme.catBlack)
                .frame(width: size * 0.82, height: size * 0.82)
            // eyes
            HStack(spacing: size * 0.20) {
                eye
                eye
            }
            .offset(y: -size * 0.04)
            // nose + mouth
            VStack(spacing: size * 0.02) {
                Circle().fill(Color.pink).frame(width: size * 0.08, height: size * 0.08)
                Capsule().fill(Color.pink.opacity(0.8)).frame(width: size * 0.16, height: size * 0.03)
            }
            .offset(y: size * 0.16)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.25), value: emotion)
        .accessibilityLabel(Text("AI CAT"))
    }

    private var eye: some View {
        Ellipse()
            .fill(Theme.eyeGreen)
            .frame(width: size * 0.14, height: size * eyeHeight)
            .overlay(
                Ellipse()
                    .fill(Theme.catBlack)
                    .frame(width: size * 0.05, height: size * max(eyeHeight - 0.05, 0.02))
            )
    }

    private var eyeHeight: CGFloat {
        switch emotion {
        case .sleepy: return 0.04
        case .happy, .proud: return 0.10
        case .thinking: return 0.08
        case .curious, .excited: return 0.20
        case .sad: return 0.12
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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
