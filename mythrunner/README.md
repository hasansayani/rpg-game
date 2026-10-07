# Mythrunner (iOS prototype)

A side-scrolling runner through **30 realms of world mythology**: Greek to Guaraní, Egyptian to Ainu, Norse to San. The Wayfarer runs (and, in two realms, swims) while Lumi, a spirit companion, tells short, true stories, and each realm ends with a guardian encounter.

- **Engine:** Swift + SpriteKit + SwiftUI. No dependencies, no image assets: all art is procedural.
- **Content:** `Mythrunner/Resources/realms.json`. 30 realms × (3 facts + relic story + guardian), each written at two reading levels, plus each realm's biome, obstacle props, motif and guardian design.
- **Portable:** the game rules in `Mythrunner/Core/` are pure Swift and unit-tested on Linux. See `docs/PORTING_GODOT.md`.

## Run it
1. Open `Mythrunner.xcodeproj` in **Xcode 16+**. (On older Xcode: `brew install xcodegen && xcodegen`.)
2. Select your team under *Signing & Capabilities* and change the bundle id `com.example.mythrunner` if needed. (The Simulator needs no signing team.)
3. Run on an iPhone or iPad, or a landscape Simulator.
4. The app opens on a splash and loading screen, asks the player's age once, then shows the title menu: **Continue**, **Choose realm**, **New game**, **Codex**, **Settings**.
5. In Settings → **Debug mode** you can unlock all realms (tap any realm on the map to play it), show FPS and (in debug builds) open the guardian gallery.

## Controls
- **Tap** for a short hop. **Press and hold** to crouch into a big jump; **keep holding** in the air to tuck into a flip, and **let go** to open up and land. Tucking spins you faster, opening up slows the spin (angular momentum is conserved), so let go in time to land upright.
- A clean flip landing gives a speed boost. Land badly and you go back to the last checkpoint. Hard landings make you stumble.
- Landing on top of an obstacle bounces you off it.
- **Swimming realms** (Sedna's Ice Sea, Moon-Eater's Sea): each press is a quick kick upward; hold to keep rising, let go to sink.
- Collect the 3 glowing relics to unlock their stories.

| | Jump / flip / swim up | Pause / resume | Back |
|---|---|---|---|
| Touch | tap / hold | ⏸ button | — |
| Keyboard | Space, ↑, W, Return | Esc, P | Backspace |
| Gamepad (Bluetooth / MFi) | Ⓐ, D-pad ↑, R1, R2 | Menu | Ⓑ |

On the results screen, jump = next realm and back = map.

## No lives: checkpoints
There are no hearts. Any failure (an obstacle, a chasm, a bad landing, the guardian) sends you back to the last **checkpoint shrine** you passed; in the guardian encounter it restarts the encounter. Younger players get checkpoints closer together. Every run gets a freshly randomized layout, and every hazard is guaranteed to leave room to land and a comfortable window to clear it with a tap.

## On the path
- **Springboards** launch you high; the landing zone is always clear.
- **Spirit gates** (floating rings) give a speed boost when you jump through.
- **Spirit motes** trail over obstacles and along open ground; your count shows on the results screen.
- **Obstacles and scenery come from each culture's world**: amphorae and broken columns in Greece, stone lanterns and bamboo in Japan, calabashes and drums in the Yoruba market, rune stones in the north, Inca masonry, coral and icicles under the sea.
- **Sky:** each checkpoint moves the day on (day → dusk → night → dawn). Nights show a constellation the culture knew; days bring birds or mythical creatures in silhouette; weather comes and goes.

## Test the core (no Mac needed)
```bash
swift test            # macOS or Linux with Swift 5.9+
# or, with Docker:
docker run --rm -v "$PWD":/src -w /src swift:6.0-noble swift test
```
The suite validates all content (30 realms, balanced regions, valid colors, bubble-sized text, unique guardians) and the physics. A bot plays **every realm × age band × guardian mode (270 runs)** plus 270 randomly generated layouts, and each must be finished within a small number of checkpoint retries.

## Layout
```
Mythrunner/
  App/        SwiftUI app entry + AppModel (settings, progress, persistence)
  Core/       Pure game logic: course generation, runner physics, guardian modes, companion pacing, age tuning
  Game/       SpriteKit rendering: scene, procedural textures, parallax painter, guardian visuals, weather
  UI/         SwiftUI screens: age gate, realm map, results, codex, settings
  Resources/  realms.json (all content)
Tests/        Core unit tests (run with `swift test`)
docs/         DESIGN.md (GDD, KPIs, realm list), PORTING_GODOT.md
```

## Adding a realm
Add one entry to `realms.json`: palette, scenery (optionally its `biome` and obstacle `props`), `motif`, facts, relic, guardian (with its `design`). Set `"terrain": "water"` for a swimming realm. Then run `swift test`. No code changes are needed unless you want a new landmark shape (`Game/SceneryPainter.swift`), guardian archetype (`Game/GuardianNode.swift`), motif (`Game/MotifPainter.swift`) or signature detail (`Game/GuardianSignatures.swift`).

Each guardian's `design` sets heads, eyes, horns, headgear, wings, tail and aura, plus a `signature`: one detail from its myth that no other guardian uses. `swift test` fails if two guardians share a design or a signature, so bosses never repeat.

Debug builds accept launch arguments for QA: `-previewRealm norse` opens a realm directly, `-guardianGallery YES -galleryPage 0` shows ten guardians per page (tap for the next page), and `-skyPhase 2` starts a run at night.
