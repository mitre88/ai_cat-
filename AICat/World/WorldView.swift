import RealityKit
import SwiftUI
import AICatCore

/// The RealityKit stage. Non-AR (virtual camera); the sky is a SwiftUI gradient behind the view
/// because `RealityViewEnvironment.default` shows the view's background style.
struct WorldView: View {
    let world: WorldModel
    var interaction: (any WorldInteraction)?

    var body: some View {
        RealityView { content in
            let generation = world.beginAttach()
            content.camera = .virtual
            await world.prepare()
            world.attach(to: &content, generation: generation)
        }
        .gesture(dragGesture)
        .background {
            SkyGradient(theme: world.theme)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .targetedToAnyEntity()
            .onChanged { value in
                interaction?.dragChanged(value)
            }
            .onEnded { value in
                interaction?.dragEnded(value)
            }
    }
}

struct SkyGradient: View {
    let theme: WorldTheme

    var body: some View {
        let palette = Theme.palette(for: theme)
        LinearGradient(
            colors: [palette.sky, palette.sky.opacity(0.85), palette.ground.opacity(0.35)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Stage = world + AI CAT's speech bubble (+ a growth slider in debug builds).
struct StageView: View {
    let world: WorldModel
    var interaction: (any WorldInteraction)?
    @Environment(AppModel.self) private var app
    @Environment(\.postureInfo) private var postureInfo
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    #if DEBUG
    @State private var debugGrowth: Double = 0
    @State private var showDebugSlider = false
    #endif

    var body: some View {
        ZStack(alignment: .top) {
            WorldView(world: world, interaction: interaction)
            CatSpeechBubble(line: app.speech)
                .frame(maxWidth: 380)
                .padding(12)
            debugBadge
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            // Growth slider for testing, tucked behind a corner button so it never sits on the play area.
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    showDebugSlider.toggle()
                } label: {
                    Image(systemName: "testtube.2").font(.caption).padding(6)
                }
                .buttonStyle(.bordered)
                .opacity(0.5)
                if showDebugSlider {
                    Slider(value: $debugGrowth, in: 0...1)
                        .frame(width: 150)
                        .tint(.white)
                        .onChange(of: debugGrowth) { _, value in
                            world.setGrowth(value, animated: true)
                        }
                }
            }
            .padding(.top, 52)
            .padding(.trailing, 10)
        }
        #endif
        .onAppear {
            #if DEBUG
            debugGrowth = app.profile.growth
            #endif
            world.setReduceEffects(app.profile.reduceEffects || systemReduceMotion)
            world.setGrowth(app.profile.growth, animated: false)
            world.wear(app.profile.unlockedKnowledge)
            world.apply(line: app.speech)
            world.setPosture(postureInfo.posture)
            world.setOpenness(postureInfo.openness)
        }
        .onChange(of: app.profile.totalXP) { _, _ in
            world.setGrowth(app.profile.growth, animated: true)
            world.wear(app.profile.unlockedKnowledge)
        }
        .onChange(of: app.speech) { _, line in
            world.apply(line: line)
        }
        .onChange(of: postureInfo) { _, info in
            world.setPosture(info.posture)
            world.setOpenness(info.openness)
        }
        .onChange(of: app.profile.reduceEffects) { _, reduce in
            world.setReduceEffects(reduce || systemReduceMotion)
        }
        .onChange(of: systemReduceMotion) { _, reduce in
            world.setReduceEffects(app.profile.reduceEffects || reduce)
        }
    }

    @ViewBuilder
    private var debugBadge: some View {
        #if DEBUG && AICAT_DUO
        VStack {
            Spacer()
            HStack {
                Spacer()
                HingeDebugBadge(info: postureInfo)
                    .padding(8)
            }
        }
        #else
        EmptyView()
        #endif
    }
}
