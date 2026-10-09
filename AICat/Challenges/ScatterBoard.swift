import SwiftUI
import AICatCore

/// Board of the Classifier Workshop: a 2-D feature space (size × fluffiness) where the child drags a
/// threshold, a line or class centroids; the meter shows how many animals the classifier gets right.
struct ScatterBoard: View {
    let controller: ClassifierWorkshopController
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string(controller.spec.goalKey.raw))
                    .font(.headline)
                Text(tipText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ScatterMeter(accuracy: controller.accuracy, target: controller.challenge.targetAccuracy)
                ScatterCanvas(controller: controller)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 440)
                HStack {
                    Text(L10n.string("scatter.axis_x")).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(L10n.string("scatter.axis_y")).font(.caption2).foregroundStyle(.secondary)
                }
                legend
                if controller.challenge.allowsFlagging {
                    Text(L10n.string("scatter.flag_tip")).font(.footnote).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    hintButton
                    Spacer()
                    Button(L10n.string("scatter.confirm")) { controller.confirm() }
                        .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                        .frame(maxWidth: 220)
                        .disabled(!controller.isSolved || controller.isDone)
                }
                if controller.isDone {
                    testResults
                }
                Text(L10n.string(controller.spec.conceptKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.mapBackground)
    }

    private var tipText: String {
        switch controller.challenge.model {
        case .threshold: return L10n.string("scatter.tip_threshold")
        case .line: return L10n.string("scatter.tip_line")
        case .centroids: return L10n.string("scatter.tip_centroids")
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(0..<controller.challenge.classes, id: \.self) { label in
                HStack(spacing: 4) {
                    Circle().fill(ClassifierWorkshopController.color(for: label)).frame(width: 12, height: 12)
                    Text(L10n.string(ClassifierWorkshopController.species(for: label).nameKey.raw)).font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var hintButton: some View {
        if app.profile.ageBand.autoHints {
            Button {
                controller.requestHint()
            } label: {
                Label(L10n.string("common.hint"), systemImage: "lightbulb.fill")
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(!controller.canRequestHint)
        } else {
            Button {
                controller.requestHint()
            } label: {
                Label(L10n.format("sorting.hint_button", controller.hintsLeft), systemImage: "lightbulb.fill")
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(!controller.canRequestHint)
        }
    }

    private var testResults: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("scatter.new_animals")).font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(controller.challenge.testPredictions, id: \.point.id) { pair in
                HStack(spacing: 8) {
                    Text(AnimalCardView.emoji(for: ClassifierWorkshopController.species(for: pair.point.label), variant: pair.point.variant))
                    Text(L10n.string(ClassifierWorkshopController.species(for: pair.predicted).nameKey.raw)).font(.callout)
                    Image(systemName: pair.predicted == pair.point.label ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(pair.predicted == pair.point.label ? Color.green : Color.red)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ScatterMeter: View {
    let accuracy: Double
    let target: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.format("scatter.meter_format", Int((accuracy * 100).rounded()), Int((target * 100).rounded())))
                .font(.subheadline.bold())
            ProgressView(value: accuracy)
                .tint(accuracy >= target ? Theme.eyeGreen : Color.orange)
                .animation(.easeInOut(duration: 0.3), value: accuracy)
        }
        .padding(14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A straight line through two points, extended across the whole board.
struct LineShape: Shape {
    var a: CGPoint
    var b: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let dx = b.x - a.x, dy = b.y - a.y
        path.move(to: CGPoint(x: a.x - dx * 20, y: a.y - dy * 20))
        path.addLine(to: CGPoint(x: b.x + dx * 20, y: b.y + dy * 20))
        return path
    }
}

struct GridLinesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for i in 1..<4 {
            let x = rect.minX + rect.width * CGFloat(i) / 4
            let y = rect.minY + rect.height * CGFloat(i) / 4
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

struct ScatterCanvas: View {
    let controller: ClassifierWorkshopController

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardBackground)
                GridLinesShape()
                    .stroke(Theme.lockedGray.opacity(0.6), lineWidth: 1)
                modelOverlay(size: size)
                ForEach(controller.challenge.points) { point in
                    ScatterPointBadge(
                        point: point,
                        predicted: controller.challenge.predict(point),
                        isFlagged: controller.challenge.flagged.contains(point.id)
                    )
                    .position(x: CGFloat(point.x) * size.width, y: (1 - CGFloat(point.y)) * size.height)
                    .onTapGesture { controller.toggleFlag(point) }
                }
                handles(size: size)
            }
            .clipped()
            .coordinateSpace(.named("board"))
            .gesture(boardDrag(size: size))
        }
    }

    @ViewBuilder
    private func modelOverlay(size: CGSize) -> some View {
        switch controller.challenge.model {
        case .threshold(let t):
            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 4, height: size.height)
                .position(x: CGFloat(t) * size.width, y: size.height / 2)
        case .line(let x1, let y1, let x2, let y2):
            LineShape(a: CGPoint(x: CGFloat(x1) * size.width, y: (1 - CGFloat(y1)) * size.height),
                      b: CGPoint(x: CGFloat(x2) * size.width, y: (1 - CGFloat(y2)) * size.height))
                .stroke(Color.red.opacity(0.85), lineWidth: 4)
        case .centroids:
            EmptyView()
        }
    }

    @ViewBuilder
    private func handles(size: CGSize) -> some View {
        switch controller.challenge.model {
        case .threshold:
            EmptyView()
        case .line(let x1, let y1, let x2, let y2):
            handle(color: .red, x: x1, y: y1, size: size) { px, py in
                controller.setLine(x1: px, y1: py, x2: x2, y2: y2)
            }
            handle(color: .red, x: x2, y: y2, size: size) { px, py in
                controller.setLine(x1: x1, y1: y1, x2: px, y2: py)
            }
        case .centroids(let centroids):
            ForEach(centroids, id: \.label) { centroid in
                handle(color: ClassifierWorkshopController.color(for: centroid.label), x: centroid.x, y: centroid.y, size: size) { px, py in
                    controller.moveCentroid(label: centroid.label, x: px, y: py)
                }
            }
        }
    }

    private func handle(color: Color, x: Double, y: Double, size: CGSize, onMove: @escaping (Double, Double) -> Void) -> some View {
        Circle()
            .fill(color)
            .frame(width: 30, height: 30)
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .position(x: CGFloat(x) * size.width, y: (1 - CGFloat(y)) * size.height)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
                    .onChanged { value in
                        onMove(Double(value.location.x / max(size.width, 1)), 1 - Double(value.location.y / max(size.height, 1)))
                    }
            )
    }

    private func boardDrag(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
            .onChanged { value in
                if case .threshold = controller.challenge.model {
                    controller.setThreshold(Double(value.location.x / max(size.width, 1)))
                }
            }
    }
}

struct ScatterPointBadge: View {
    let point: ScatterPoint
    let predicted: Int
    let isFlagged: Bool

    private var trueColor: Color { ClassifierWorkshopController.color(for: point.label) }
    private var predictedColor: Color { ClassifierWorkshopController.color(for: predicted) }
    private var isWrong: Bool { predicted != point.label && !isFlagged }

    var body: some View {
        ZStack {
            Circle()
                .fill(trueColor.opacity(isFlagged ? 0.1 : 0.25))
                .frame(width: 34, height: 34)
            Circle()
                .stroke(isWrong ? Color.red : trueColor, lineWidth: isWrong ? 3 : 2)
                .frame(width: 34, height: 34)
            Text(AnimalCardView.emoji(for: ClassifierWorkshopController.species(for: point.label), variant: point.variant))
                .font(.system(size: 18))
                .opacity(isFlagged ? 0.35 : 1)
            Circle()
                .fill(predictedColor)
                .frame(width: 9, height: 9)
                .offset(x: 0, y: 19)
            if isFlagged {
                Text("❌").font(.caption2).offset(x: 13, y: -13)
            }
        }
        .frame(width: 44, height: 44)
    }
}
