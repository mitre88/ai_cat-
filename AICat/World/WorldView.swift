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
        } placeholder: {
            WorldPlaceholder(theme: world.theme)
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

/// What the stage shows while a world's textures and sky are being generated: the world's sky, two felt
/// hills and the kitten's portrait breathing gently, so the wait reads as "the world is getting ready",
/// not as a broken view. Still with Reduce Motion.
struct WorldPlaceholder: View {
    let theme: WorldTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private var palette: WorldPalette { Theme.palette(for: theme) }
    private var skyTop: Color { Theme.mix(palette.sky, white: 0.45) }
    private var skyBottom: Color { Theme.mix(palette.sky, white: 0.15) }
    private var farHill: Color { Theme.mix(palette.accent, white: 0.5) }
    private var nearHill: Color { Theme.mix(palette.ground, white: 0.35) }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [skyTop, skyBottom], startPoint: .top, endPoint: .bottom)
            Ellipse()
                .fill(farHill)
                .frame(width: 620, height: 200)
                .offset(x: 160, y: 90)
            Ellipse()
                .fill(nearHill)
                .frame(width: 760, height: 220)
                .offset(x: -140, y: 120)
            CatAvatarView(emotion: .curious, size: 72)
                .scaleEffect(breathing ? 1.04 : 0.96)
                .padding(.bottom, 70)
        }
        .clipped()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
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

/// Stage = world + AI CAT's speech bubble (+ a growth slider in debug builds). A caller that shows the line
/// elsewhere (the map puts it under the stage, next to the portrait) passes `showsSpeech: false`.
struct StageView: View {
    let world: WorldModel
    var interaction: (any WorldInteraction)?
    var showsSpeech = true
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
            if showsSpeech {
                CatSpeechBubble(line: app.speech)
                    .frame(maxWidth: 380)
                    .padding(12)
            }
            debugBadge
        }
        #if DEBUG
        .overlay(alignment: .bottomLeading) {
            // Growth slider for testing, tucked behind a corner button in the bottom-left corner, away from
            // the speech bubble (top) and the hinge badge (bottom-right).
            VStack(alignment: .leading, spacing: 6) {
                if showDebugSlider {
                    Slider(value: $debugGrowth, in: 0...1)
                        .frame(width: 150)
                        .tint(.white)
                        .onChange(of: debugGrowth) { _, value in
                            world.setGrowth(value, animated: true)
                        }
                }
                Button {
                    showDebugSlider.toggle()
                } label: {
                    Image(systemName: "testtube.2").font(.caption2).padding(5)
                }
                .buttonStyle(.bordered)
                .opacity(0.35)
            }
            .padding(10)
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
