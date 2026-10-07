# Mythrunner (iOS prototype)

An Alto's Odyssey–style side-scrolling runner through **30 realms of world mythology**: Greek to Guaraní, Egyptian to Ainu, Norse to San. Lumi, a spirit companion, tells short, true stories as you ride, and each realm ends with a guardian encounter.

- **Engine:** Swift + SpriteKit + SwiftUI. No dependencies, no image assets: all art is procedural.
- **Content:** `Mythrunner/Resources/realms.json`. 30 realms × (3 facts + relic story + guardian), each written at two reading levels.
- **Portable:** the game rules in `Mythrunner/Core/` are pure Swift and unit-tested on Linux. See `docs/PORTING_GODOT.md`.

## Run it
1. Open `Mythrunner.xcodeproj` in **Xcode 16+**. (On older Xcode: `brew install xcodegen && xcodegen`.)
2. Select your team under *Signing & Capabilities* and change the bundle id `com.example.mythrunner` if needed.
3. Run on an iPhone or iPad, or a landscape Simulator.
4. First launch asks for the player's age. In Settings you can:
   - set **Unlock all 30 realms** for testing
   - change the **Guardian encounter** (default: Chase & Escape)
   - turn on **Show FPS & draw calls**

## Controls
- **Tap** to jump. **Hold in the air** to backflip.
- A clean flip landing gives a speed boost. Land a half‑flip and you crash.
- Collect the 3 glowing relics to unlock their stories.

| | Jump (hold to flip) | Pause / resume | Back |
|---|---|---|---|
| Touch | tap / hold | ⏸ button | — |
| Keyboard | Space, ↑, W, Return | Esc, P | Backspace |
| Gamepad (Bluetooth / MFi) | Ⓐ, D-pad ↑, R1, R2 | Menu | Ⓑ |

On the results screen, jump = next realm (or retry after a loss) and back = map.

## On the path
- **Springboards** launch you high; the landing zone is always clear.
- **Spirit gates** (floating rings) give a speed boost when you jump through.
- **Spirit motes** trail over obstacles and along open ground; your count shows on the results screen.
- **Heart shrines** (a pillar of light, one per realm, two on the longest) restore a heart, or boost you at full health.

## Test the core (no Mac needed)
```bash
swift test            # macOS or Linux with Swift 5.9+
# or, with Docker:
docker run --rm -v "$PWD":/src -w /src swift:6.0-noble swift test
```
The suite validates all content (30 realms, balanced regions, valid colors, bubble-sized text). It also plays **every realm × age band × guardian mode (270 runs)** with a bot, to guarantee each one is beatable.

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
Add one entry to `realms.json`: palette, scenery, `motif`, facts, relic, guardian (with its `design`). Then run `swift test`. No code changes are needed unless you want a new landmark shape (`Game/SceneryPainter.swift`), guardian archetype (`Game/GuardianNode.swift`), motif (`Game/MotifPainter.swift`) or signature detail (`Game/GuardianSignatures.swift`).

Each guardian's `design` sets heads, eyes, horns, headgear, wings, tail and aura, plus a `signature`: one detail from its myth that no other guardian uses. `swift test` fails if two guardians share a design or a signature, so bosses never repeat.

Debug builds accept launch arguments for QA: `-previewRealm norse` opens a realm directly, and `-guardianGallery YES -galleryPage 0` shows ten guardians per page (tap for the next page).
