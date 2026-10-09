# Shadow frameworks

Tiny stand-ins for `simd`, `UIKit`, `SwiftUI` and `RealityKit` with just enough API *shape* to
type-check AI CAT's app code on Linux (where the real frameworks do not exist). They model the
signatures the app relies on, following Apple's documentation; they are **not** behavioural.

`Tools/verify_linux.sh` compiles them as modules and type-checks every app file against them
(`Intelligence/CatVoice.swift` and `World/SkyEnvironment.swift` are replaced by `AppStubs.swift`,
because AVFoundation and CoreGraphics are not modelled).

What this catches: wrong labels or types between the app's own files, main-actor isolation mistakes,
misuse of the modelled framework signatures, and anything the syntax pass misses.
What it cannot catch: a framework signature that differs from the shadow. Keep the shadows in sync
with Apple's docs when adding new framework calls.

## Added while the boards grew

`position`, `onTapGesture`, `clipped`, `coordinateSpace(_:)` with `NamedCoordinateSpace`, `aspectRatio`, `zIndex`,
`scrollDisabled`, `task(priority:_:)`, `task(id:priority:_:)`, `ProgressView()`, `Color.primary` / `Color.secondary`,
and the Capture stubs (`CameraClassifier`, `CameraPreview`, `SpeechListener`) in `AppStubs.swift`. When a board uses a
new modifier, add it here with the same signature as Apple's and keep the body a no-op.
