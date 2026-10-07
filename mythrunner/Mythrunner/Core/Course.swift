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

/// A shrine with a pillar of light: riding through it (on the ground or jumping) restores one heart,
/// or boosts at full health.
struct HeartShrine: Equatable {
    var x: Double
    var lift: Double
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
    let shrines: [HeartShrine]
    /// World x positions where Lumi shares a fact (one per realm fact).
    let factTriggers: [Double]

    /// How far a springboard throws the runner; the landing zone after one is kept hazard-free.
    static let springboardClearance: Double = 750

    private let waves: [(amp: Double, freq: Double, phase: Double)]

    init(realm: Realm, totalRealms: Int, tuning: AgeTuning) {
        var rng = SeededRandom(seed: realm.seed)
        let difficulty = realm.difficulty(totalRealms: totalRealms)

        let runLength = 10000 + 4000 * difficulty
        self.runLength = runLength
        let f = realm.scenery.frequency
        let twoPi = Double.pi * 2
        let waves: [(amp: Double, freq: Double, phase: Double)] = [
            (0.55, twoPi / (1100 / f), rng.range(0, twoPi)),
            (0.30, twoPi / (520 / f), rng.range(0, twoPi)),
            (0.15, twoPi / (260 / f), rng.range(0, twoPi)),
        ]
        self.waves = waves

        // Kids get gentler hills. Content can never exceed the max slope (keeps every realm rideable).
        var amp = realm.scenery.amplitude * (tuning.band == .sprout ? 0.75 : 1.0)
        let worstSlope = amp * waves.reduce(0) { $0 + $1.amp * $1.freq }
        if worstSlope > Course.maxSlope { amp *= Course.maxSlope / worstSlope }
        amplitude = amp

        // Hazards are placed on a slot grid so they never overlap each other.
        let slot = 320.0
        let slotCount = Int((runLength - Course.safeStart - 400) / slot)
        var free = Array(0..<max(slotCount, 0)).map { Course.safeStart + Double($0) * slot + slot / 2 }
        // Shuffle deterministically.
        for i in stride(from: free.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            free.swapAt(i, j)
        }

        let gapCount = Int((1 + 4 * difficulty) * tuning.gapScale + 0.5)
        var gaps: [Gap] = []
        let localWaves = waves, localAmplitude = amp
        func rise(across width: Double, at center: Double) -> Double {
            Course.height(at: center + width / 2, waves: localWaves, amplitude: localAmplitude)
                - Course.height(at: center - width / 2, waves: localWaves, amplitude: localAmplitude)
        }
        // Chasms only where the far edge isn't higher than the takeoff (always jumpable).
        var candidates = free.indices.reversed().makeIterator()
        var used: [Int] = []
        while gaps.count < min(gapCount, free.count / 3), let i = candidates.next() {
            let width = rng.range(100, 150 + 60 * difficulty)
            if rise(across: width, at: free[i]) <= 4 {
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
        let springCount = Int(runLength / 3200)
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
        let sortedObstacles = obstacles.sorted { $0.x < $1.x }
        self.obstacles = sortedObstacles

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
        }
        func inLanding(_ x: Double) -> Bool {
            springboards.contains { x > $0.x && x < $0.x + Course.springboardClearance }
        }
        func take(where ok: (Double) -> Bool) -> Double? {
            guard let i = free.firstIndex(where: ok) else { return nil }
            return free.remove(at: i)
        }

        // A shrine just before halfway, when the run starts to bite.
        // The longest (late-game) runs get a second one at about three quarters.
        var shrines: [HeartShrine] = []
        for start in runLength > 12500 ? [0.45, 0.72] : [0.45] {
            if let x = take(where: { $0 > runLength * start && !inLanding($0) && clear(of: $0, before: 140, after: 140) }) {
                shrines.append(HeartShrine(x: x, lift: 46))
            }
        }
        self.shrines = shrines

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
            for k in 0..<5 { motes.append(Mote(x: x - 80 + Double(k) * 40, lift: 30)) }
        }
        self.motes = motes.sorted { $0.x < $1.x }

        factTriggers = realm.facts.indices.map { i in
            runLength * (0.08 + 0.64 * Double(i) / Double(max(realm.facts.count - 1, 1)))
        }
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
