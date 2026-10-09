# AI CAT 🐱

An iOS game that teaches the fundamentals of artificial intelligence to children (6–12). A black kitten,
**AI CAT**, guides the player through 10 progressive worlds; every challenge makes the kitten grow,
physically (continuous morphology from kitten to adult cat) and in knowledge. Bilingual (Spanish / English),
100 % on device, designed first for **iPhone Duo** (outer 5.4" display, inner 7.6" display, hinge postures)
and runs on any iPhone with iOS 26+.

Status: foundation + 10 scenarios defined + **scenarios 1 and 2 playable**. Design document: `Docs/GDD.md`.

## Inicio rápido (ES)

1. Abre `AICat.xcodeproj` con Xcode 26 o superior (Xcode 27.1 para los layouts del iPhone Duo).
2. Si Xcode no abre el proyecto escrito a mano: `brew install xcodegen && xcodegen generate`.
3. Con Xcode 26 (sin SDK del Duo) quita `AICAT_DUO` de `SWIFT_ACTIVE_COMPILATION_CONDITIONS` en el target.
4. Pruebas de la lógica sin simulador: `cd Packages/AICatCore && swift test`.

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
| `AICat/World` | RealityKit stage: materials, lighting with shadows, camera rig, sets, props, sky/IBL, drag interaction, celebration. |
| `AICat/Cat` | `CatRig` protocol, procedural kitten, animator, USDZ slot. |
| `AICat/Challenges` | Challenge host and session, sorting and labeling boards, result overlay. |
| `AICat/Scenarios` | World map, scenario host, controllers for scenarios 1 and 2. |
| `AICat/Intelligence` | Scripted brain, Foundation Models brain, router with timeout, kid-safe filter, text-to-speech. |
| `AICat/Parent` | Parental gate and parent zone. |
| `Config/Info.plist` | Explicit Info.plist (kept outside the synchronized folder on purpose). |
| `Packages/AICatCore/` | Foundation-only Swift package: curriculum, growth model, adaptive difficulty, scoring, learners (decision stump, k-NN), challenge state machines, tests. |
| `Tools/` | Python helpers: reference math model, string catalog generator, project validator. |
| `Docs/` | Game design document and art pipeline. |

## How the two playable worlds use real AI

- **Pattern Garden**: AI CAT learns the sorting rule from the child's examples with a one-level decision tree, and only commits when a single hypothesis survives (a version-space idea). Then it carries the remaining fruit itself.
- **Data Library**: AI CAT classifies with k-nearest neighbours over the child's labels; a hidden test set drives the accuracy meter, so wrong labels visibly hurt.

## QA checklist

- Postures (Device Hub, Xcode 27.1): closed → pocket layout; open flat → `ArrangementView` split; tabletop → stage above the fold, controls below; book → board on one page, stage on the other. The sun rises as the device opens; no letterboxing in any pose; interactive controls never sit on the fold.
- Any iPhone: portrait → pocket, large landscape → world. All four orientations.
- Language toggle (parent zone) updates every screen and the voice.
- Reduce Motion (system or parent zone) removes particles, sunrise and fold gestures.
- Apple Intelligence on + "Creative AI CAT" on → generated lines pass the filter; off or unavailable → scripted lines, no visible errors.
- Progress survives relaunch; "Reset progress" asks for confirmation.
- VoiceOver reads cards, scenario titles and AI CAT's bubble; Dynamic Type reflows the boards.

## Troubleshooting

- *Project will not open*: run `xcodegen generate` (uses `project.yml`).
- *Unknown type `ArrangementView` / `DeviceHinge`*: you are on Xcode 26; remove `AICAT_DUO`.
- *No shadows*: check the simulator's Metal support; shadows need a device or a recent simulator.
- *Kitten does not grow*: XP only accrues on passed challenges (accuracy ≥ 60 %).

## License

MIT — see `LICENSE`.
