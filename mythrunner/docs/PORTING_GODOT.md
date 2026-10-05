# Porting Mythrunner to Godot 4

The codebase is split so that a port touches **only the presentation layer**:

| Layer | Files | Port effort |
|---|---|---|
| Content | `Resources/realms.json` | **None.** Load it as-is with `JSON.parse_string`. |
| Game rules (pure logic, no Apple APIs) | `Core/*.swift` | **Mechanical** line-by-line translation to GDScript (≈1,400 lines incl. comments). |
| Rendering / input / UI | `Game/*.swift`, `UI/*.swift` | Rebuild with Godot nodes (mapping below). |

The Core unit tests (`Tests/MythrunnerCoreTests`) act as the spec. Port them to [GUT](https://github.com/bitwes/Gut) or gdUnit4 and they will catch behavior drift.

## Core → GDScript mapping

| Swift (Core) | GDScript |
|---|---|
| `struct Course`, `final class RunnerSim`, `GuardianSim`, `RunSession` | `class_name Course extends RefCounted`, etc. |
| `enum RunnerEvent` with associated values | `enum` + a `Dictionary` payload (`{type = Event.LANDED, flips = 2}`) |
| `events: inout [RunnerEvent]` | Pass an `Array` (arrays are by reference in GDScript) |
| `SeededRandom` (SplitMix64) | Same algorithm. GDScript `int` is a signed 64‑bit integer that wraps on overflow, but `>>` is an arithmetic shift, so mask after each shift: `(z >> 30) & 0x3FFFFFFFF`. Verify by comparing the first 10 outputs for a seed against Swift. |
| `Double` | `float` (64-bit in Godot 4) |
| `RunSession.advance(dt)` fixed 1/120 s sub-steps | Call from `_physics_process` with *Physics Ticks per Second* = 120, or keep the accumulator in `_process`. |

Because the course generator is seeded from the realm id (FNV‑1a hash), **a port that reproduces SplitMix64 exactly will generate the identical 30 courses.** Saves and level design carry over.

## Presentation mapping (SpriteKit → Godot)

| SpriteKit | Godot 4 |
|---|---|
| `SKScene` + `SKCameraNode` | `Node2D` root + `Camera2D` (smoothing on) |
| Parallax layers attached to camera | `ParallaxBackground` / `Parallax2D` (4.3+) with `motion_scale` 0.08 / 0.22 / 0.45 |
| `TextureFactory` (Core Graphics) | Draw once in `_draw()` on a `SubViewport`, or use `Polygon2D` + `Line2D` for terrain (Godot batches these well) |
| Terrain chunks (`SKSpriteNode` per 600 pt) | `Polygon2D` per chunk, built from `course.ground(x)`, with a `Line2D` rim |
| `SKEmitterNode` weather | `GPUParticles2D` (`CPUParticles2D` on low-end Android) |
| `SKAction` sequences (bobbing, flapping) | `Tween` or `AnimationPlayer` |
| `SpeechBubble` (`SKLabelNode`) | `CanvasLayer` → `PanelContainer` + `RichTextLabel` (autowrap) |
| SwiftUI menus (map, codex, settings, results) | `Control` scenes. `ScrollContainer` + `HBoxContainer` of realm cards. |
| `UserDefaults` via `SaveStore` | `ConfigFile` or `FileAccess` JSON at `user://save.json` (same Codable JSON shape) |
| `UIImpactFeedbackGenerator` | `Input.vibrate_handheld(ms)` |
| Touch began/ended | `_unhandled_input` with `InputEventScreenTouch` (`pressed` true/false) |

## Suggested Godot project layout
```
godot/
  core/            # course.gd, runner_sim.gd, guardian_sim.gd, run_session.gd, companion.gd, age_tuning.gd
  data/realms.json # symlink or copy
  scenes/game.tscn, realm_map.tscn, codex.tscn, settings.tscn, results.tscn
  render/          # terrain_chunk.gd, guardian_visual.gd, lumi.gd, scenery_painter.gd
  tests/           # GUT ports of CoreTests.swift
```

## When to port
Port only if you need Android or consoles. On iOS, SpriteKit keeps the app smaller (~10 MB vs ~50 MB) with lower overhead, and gives native haptics, Game Center and ProMotion with no plugins.
