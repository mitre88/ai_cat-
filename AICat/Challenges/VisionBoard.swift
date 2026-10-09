import SwiftUI
import AICatCore

/// Board of AI CAT's Eyes: pixels and numbers, the edge dial, shape clues, and live checks.
struct VisionBoard: View {
    let controller: CatEyesController
    @Environment(AppModel.self) private var app
    @State private var gatePresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string(controller.spec.goalKey.raw))
                    .font(.headline)
                switch controller.level {
                case .pixels:
                    if let challenge = controller.pixels { pixelsView(challenge) }
                case .edges:
                    if let challenge = controller.edges { edgesView(challenge) }
                case .shapes:
                    if let challenge = controller.shapes { shapesView(challenge) }
                case .live:
                    if let challenge = controller.live { liveView(challenge) }
                }
                HStack(spacing: 12) {
                    if controller.level != .live {
                        Button(confirmTitle) { controller.confirm() }
                            .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                            .disabled(!controller.canConfirm)
                        hintButton
                    }
                }
                Text(L10n.string(controller.spec.conceptKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.mapBackground)
        .sheet(isPresented: $gatePresented) {
            ParentGateView {
                gatePresented = false
                controller.approveParent()
            }
        }
        .onDisappear { controller.stopCamera() }
    }

    private var confirmTitle: String {
        switch controller.level {
        case .pixels: return L10n.string("vision.shapes.confirm")
        case .edges: return L10n.string("vision.edges.confirm")
        case .shapes, .live: return L10n.string("vision.shapes.confirm")
        }
    }

    @ViewBuilder
    private var hintButton: some View {
        Button {
            controller.requestHint()
        } label: {
            Label(app.profile.ageBand.autoHints ? L10n.string("common.hint") : L10n.format("sorting.hint_button", controller.hintsLeft), systemImage: "lightbulb.fill")
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .disabled(!controller.canRequestHint)
    }

    // MARK: Pixels

    private func pixelsView(_ challenge: PixelChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("vision.pixels.tip")).font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(1...PixelChallenge.maxZoom, id: \.self) { level in
                    Button {
                        controller.setZoom(level)
                    } label: {
                        Text(zoomLabel(level)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(challenge.zoom == level ? Theme.eyeGreen : Color.accentColor)
                    .disabled(controller.isDone)
                }
            }
            PixelGridView(image: challenge.image,
                          cellSize: challenge.zoom == 1 ? 12 : (challenge.zoom == 2 ? 20 : 28),
                          showNumbers: challenge.zoom == PixelChallenge.maxZoom,
                          showGrid: challenge.zoom >= 2,
                          highlighted: challenge.picks.intersection(challenge.targets),
                          wrong: challenge.picks.subtracting(challenge.targets),
                          hinted: controller.hintPoint,
                          onTap: { controller.tapPixel($0) })
            Text(L10n.format("vision.pixels.remaining_format", challenge.remaining)).font(.caption).foregroundStyle(.secondary)
            if controller.zoomNotice {
                Text(L10n.string("vision.pixels.zoom_first")).font(.callout.bold()).foregroundStyle(Color.orange)
            } else if challenge.isSolved {
                Text(L10n.string("vision.pixels.done")).font(.callout.bold()).foregroundStyle(Theme.eyeGreen)
            } else if challenge.wrongPicks > 0 {
                Text(L10n.string("vision.pixels.wrong")).font(.caption).foregroundStyle(Color.orange)
            }
        }
    }

    private func zoomLabel(_ level: Int) -> String {
        switch level {
        case 1: return "🖼️ " + L10n.string("vision.zoom.picture")
        case 2: return "🔍 " + L10n.string("vision.zoom.grid")
        default: return "🔢 " + L10n.string("vision.zoom.numbers")
        }
    }

    // MARK: Edges

    private func edgesView(_ challenge: EdgeChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("vision.edges.tip")).font(.footnote).foregroundStyle(.secondary)
            PixelGridView(image: challenge.image, cellSize: 26, showNumbers: true, showGrid: true,
                          highlighted: challenge.edges, wrong: [], hinted: nil, onTap: nil)
            HStack(spacing: 12) {
                Button {
                    controller.adjustThreshold(by: -1)
                } label: {
                    Image(systemName: "minus.circle.fill").font(.title)
                }
                .buttonStyle(.plain)
                .disabled(controller.isDone || challenge.threshold <= 0)
                Text(L10n.format("vision.edges.threshold_format", challenge.threshold)).font(.callout.bold())
                Button {
                    controller.adjustThreshold(by: 1)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title)
                }
                .buttonStyle(.plain)
                .disabled(controller.isDone || challenge.threshold >= 9)
            }
            Text(L10n.format("vision.edges.match_format", Int((challenge.f1 * 100).rounded())))
                .font(.subheadline.bold())
                .foregroundStyle(challenge.isSolved ? Theme.eyeGreen : Color.orange)
            if challenge.isSolved {
                Text(L10n.string("vision.edges.done")).font(.callout.bold()).foregroundStyle(Theme.eyeGreen)
            }
        }
    }

    // MARK: Shapes

    private func shapesView(_ challenge: ShapeMatchChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("vision.shapes.tip")).font(.footnote).foregroundStyle(.secondary)
            Text(L10n.format("vision.shapes.round_format", min(challenge.currentIndex + 1, challenge.rounds.count), challenge.rounds.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let round = challenge.current ?? challenge.rounds.last {
                PixelGridView(image: round.query, cellSize: 18, showNumbers: false, showGrid: true,
                              highlighted: [], wrong: [], hinted: nil, onTap: nil)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 8)], spacing: 8) {
                    ForEach(challenge.templates) { template in
                        Button {
                            controller.pickShape(template.id)
                        } label: {
                            VStack(spacing: 4) {
                                PixelGridView(image: template.image, cellSize: 7, showNumbers: false, showGrid: false,
                                              highlighted: [], wrong: [], hinted: nil, onTap: nil)
                                Text(L10n.string(template.nameKey)).font(.caption)
                                Text(L10n.format("vision.shapes.clues_format", round.clues[template.id] ?? 0)).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(controller.hintedShapeID == template.id ? Color.orange : Color.accentColor)
                        .disabled(challenge.isComplete || controller.isDone)
                    }
                }
            }
            if let right = controller.lastPickCorrect {
                Text(L10n.string(right ? "vision.shapes.right" : "vision.shapes.wrong"))
                    .font(.callout.bold())
                    .foregroundStyle(right ? Theme.eyeGreen : Color.orange)
            }
        }
    }

    // MARK: Live

    @ViewBuilder
    private func liveView(_ challenge: LiveCheckChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("vision.live.tip")).font(.footnote).foregroundStyle(.secondary)
            Text(L10n.format("vision.live.checks_format", challenge.checks.count, challenge.required)).font(.caption).foregroundStyle(.secondary)
            switch controller.cameraState {
            case .needsParent:
                Text(L10n.string("vision.live.parent_needed")).font(.callout)
                Button(L10n.string("vision.live.ask_parent")) { gatePresented = true }
                    .buttonStyle(KidButtonStyle(tint: Color.accentColor))
            case .idle:
                Button(L10n.string("vision.live.start_camera")) { controller.openEyes() }
                    .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                Button(L10n.string("vision.live.use_samples")) { controller.useSamples() }
                    .buttonStyle(.bordered)
            case .starting:
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.string("vision.live.no_guess")).font(.caption).foregroundStyle(.secondary)
                }
            case .running:
                CameraPreview(classifier: controller.camera)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                guessesList
            case .samples:
                if controller.cameraDenied {
                    Text(L10n.string("vision.live.denied")).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(L10n.string("vision.live.samples_tip")).font(.caption).foregroundStyle(.secondary)
                }
                Text(controller.currentSample)
                    .font(.system(size: 96))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                if controller.isClassifying {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(L10n.string("vision.live.thinking")).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    guessesList
                }
                Button(L10n.string("vision.live.next_sample")) { controller.nextSample() }
                    .buttonStyle(.bordered)
                    .disabled(controller.isClassifying || controller.isDone)
            }
            if challenge.isSolved {
                Text(L10n.string("vision.live.done")).font(.callout.bold()).foregroundStyle(Theme.eyeGreen)
            }
            Text(L10n.string("vision.live.private_note")).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var guessesList: some View {
        let guesses = controller.currentGuesses
        if guesses.isEmpty {
            Text(L10n.string("vision.live.no_guess")).font(.callout).foregroundStyle(.secondary)
        } else {
            ForEach(guesses) { guess in
                HStack(spacing: 8) {
                    Text(L10n.format("vision.live.guess_format", guess.label, Int((guess.confidence * 100).rounded()))).font(.callout)
                    Spacer()
                    Button(L10n.string("vision.live.agree")) { controller.check(guess, agreed: true) }
                        .buttonStyle(.bordered)
                        .tint(Theme.eyeGreen)
                    Button(L10n.string("vision.live.disagree")) { controller.check(guess, agreed: false) }
                        .buttonStyle(.bordered)
                        .tint(Color.red)
                }
                .disabled(controller.isDone)
                .padding(10)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

/// A grid of pixels, optionally with their numbers; highlighted cells glow, wrong picks are crossed.
struct PixelGridView: View {
    let image: PixelImage
    let cellSize: CGFloat
    let showNumbers: Bool
    let showGrid: Bool
    let highlighted: Set<PixelPoint>
    let wrong: Set<PixelPoint>
    let hinted: PixelPoint?
    let onTap: ((PixelPoint) -> Void)?

    var body: some View {
        VStack(spacing: showGrid ? 1 : 0) {
            ForEach(0..<image.height, id: \.self) { y in
                HStack(spacing: showGrid ? 1 : 0) {
                    ForEach(0..<image.width, id: \.self) { x in
                        cell(PixelPoint(x, y))
                    }
                }
            }
        }
        .padding(showGrid ? 4 : 0)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func cell(_ point: PixelPoint) -> some View {
        let value = image[point]
        let isHighlighted = highlighted.contains(point)
        let isWrong = wrong.contains(point)
        let isHinted = hinted == point
        return Button {
            onTap?(point)
        } label: {
            ZStack {
                Rectangle().fill(CatEyesController.grey(value))
                if isHighlighted {
                    Rectangle().stroke(Color.orange, lineWidth: 2)
                }
                if isHinted {
                    Rectangle().stroke(Color.yellow, lineWidth: 3)
                }
                if showNumbers {
                    Text("\(value)")
                        .font(.system(size: cellSize * 0.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(value >= 5 ? Color.black : Color.white)
                }
                if isWrong {
                    Text("✕").font(.system(size: cellSize * 0.6)).foregroundStyle(Color.red)
                }
            }
            .frame(width: cellSize, height: cellSize)
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}
