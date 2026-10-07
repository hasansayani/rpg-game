import Foundation

struct Obstacle: Equatable {
    var x: Double
    var width: Double
    var height: Double
}

struct Gap: Equatable {
    var start: Double
    var end: Double
    func contains(_ x: Double) -> Bool { x > start && x < end }
}

struct RelicSpot: Equatable {
    var x: Double
    /// Height above the ground surface.
    var lift: Double
}

/// A launch pad on the ground: riding over it throws the runner high into the air.
struct Springboard: Equatable {
    var x: Double
}

/// A floating ring. Passing through it grants a speed boost.
struct SpiritGate: Equatable {
    var x: Double
    /// Height of the ring's center above the ground surface.
    var lift: Double
}

/// A small glowing collectible. Motes come in trails: arcs over obstacles and lines along the ground.
struct Mote: Equatable {
    var x: Double
    var lift: Double
}

/// A culture's shrine on the path. Passing it saves progress: failures respawn the runner here.
struct Checkpoint: Equatable {
    var x: Double
}

/// Water realms only: an icicle or jellyfish hanging down from the water surface.
struct Hanger: Equatable {
    var x: Double
    var width: Double
    /// How far it reaches down from the surface.
    var length: Double
}

/// A deterministic, infinite course. The "run" section (0..<runLength) holds gaps,
/// obstacles and relics; the guardian phase continues on hazard-free hills after it.
struct Course {
    static let baseHeight: Double = 230
    static let safeStart: Double = 700
    /// Upper bound on terrain steepness (rise/run). ~0.9 ≈ 42°.
    static let maxSlope: Double = 0.9

    let runLength: Double
    let amplitude: Double
    let gaps: [Gap]
    let obstacles: [Obstacle]
    let relics: [RelicSpot]
    let springboards: [Springboard]
    let gates: [SpiritGate]
    /// Sorted by x.
    let motes: [Mote]
    /// Sorted by x.
    let checkpoints: [Checkpoint]
    /// Water realms: the ground is the seabed and the swimmer stays below `waterSurface`.
    let isWater: Bool
    let waterSurface: Double
    /// Sorted by x. Empty on land.
    let hangers: [Hanger]
    /// Minimum clear ground between consecutive hazards: enough to land a short hop and jump again.
    let landingRoom: Double
    /// The per-run seed this layout was built from.
    let variation: UInt64
    /// World x positions where Lumi shares a fact (one per realm fact).
    let factTriggers: [Double]

    /// How far a springboard throws the runner; the landing zone after one is kept hazard-free.
    static let springboardClearance: Double = 750

    private let waves: [(amp: Double, freq: Double, phase: Double)]

    /// `variation` makes each run different (0 = the realm's reference layout, used by tests).
    /// Everything is still deterministic for a given (realm, variation) pair.
    init(realm: Realm, totalRealms: Int, tuning: AgeTuning, variation: UInt64 = 0) {
        var rng = SeededRandom(seed: realm.seed ^ (variation &* 0x9E37_79B9_7F4A_7C15))
        self.variation = variation
        let difficulty = realm.difficulty(totalRealms: totalRealms)

        let runLength = 10000 + 4000 * difficulty
        self.runLength = runLength
        let f = realm.scenery.frequency
        let twoPi = Double.pi * 2
        // Each run reshuffles the hills: new phases and slightly different wavelengths.
        let waves: [(amp: Double, freq: Double, phase: Double)] = [
            (0.55, twoPi / (1100 * rng.range(0.85, 1.15) / f), rng.range(0, twoPi)),
            (0.30, twoPi / (520 * rng.range(0.85, 1.15) / f), rng.range(0, twoPi)),
            (0.15, twoPi / (260 * rng.range(0.85, 1.15) / f), rng.range(0, twoPi)),
        ]
        self.waves = waves

        // Kids get gentler hills. Content can never exceed the max slope (keeps every realm rideable).
        // The seabed of water realms is gentler, leaving room to swim.
        let isWater = realm.isWater
        self.isWater = isWater
        var amp = realm.scenery.amplitude * (tuning.band == .sprout ? 0.75 : 1.0) * (isWater ? 0.7 : 1.0)
        let worstSlope = amp * waves.reduce(0) { $0 + $1.amp * $1.freq }
        if worstSlope > Course.maxSlope { amp *= Course.maxSlope / worstSlope }
        amplitude = amp
        // At least ~200 pt of water over the highest seabed.
        let waterSurface = Course.baseHeight + amp + 200
        self.waterSurface = waterSurface

        // Hazards are placed on a slot grid so they never overlap each other.
        let slot = 320.0
        let slotCount = Int((runLength - Course.safeStart - 400) / slot)
        var free = Array(0..<max(slotCount, 0)).map { Course.safeStart + Double($0) * slot + slot / 2 }
        // Shuffle deterministically.
        for i in stride(from: free.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            free.swapAt(i, j)
        }

        let gapCount = isWater ? 0 : Int((1 + 4 * difficulty) * tuning.gapScale + 0.5)
        var gaps: [Gap] = []
        let localWaves = waves, localAmplitude = amp
        func rise(across width: Double, at center: Double) -> Double {
            Course.height(at: center + width / 2, waves: localWaves, amplitude: localAmplitude)
                - Course.height(at: center - width / 2, waves: localWaves, amplitude: localAmplitude)
        }
        // Chasms only where the far edge isn't higher than the takeoff, and where a short hop at cruising
        // speed clears them from a comfortable window of take-off points (downhill hops are flatter).
        let runnerCfg = RunnerConfig(difficulty: difficulty, tuning: tuning)
        func gapClearable(start: Double, end: Double) -> Bool {
            let surf = { (x: Double) in Course.height(at: x, waves: localWaves, amplitude: localAmplitude) }
            return Course.comfortSpeeds(runnerCfg).allSatisfy { speed in
                stride(from: start - 300, through: start - 5, by: 10).filter {
                    Course.hopLanding(from: $0, speed: speed, hop: runnerCfg.shortJumpVelocity,
                                      gravity: runnerCfg.gravity, surface: surf) > end + 15
                }.count >= Course.comfortWindow
            }
        }
        var candidates = free.indices.reversed().makeIterator()
        var used: [Int] = []
        while gaps.count < min(gapCount, free.count / 3), let i = candidates.next() {
            let width = rng.range(100, 150 + 60 * difficulty)
            let start = free[i] - width / 2, end = free[i] + width / 2
            let gapRoom = 2 * runnerCfg.shortJumpVelocity / runnerCfg.gravity * runnerCfg.baseSpeed * 1.35
            if rise(across: width, at: free[i]) <= 4,
               !gaps.contains(where: { $0.end > start - gapRoom && $0.start < end + gapRoom }),
               gapClearable(start: start, end: end) {
                gaps.append(Gap(start: free[i] - width / 2, end: free[i] + width / 2))
                used.append(i)
            }
        }
        for i in used.sorted(by: >) { free.remove(at: i) }
        let sortedGaps = gaps.sorted { $0.start < $1.start }
        self.gaps = sortedGaps

        // Springboards claim their slots before obstacles so each gets a clear landing zone.
        var springboards: [Springboard] = []
        var landingSlots: [Double] = []
        let springCount = isWater ? 0 : Int(runLength / 3200)
        for k in 0..<springCount {
            let target = runLength * (Double(k) + 0.5) / Double(springCount)
            let candidates = free.filter { x in
                !sortedGaps.contains { $0.end > x - 120 && $0.start < x + Course.springboardClearance }
                    && x + Course.springboardClearance < runLength - 200
                    && !springboards.contains { abs($0.x - x) < 1500 }
            }
            guard let x = candidates.min(by: { abs($0 - target) < abs($1 - target) }) else { continue }
            springboards.append(Springboard(x: x))
            landingSlots += free.filter { $0 > x && $0 < x + Course.springboardClearance + slot / 2 }
            free.removeAll { $0 >= x && $0 < x + Course.springboardClearance + slot / 2 }
        }
        self.springboards = springboards.sorted { $0.x < $1.x }

        // Longer runs keep obstacle density a little lower than the old short runs, so total risk grows gently.
        let obstacleCount = Int(((runLength / 875) * (0.6 + 0.8 * difficulty)) * tuning.obstacleScale + 0.5)
        var obstacles: [Obstacle] = []
        for _ in 0..<min(obstacleCount, free.count / 2) {
            let base = free.removeLast()
            var x = base + rng.range(-60, 60)
            if springboards.contains(where: { x > $0.x - 60 && x < $0.x + Course.springboardClearance + 20 }) { x = base }
            obstacles.append(Obstacle(x: x, width: rng.range(30, 46), height: rng.range(26, 40 + 8 * difficulty)))
        }
        // Room to land: after clearing one hazard there must be space to touch down and jump again,
        // so drop any obstacle that starts within a short hop's landing distance of the previous hazard.
        let runner = runnerCfg
        let hopAirtime = 2 * runner.shortJumpVelocity / runner.gravity
        let landingRoom = hopAirtime * runner.baseSpeed * 1.35
        self.landingRoom = landingRoom
        var spaced: [Obstacle] = []
        var lastEnd = -Double.infinity
        let hazards: [(start: Double, end: Double, obstacle: Obstacle?)] =
            (obstacles.map { ($0.x - $0.width / 2, $0.x + $0.width / 2, Optional($0)) }
                + sortedGaps.map { ($0.start, $0.end, nil) }).sorted { $0.start < $1.start }
        // A tap must clear every obstacle: keep one only if a short hop clears it from a comfortable
        // window of take-off points (at least 50 pt, not one pixel-perfect spot), whether running slow or fast.
        let hopV = runner.shortJumpVelocity, g = runner.gravity
        func tapClearable(_ o: Obstacle) -> Bool {
            Course.comfortSpeeds(runner).allSatisfy { speed in
                stride(from: o.x - 300, through: o.x - 40, by: 10).filter {
                    Course.hopClears(from: $0, obstacle: o, speed: speed, hop: hopV, gravity: g,
                                     surface: { Course.height(at: $0, waves: waves, amplitude: amp) })
                }.count >= Course.comfortWindow
            }
        }
        for h in hazards {
            if let o = h.obstacle {
                guard isWater || tapClearable(o) else { continue }
                guard h.start - lastEnd >= landingRoom,
                      !sortedGaps.contains(where: { $0.start >= h.end && $0.start - h.end < landingRoom }) else { continue }
                spaced.append(o)
            }
            lastEnd = max(lastEnd, h.end)
        }
        let sortedObstacles = spaced
        self.obstacles = sortedObstacles

        // Water: things hanging from the surface, in their own slots, always leaving a swimmable channel.
        var hangers: [Hanger] = []
        if isWater {
            let hangerCount = Int(Double(obstacleCount) * 0.6)
            for _ in 0..<min(hangerCount, free.count / 2) {
                let x = free.removeLast()
                // Same rule as on land: time to change depth between consecutive hazards.
                guard x > Course.safeStart + 400,
                      !sortedObstacles.contains(where: { abs($0.x - x) < landingRoom }),
                      !hangers.contains(where: { abs($0.x - x) < landingRoom }) else { continue }
                let depth = waterSurface - Course.height(at: x, waves: waves, amplitude: amp)
                let length = min(rng.range(50, 80 + 40 * difficulty), depth - 130)
                hangers.append(Hanger(x: x, width: rng.range(26, 40), length: max(length, 30)))
            }
        }
        self.hangers = hangers.sorted { $0.x < $1.x }

        // Three relics, evenly spread, nudged away from hazards.
        var relics: [RelicSpot] = []
        for i in 0..<3 {
            var x = runLength * (Double(i) + 0.6) / 3.4
            while sortedGaps.contains(where: { abs($0.start - x) < 120 || $0.contains(x) })
                    || sortedObstacles.contains(where: { abs($0.x - x) < 90 }) {
                x += 60
            }
            relics.append(RelicSpot(x: x, lift: rng.range(95, 140)))
        }
        self.relics = relics

        // Interactive extras use the remaining free slots (landing zones are safe for them too),
        // in a fixed order so seeds stay stable.
        free = (free + landingSlots).sorted()
        func clear(of x: Double, before: Double, after: Double) -> Bool {
            !sortedGaps.contains { $0.end > x - before && $0.start < x + after }
                && !sortedObstacles.contains { $0.x > x - before && $0.x < x + after }
                && !relics.contains { abs($0.x - x) < 80 }
                && !springboards.contains { abs($0.x - x) < 120 }
                && !hangers.contains { abs($0.x - x) < before }
        }
        func inLanding(_ x: Double) -> Bool {
            springboards.contains { x > $0.x && x < $0.x + Course.springboardClearance }
        }
        // Checkpoints every `checkpointSpacing`, each nudged forward onto safe, open ground
        // (a respawn must never land in a gap, on a hazard, or mid-springboard arc).
        var checkpoints: [Checkpoint] = []
        var target = tuning.checkpointSpacing
        while target < runLength - 400 {
            var x = target
            while x < runLength - 300, inLanding(x) || !clear(of: x, before: 160, after: 220) { x += 20 }
            if x < runLength - 300, checkpoints.last.map({ x - $0.x > 600 }) ?? true {
                checkpoints.append(Checkpoint(x: x))
            }
            target += tuning.checkpointSpacing
        }
        self.checkpoints = checkpoints

        // Spirit gates: reachable with a plain jump; a bit higher on harder realms.
        var gates: [SpiritGate] = []
        let gateCount = Int(runLength / 1700)
        for _ in 0..<gateCount {
            guard !free.isEmpty else { break }
            let i = Int(rng.next() % UInt64(free.count))
            let x = free[i]
            guard clear(of: x, before: 100, after: 100) else { continue }
            free.remove(at: i)
            gates.append(SpiritGate(x: x, lift: rng.range(78, 96 + 18 * difficulty)))
        }
        self.gates = gates.sorted { $0.x < $1.x }

        // Mote trails: arcs over every other obstacle (rewarding a clean jump), lines along open ground.
        var motes: [Mote] = []
        for (n, o) in sortedObstacles.enumerated() where n % 2 == 0 {
            for k in 0..<5 {
                let t = Double(k) / 4
                let peak = o.height + 70
                motes.append(Mote(x: o.x - 90 + 180 * t, lift: 34 + (peak - 34) * (1 - pow(2 * t - 1, 2))))
            }
        }
        for x in free where !inLanding(x) && clear(of: x, before: 120, after: 120) {
            // Underwater, lines float at different depths and gently wave.
            let base = isWater ? 40 + Double(Int(x) % 7) * 18 : 30
            for k in 0..<5 {
                let wave = isWater ? sin(Double(k) * 0.9) * 14 : 0
                motes.append(Mote(x: x - 80 + Double(k) * 40, lift: base + wave))
            }
        }
        self.motes = motes.sorted { $0.x < $1.x }

        factTriggers = realm.facts.indices.map { i in
            runLength * (0.08 + 0.64 * Double(i) / Double(max(realm.facts.count - 1, 1)))
        }
    }

    /// Take-off samples (10 pt apart) that must work for a hazard to count as fairly jumpable.
    static let comfortWindow = 5
    /// Running speeds a hazard must be tap-clearable at: a little slow and fairly fast.
    static func comfortSpeeds(_ c: RunnerConfig) -> [Double] { [c.baseSpeed * 0.95, c.baseSpeed * 1.25] }

    /// Does a short hop taken at `x0` (running at `speed`, vertical push `hop`) clear obstacle `o`?
    /// Simulates the same arc the runner follows: ground velocity along the slope plus a vertical push,
    /// then gravity. Fails if the runner comes down before the obstacle or is below its top over it.
    static func hopClears(from x0: Double, obstacle o: Obstacle, speed: Double, hop: Double, gravity: Double,
                          surface: (Double) -> Double) -> Bool {
        let slope = (surface(x0 + 2) - surface(x0 - 2)) / 4
        let y0 = surface(x0)
        let vy0 = speed * slope + hop
        let top = surface(o.x) + o.height - 4
        let left = o.x - o.width / 2 - 12, right = o.x + o.width / 2 + 12
        var t = 0.0
        while true {
            t += 1.0 / 120
            let x = x0 + speed * t
            let y = y0 + vy0 * t - 0.5 * gravity * t * t
            if x >= left && x <= right { if y < top { return false } } else if x > right { return true }
            if x < left, t > 0.05, y <= surface(x) { return false }
        }
    }

    /// Where a short hop taken at `x0` comes back down onto the (gap-free) surface.
    static func hopLanding(from x0: Double, speed: Double, hop: Double, gravity: Double,
                           surface: (Double) -> Double) -> Double {
        let slope = (surface(x0 + 2) - surface(x0 - 2)) / 4
        let y0 = surface(x0)
        let vy0 = speed * slope + hop
        var t = 0.0
        while t < 3 {
            t += 1.0 / 120
            let x = x0 + speed * t
            if t > 0.05, y0 + vy0 * t - 0.5 * gravity * t * t <= surface(x) { return x }
        }
        return x0 + speed * t
    }

    func hopLanding(from x0: Double, speed: Double, config: RunnerConfig) -> Double {
        Course.hopLanding(from: x0, speed: speed, hop: config.shortJumpVelocity, gravity: config.gravity,
                          surface: surface(at:))
    }

    func hopClears(from x0: Double, obstacle o: Obstacle, speed: Double, config: RunnerConfig) -> Bool {
        Course.hopClears(from: x0, obstacle: o, speed: speed, hop: config.shortJumpVelocity,
                         gravity: config.gravity, surface: surface(at:))
    }

    /// Smooth surface height, ignoring gaps. Defined for every x (including the guardian phase).
    func surface(at x: Double) -> Double {
        Course.height(at: x, waves: waves, amplitude: amplitude)
    }

    private static func height(at x: Double, waves: [(amp: Double, freq: Double, phase: Double)],
                               amplitude: Double) -> Double {
        var h = Course.baseHeight
        for w in waves { h += amplitude * w.amp * sin(w.freq * x + w.phase) }
        // Ease the first stretch flat so the player starts calmly.
        if x < Course.safeStart {
            let t = max(x, 0) / Course.safeStart
            let ease = t * t * (3 - 2 * t)
            h = Course.baseHeight + (h - Course.baseHeight) * ease
        }
        return h
    }

    /// Ground height, or nil above a gap.
    func ground(at x: Double) -> Double? {
        if gap(at: x) != nil { return nil }
        return surface(at: x)
    }

    func slope(at x: Double) -> Double {
        let e = 2.0
        return (surface(at: x + e) - surface(at: x - e)) / (2 * e)
    }

    func gap(at x: Double) -> Gap? {
        // Few gaps per course; linear scan is cheaper than a tree here.
        for g in gaps where g.contains(x) { return g }
        return nil
    }

    var maxSurface: Double { Course.baseHeight + amplitude }
    var minSurface: Double { Course.baseHeight - amplitude }
}
