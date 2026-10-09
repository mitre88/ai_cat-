# Art pipeline — replacing the procedural assets

Everything on stage is generated from primitives so the game runs without a single art file. Each piece has a slot for production assets.

## 1. AI CAT (USDZ)

1. Export the cat as `AICat.usdz` and drop it into `AICat/Resources/` (the synchronized folder picks it up).
2. Conventions expected by `USDZCatRig`:
   - 1 unit = 1 metre; the model stands on the ground at the origin; **nose points to +Z**, up is +Y.
   - The visual bounds' height is used to scale the model to `CatMorphology.standingHeight` (kitten 0.21 m → adult 0.62 m), so author the model at any size.
   - The first animation in the file loops as idle (`availableAnimations.first`). Add `walk`/`jump` clips to extend `USDZCatRig.play(gesture:)`.
   - Materials: PBR (USDZ preview surface). Black fur with a subtle sheen reads best against the sets.
3. Run the app: `WorldModel.prepare()` loads the USDZ when present and falls back to `ProceduralCatRig` otherwise.
4. To support emotions and gaze with a rigged model, map `CatEmotion` to blend shapes and drive the head joint in a new `CatRig` conformer.

## 2. Props and sets

- `World/Props/PropFactory.swift` builds trees, flowers, hedges, bookshelves, baskets and pedestals; `FruitFactory.swift` builds fruits and numbered baskets.
- Replace a builder by loading an entity: `try await Entity(named: "basket", in: nil)` and keep the same collider sizes (`PatternGardenController.basketRadius/basketHeight`) so scoring stays identical.
- Keep draggable props with `InputTargetComponent` + `CollisionComponent` + `PhysicsBodyComponent(mode: .dynamic)`.

## 3. Palette and sky

- `App/Theme.swift` holds the palette per world (`WorldPalette`). Materials derive from it (`World/Materials.swift`).
- `World/SkyEnvironment.swift` paints an equirectangular gradient used as skybox and image-based light. Replace it with a `.exr`/`.hdr` in a `*.skybox` folder and load it with `EnvironmentResource(named:in:)` for HDR lighting.

## 4. 2-D art

- Cards use emoji variants (`AnimalCardView.emoji`). Swap for images in an asset catalog and keep three variants per species.
- The 2-D kitten portrait (`App/CatAvatarView.swift`) can be replaced by an image set; keep the `emotion` parameter.

## 5. Localization

All text is generated from `Tools/strings_source.py` into the String Catalogs. Never edit the `.xcstrings` by hand; run `python3 Tools/gen_strings.py` and `python3 Tools/validate_project.py`.
