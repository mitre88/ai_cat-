import SwiftUI
import AICatCore

/// Board of the Algorithm Trail: the grid, the program the child assembles and the block palette.
struct TrailBoard: View {
    let controller: AlgorithmTrailController
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var controller = controller
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string(controller.spec.goalKey.raw))
                    .font(.headline)
                Text(L10n.string("trail.tip"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TrailGridView(controller: controller)
                    .frame(maxWidth: .infinity)
                programCard
                paletteCard(repeatCount: $controller.repeatCount)
                HStack(spacing: 12) {
                    Button(L10n.string("trail.run")) { controller.run() }
                        .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                        .disabled(controller.isRunning || controller.isDone || controller.program.isEmpty)
                    hintButton
                }
                if let outcome = controller.lastOutcome {
                    Text(outcomeText(outcome))
                        .font(.callout.bold())
                        .foregroundStyle(outcome == .goal ? Color.green : Color.orange)
                }
                Text(L10n.string(controller.spec.conceptKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.mapBackground)
    }

    private var programCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.string("trail.program_title")).font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Text(L10n.format("trail.budget_format", controller.budgetText)).font(.caption).foregroundStyle(.secondary)
            }
            if controller.program.isEmpty {
                Text(L10n.string("trail.program_empty")).font(.callout).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52, maximum: 70), spacing: 6)], spacing: 6) {
                    ForEach(Array(controller.program.enumerated()), id: \.offset) { pair in
                        TrailBlockChip(block: pair.element, index: pair.offset + 1)
                    }
                }
            }
            HStack(spacing: 8) {
                Button {
                    controller.removeLast()
                } label: {
                    Label(L10n.string("trail.remove_last"), systemImage: "delete.left")
                }
                .buttonStyle(.bordered)
                .disabled(controller.program.isEmpty || controller.isRunning || controller.isDone)
                Button {
                    controller.clear()
                } label: {
                    Label(L10n.string("trail.clear"), systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(controller.program.isEmpty || controller.isRunning || controller.isDone)
            }
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func paletteCard(repeatCount: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("trail.palette_title")).font(.caption.bold()).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: 8)], spacing: 8) {
                ForEach(controller.palette, id: \.self) { kind in
                    Button {
                        controller.append(kind)
                    } label: {
                        VStack(spacing: 2) {
                            Text(TrailBlockChip.symbol(for: kind, repeatCount: repeatCount.wrappedValue)).font(.title3)
                            Text(L10n.string(TrailBlockChip.nameKey(for: kind))).font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(controller.hintedBlock?.kind == kind ? Color.orange : Color.accentColor)
                    .disabled(controller.isRunning || controller.isDone)
                }
            }
            if controller.palette.contains(.repeatTimes) {
                HStack {
                    Text(L10n.string("trail.repeat_label")).font(.caption)
                    Picker(L10n.string("trail.repeat_label"), selection: repeatCount) {
                        ForEach([2, 3, 4, 5], id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
            }
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private func outcomeText(_ outcome: TrailOutcome) -> String {
        switch outcome {
        case .goal: return L10n.string("trail.outcome.goal")
        case .splash: return L10n.string("trail.outcome.splash")
        case .lost: return L10n.string("trail.outcome.lost")
        case .tooLong: return L10n.string("trail.outcome.too_long")
        }
    }
}

struct TrailGridView: View {
    let controller: AlgorithmTrailController

    var body: some View {
        let world = controller.challenge.world
        VStack(spacing: 3) {
            ForEach(Array((0..<world.height).reversed()), id: \.self) { y in
                HStack(spacing: 3) {
                    ForEach(0..<world.width, id: \.self) { x in
                        cell(TrailCell(x, y), world: world)
                    }
                }
            }
        }
        .padding(8)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func cell(_ cell: TrailCell, world: TrailWorld) -> some View {
        let isGoal = cell == world.goal
        let isPuddle = world.isPuddle(cell)
        let hasCat = cell == controller.catCell
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isGoal ? Color.yellow.opacity(0.6) : (isPuddle ? Color.blue.opacity(0.35) : Color.green.opacity(0.18)))
            Text(symbol(isGoal: isGoal, isPuddle: isPuddle, hasCat: hasCat))
                .font(.system(size: 20))
        }
        .frame(width: 40, height: 40)
        .accessibilityLabel(Text(L10n.format("a11y.trail_cell_format", cell.x + 1, cell.y + 1, L10n.string(hasCat ? "a11y.tile.cat" : (isGoal ? "a11y.tile.fish" : (isPuddle ? "a11y.tile.puddle" : "a11y.tile.free"))))))
        .animation(.easeInOut(duration: 0.2), value: controller.catCell)
    }

    private func symbol(isGoal: Bool, isPuddle: Bool, hasCat: Bool) -> String {
        if hasCat {
            switch controller.catDirection {
            case .north: return "⬆️"
            case .east: return "➡️"
            case .south: return "⬇️"
            case .west: return "⬅️"
            }
        }
        if isGoal { return "🐟" }
        if isPuddle { return "💧" }
        return ""
    }
}

struct TrailBlockChip: View {
    let block: TrailBlock
    let index: Int

    static func symbol(for kind: TrailBlockKind, repeatCount: Int) -> String {
        switch kind {
        case .forward: return "⬆️"
        case .turnLeft: return "↩️"
        case .turnRight: return "↪️"
        case .jump: return "🦘"
        case .ifPuddleAhead: return "💧→🦘"
        case .repeatTimes: return "🔁\(repeatCount)⬆️"
        }
    }

    static func nameKey(for kind: TrailBlockKind) -> String {
        switch kind {
        case .forward: return "trail.block.forward"
        case .turnLeft: return "trail.block.turn_left"
        case .turnRight: return "trail.block.turn_right"
        case .jump: return "trail.block.jump"
        case .ifPuddleAhead: return "trail.block.if_puddle"
        case .repeatTimes: return "trail.block.repeat"
        }
    }

    private var symbol: String {
        if case .repeatForward(let n) = block { return Self.symbol(for: .repeatTimes, repeatCount: n) }
        return Self.symbol(for: block.kind, repeatCount: 0)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(symbol).font(.title3)
            Text("\(index)").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Theme.eyeGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
