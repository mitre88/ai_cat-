# AI CAT 🐱

An iOS game that teaches the fundamentals of artificial intelligence to children (6–12). A black kitten,
**AI CAT**, guides the player through 10 progressive worlds; every challenge makes the kitten grow,
physically (continuous morphology from kitten to adult cat) and in knowledge. Bilingual (Spanish / English),
100 % on device, designed first for **iPhone Duo** (outer 5.4" display, inner 7.6" display, hinge postures)
and runs on any iPhone with iOS 26+.

Status: **all 10 scenarios playable** (40 challenges), procedural textures and normal maps on grounds, props and fur (the texture math is unit-tested in the core package), contact shadows under the kitten and under every prop, rim light. Worlds 7 and 8 use the camera and the microphone, behind the parental gate, with sample pictures and sentence chips as fallbacks. Design document: `Docs/GDD.md`.

## Inicio rápido (ES)

1. Abre `AICat.xcodeproj` con Xcode 26 o superior (Xcode 27.1 para los layouts del iPhone Duo).
2. Si Xcode no abre el proyecto escrito a mano: `brew install xcodegen && xcodegen generate`.
3. Con Xcode 26 (sin SDK del Duo) quita `AICAT_DUO` de `SWIFT_ACTIVE_COMPILATION_CONDITIONS` en el target.
4. Pruebas de la lógica sin simulador: `cd Packages/AICatCore && swift test`.
5. Humo completo en la Mac (pruebas + build del simulador + build Duo): `Tools/xcode_smoke.sh` (Xcode 27.1) o `Tools/xcode_smoke.sh --no-duo` (Xcode 26). Si algo falla, el error casi seguro está en la tabla «First build on the Mac» de abajo: pega el error tal cual en el chat y se corrige por archivo.
6. Para ver las texturas y el cielo procedurales como PNG sin abrir Xcode: `Tools/render_textures.sh` (escribe en `/tmp/aicat-textures`).

## Requirements

- Xcode 26 or later. **Xcode 27.1 (beta)** is required for the iPhone Duo layouts (`AICAT_DUO` flag, iOS 27.1 SDK).
- iOS 26.0 deployment target, iPhone only. Apple Intelligence (Foundation Models) is optional: the game is complete without it.

## Build

1. Open `AICat.xcodeproj`. If Xcode refuses the hand-written project file, regenerate it: `brew install xcodegen && xcodegen generate`.
2. Select the `AICat` scheme and an iPhone simulator, or an iPhone Duo pose in Xcode 27.1 Device Hub.
3. Building with Xcode 26 (no Duo SDK)? Remove `AICAT_DUO` from `SWIFT_ACTIVE_COMPILATION_CONDITIONS` (target build settings or `project.yml`); the game falls back to size-class layouts.
4. Signing: set your team in Signing & Capabilities (`DEVELOPMENT_TEAM` is intentionally empty).

Core logic tests (no simulator needed):

```bash
cd Packages/AICatCore && swift test
```

## Static validation (runs anywhere with Python 3)

```bash
pip install openstep_parser
python3 Tools/reference_model.py     # math models: invariants, tables, GoldenValues.swift
python3 Tools/gen_strings.py         # regenerate the String Catalogs from Tools/strings_source.py
python3 Tools/validate_project.py    # pbxproj, plists, catalogs, Swift hygiene
```

## Project layout

| Path | What |
|---|---|
| `AICat/` | App target (SwiftUI + RealityKit). Synchronized folder: new files are picked up automatically. |
| `AICat/App` | App entry, observable app model, root/onboarding views, theme, 2-D avatar, in-app localization. |
| `AICat/Layout` | Posture model (`pocket` / `world` / `lab` / `book`), adaptive stage; `Duo/` holds the iOS 27.1 hinge and arrangement code behind `AICAT_DUO`. |
| `AICat/World` (textures, sky) | `ProceduralTextures` and `ProceduralSky` (AICatCore, tested) compute tileable noise textures, normal maps and the equirectangular sky; `ProceduralImages` wraps them in a `CGImage` on the device; `TextureLibrary` uploads and caches textures; no image assets ship. A `CoreGraphics` shadow lets Linux type-check these files too. |
| `AICat/World` | RealityKit stage: materials, lighting with shadows, camera rig, sets, props, sky/IBL, drag interaction, celebration. |
| `AICat/Cat` | `CatRig` protocol, procedural kitten, animator, USDZ slot. |
| `AICat/Challenges` | Challenge host and session, sorting and labeling boards, result overlay. |
| `AICat/Scenarios` | World map, scenario host, one controller folder per scenario (1–10). |
| `AICat/Capture` | Camera classifier (AVFoundation + Vision), camera preview and on-device speech listener (Speech). Excluded from the Linux type-check and stubbed in `Tools/shadows/AppStubs.swift`. |
| `AICat/Intelligence` | Scripted brain, Foundation Models brain, router with timeout, text-to-speech. The kid-safe filter lives in `AICatCore/Safety` so it is unit-tested. |
| `AICat/Parent` | Parental gate and parent zone. |
| `Config/Info.plist` | Explicit Info.plist (kept outside the synchronized folder on purpose). |
| `Packages/AICatCore/` | Foundation-only Swift package: curriculum, growth model, adaptive difficulty, scoring, learners (decision stump, k-NN), challenge state machines, tests. |
| `Tools/` | Python helpers: reference math model, string catalog generator, project validator. |
| `Docs/` | Game design document, art pipeline, manual QA plan, changelog and the privacy policy (EN/ES). |

## How the playable worlds use real AI

- **Pattern Garden**: AI CAT learns the sorting rule from the child's examples with a one-level decision tree, and only commits when a single hypothesis survives (a version-space idea). Then it carries the remaining fruit itself.
- **Data Library**: AI CAT classifies with k-nearest neighbours over the child's labels; a hidden test set drives the accuracy meter, so wrong labels visibly hurt.
- **Classifier Workshop**: the child *is* the training algorithm. A threshold, a line or three centroids are the model; the meter is the training accuracy, and after "Done" AI CAT classifies unseen test animals with the same model (generalisation). The master level adds outliers the child may flag, but flagging a genuine animal counts as an error.
- **Algorithm Trail**: a tiny interpreter runs the child's block program (forward, turn, jump, *if puddle ahead*, *repeat n*) step by step on the 3-D cat, with a step limit that turns an endless loop into a visible "that program never ends". Fewer runs to reach the fish mean a higher score.
- **Reward Maze**: real tabular Q-learning (α 0.5, γ 0.9, ε-greedy). The child designs the maze (treat, puddles), AI CAT explores in batches, every tile is painted with V(s) = max Q(s, a) so values visibly spread back from the treat, and the greedy policy is replayed on stage. The master level asks for a long *safe* path and lets the child pick how curious (ε) the kitten is. Changing the map makes AI CAT forget, because the old values are no longer true.
- **Neuron Factory**: neurons with wires in {−1, 0, +1} and a "needs at least k" threshold that the child sets by hand; level 3 samples examples that provably need a hidden layer (brute-force separability check). The master level trains a 4-3-1 sigmoid network by full-batch gradient descent on cross-entropy; the child picks the learning rate (slow / medium / turbo, and turbo really does bounce) and watches the error curve.
- **AI CAT's Eyes**: the picture is a 10×10 grid of digits (also built on stage as little cubes). Level 1 zooms until the numbers appear and asks for the brightest pixels; level 2 is a real edge detector (biggest change to a neighbour ≥ a dial the child turns, scored by F1 against the true outline); level 3 is template matching by counting matching pixels ("clues"); the master level runs Vision's on-device classifier on the live camera (or on sample pictures when there is no camera or no permission) and the child checks every guess.
- **AI CAT's Voice**: a greedy longest-match tokenizer (a toy WordPiece) the child reproduces chip by chip; a bigram language model trained on eight visible sentences whose counts the child can verify; on-device speech recognition (`requiresOnDeviceRecognition`) that turns a spoken sentence into text and tokens, with "pretend you said…" chips as the fallback; and a conversation with planted wrong answers to spot. With creative mode on, the child can ask the on-device model one of three fixed questions, filtered and labelled as model-written.
- **Fair Scale**: a data set with a missing coat and the kitten's failed guesses on exactly that coat; a balance game where recognition per group grows with its examples and the scale on stage tilts with the fairness gap; a data-minimisation sort (keep only what the game needs *and* is not private); and real-world cases to judge (cause + fix).
- **Creative Lab**: a tiny generative model (a seeded three-sentence grammar: same seeds, same story; change a word, change the story) that the child remixes; with creative mode on and Apple Intelligence available, the on-device model writes the sentences instead, every one filtered by `KidSafeFilter`, and the card says which one wrote it. The child then designs a helper AI (goal, data, rules) against a six-point checklist, and graduates with a quiz over the ten worlds.

## First build on a Mac

Everything was verified on Linux (package tests, syntax of every file, whole-app type-check against the shadow frameworks in `Tools/shadows`), so the remaining risk sits where Apple's real SDKs differ from the shadows. Run `Tools/xcode_smoke.sh` (Xcode 27.1) or `Tools/xcode_smoke.sh --no-duo` (Xcode 26) and map any error to this list:

| Area | Files | What could differ |
|---|---|---|
| iPhone Duo (iOS 27.1 beta) | `AICat/Layout/Duo/*` | `onHingeChange`, `reservedRegions`, `ArrangementView` signatures; drop `AICAT_DUO` to build without them. |
| Foundation Models | `AICat/Intelligence/FoundationModelsBrain.swift` | `@Generable` / `@Guide` spelling, `respond(to:generating:)`, `prewarm()`. The scripted brain is the fallback for everything. |
| Camera, Vision, Speech | `AICat/Capture/*` | Not type-checked on Linux. `VNClassifyImageRequest`, `AVAudioApplication.requestRecordPermission`, `SFSpeechAudioBufferRecognitionRequest`. Sample pictures and sentence chips keep worlds 7 and 8 playable without them. |
| RealityKit details | `AICat/World/*`, `AICat/Cat/*`, scenario controllers | `DirectionalLightComponent.Shadow(shadowProjection: .fixed(...), depthBias:, cullMode:)` (iOS 18+; if sun shadows vanish, use `.automatic(maximumDistance: 10)`), `EnvironmentResource(equirectangular:withName:)`, `TextureResource(image:withName:options:)`, `PhysicallyBasedMaterial.Opacity(scale:texture:)` + `Opacity.textureSemantic` (contact shadows), `DynamicLightShadowComponent(castsShadow:)` (iOS 18+), `MeshDescriptor` + `MeshBuffers` + `MeshResource.generate(from:)` (capsules with UVs), `MeshResource(shape:)`, `GroundingShadowComponent`, `DirectionalLightComponent.Shadow(shadowProjection: .fixed(...), depthBias:, cullMode:)` (iOS 18+; if sun shadows vanish, use `.automatic(maximumDistance: 10)`), `EnvironmentResource(equirectangular:withName:)`, `TextureResource(image:withName:options:)`, `PhysicallyBasedMaterial.Opacity(scale:texture:)` + `Opacity.textureSemantic` (contact shadows), `DynamicLightShadowComponent(castsShadow:)` (iOS 18+), `MeshDescriptor` + `MeshBuffers` + `MeshResource.generate(from:)` (capsules with UVs), `ImageBasedLightComponent`, `ParticleEmitterComponent.Presets`, `DragGesture().targetedToAnyEntity()`; all centralised, fix once. |
| Text-to-speech | `AICat/Intelligence/CatVoice.swift` | Stubbed on Linux (AVFoundation); small file. |

Checked against Apple's reference pages on 2026-10-09 (so these should not be the problem): `MeshResource.generateBox(size:cornerRadius:)`, `generateSphere`, `generateCylinder`, `generateCone`, `generatePlane(width:depth:cornerRadius:)`, `MeshResource(shape:)`; `GroundingShadowComponent(castsShadow:)` (iOS 18+, lights do not affect it); `VNClassifyImageRequest` and its `[VNClassificationObservation]?` results; `SFSpeechRecognizer(locale:)`, `supportsOnDeviceRecognition`, `isAvailable`, `recognitionTask(with:resultHandler:)`, `requiresOnDeviceRecognition`; `AVAudioApplication.requestRecordPermission(completionHandler:)`; `LanguageModelSession(instructions:)`, `respond(to:generating:)`, `prewarm(promptPrefix:)`; SwiftUI `coordinateSpace(_:)` with `NamedCoordinateSpace` (iOS 17+).

## QA checklist

- Postures (Device Hub, Xcode 27.1): closed → pocket layout; open flat → `ArrangementView` split; tabletop → stage above the fold, controls below; book → board on one page, stage on the other. The sun rises as the device opens; no letterboxing in any pose; interactive controls never sit on the fold.
- Any iPhone: portrait → pocket, large landscape → world. All four orientations.
- Language toggle (parent zone) updates every screen and the voice.
- Reduce Motion (system or parent zone) removes particles, sunrise and fold gestures.
- Apple Intelligence on + "Creative AI CAT" on → generated lines pass the filter; off or unavailable → scripted lines, no visible errors.
- Progress survives relaunch; "Reset progress" asks for confirmation.
- World 7 master: the parental gate appears before the camera; denying the permission (or the simulator) falls back to sample pictures; the preview stops when leaving the level.
- World 8 "Talk to me": the parental gate appears before the microphone; speech is transcribed on device; without permission or support the sentence chips still complete the level.
- VoiceOver reads cards, scenario titles and AI CAT's bubble; Dynamic Type reflows the boards.

## Troubleshooting

- *Project will not open*: run `xcodegen generate` (uses `project.yml`).
- *Unknown type `ArrangementView` / `DeviceHinge`*: you are on Xcode 26; remove `AICAT_DUO`.
- *No shadows*: check the simulator's Metal support; shadows need a device or a recent simulator.
- *Kitten does not grow*: XP only accrues on passed challenges (accuracy ≥ 60 %).
- *Linux / CI without Xcode*: `Tools/verify_linux.sh <swift-toolchain-root>` builds and tests the package, parses every app file and type-checks the whole app against the shadow frameworks in `Tools/shadows` (see `Tools/shadows/README.md`).
- *On a Mac*: `Tools/xcode_smoke.sh [--no-duo]` runs the package tests and a simulator build in one go.
- *GitHub Actions*: `.github/workflows/verify.yml` runs the validators and the full Linux pipeline in the official `swift:6.1-noble` container, plus the package tests on macOS, on every push.

## License

MIT — see `LICENSE`.
