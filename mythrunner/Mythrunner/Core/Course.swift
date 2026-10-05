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
    /// World x positions where Lumi shares a fact (one per realm fact).
    let factTriggers: [Double]

    private let waves: [(amp: Double, freq: Double, phase: Double)]

    init(realm: Realm, totalRealms: Int, tuning: AgeTuning) {
        var rng = SeededRandom(seed: realm.seed)
        let difficulty = realm.difficulty(totalRealms: totalRealms)

        let runLength = 6000 + 2400 * difficulty
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

        let obstacleCount = Int(((runLength / 700) * (0.6 + 0.8 * difficulty)) * tuning.obstacleScale + 0.5)
        var obstacles: [Obstacle] = []
        for _ in 0..<min(obstacleCount, free.count / 2) {
            let x = free.removeLast() + rng.range(-60, 60)
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
