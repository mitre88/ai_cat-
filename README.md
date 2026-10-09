# AI CAT 🐱

An iOS game that teaches the fundamentals of artificial intelligence to children (6–12).
A black kitten, **AI CAT**, guides the player through 10 progressive worlds; every challenge
makes the kitten grow — physically (continuous morphology from kitten to adult cat) and in
knowledge. Bilingual (Spanish / English), 100 % on-device, designed first for **iPhone Duo**
(outer 5.4" display, inner 7.6" display, hinge postures) and runs on any iPhone with iOS 26+.

> Status: foundation + 10 scenarios defined + scenarios 1 and 2 playable. See `Docs/GDD.md`.

## Requirements

- Xcode 26 or later. **Xcode 27.1 (beta)** is required for the iPhone Duo layouts (`AICAT_DUO` flag).
- iOS 26.0 deployment target. Apple Intelligence (Foundation Models) is optional: the game is complete without it.

## Build

1. Open `AICat.xcodeproj` (if Xcode refuses the hand-written project, run `brew install xcodegen && xcodegen generate`).
2. Select the `AICat` scheme and an iPhone simulator (or an iPhone Duo pose in Xcode 27.1 Device Hub).
3. Building with Xcode 26 (no Duo SDK)? Remove `AICAT_DUO` from `SWIFT_ACTIVE_COMPILATION_CONDITIONS` in the target build settings; the game falls back to size-class layouts.

Core logic tests (no simulator needed):

```bash
cd Packages/AICatCore && swift test
```

## Static validation (runs anywhere with Python 3)

```bash
pip install openstep_parser
python3 Tools/gen_strings.py        # regenerate the String Catalogs from Tools/strings_source.py
python3 Tools/validate_project.py   # pbxproj, plists, catalogs, Swift hygiene
```

## Layout

| Path | What |
|---|---|
| `AICat/` | App target (SwiftUI + RealityKit). Synchronized folder: new files are picked up automatically. |
| `Config/Info.plist` | Explicit Info.plist (kept outside the synchronized folder on purpose). |
| `Packages/AICatCore/` | Foundation-only Swift package: curriculum, growth model, adaptive difficulty, learners, challenge state machines. |
| `Tools/` | Python helpers: string catalog generator, project validator, reference math model. |
| `Docs/` | Game design document and art pipeline. |

## License

MIT — see `LICENSE`.
