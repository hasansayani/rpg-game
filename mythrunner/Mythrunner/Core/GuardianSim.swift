import Foundation

enum GuardianEvent: Equatable {
    case caught
    case projectileLaunched(id: Int)
    case projectileHit(id: Int)
    case projectileGone(id: Int)
    case weakPointSpawned(index: Int)
    case weakPointBroken(index: Int)
    case weakPointMissed(index: Int)
    case defeated
}

struct Projectile: Equatable {
    enum Kind: Equatable { case low, high }
    var id: Int
    var kind: Kind
    var x: Double
    var lift: Double            // height above the ground surface
    var speed: Double           // world units/s, moving left
    var warning: Double         // seconds of on-screen warning before it is dangerous/visible
}

struct WeakPoint: Equatable {
    var index: Int
    var x: Double
    var lift: Double
}

/// The end-of-realm guardian encounter. One sim, three selectable modes.
final class GuardianSim {
    let mode: GuardianMode
    let startX: Double
    let tuning: AgeTuning

    // Chase
    static let escapeDistance: Double = 2600
    private(set) var chaserX: Double

    // Gauntlet
    static let gauntletDuration: Double = 20
    private(set) var elapsed: Double = 0
    private var spawnTimer: Double = 1.2

    // Weak points
    static let weakPointCount = 3
    private(set) var weakPoint: WeakPoint?
    private(set) var brokenCount = 0

    private(set) var projectiles: [Projectile] = []
    private var nextID = 0
    private var rng: SeededRandom
    private(set) var finished = false

    init(mode: GuardianMode, startX: Double, tuning: AgeTuning, seed: UInt64) {
        self.mode = mode
        self.startX = startX
        self.tuning = tuning
        self.rng = SeededRandom(seed: seed ^ 0xA5A5_5A5A_DEAD_BEEF)
        chaserX = startX - 650
    }

    /// 0...1 progress through the encounter (for the HUD bar).
    func progress(runnerX: Double) -> Double {
        switch mode {
        case .chase: return min(max((runnerX - startX) / GuardianSim.escapeDistance, 0), 1)
        case .gauntlet: return min(elapsed / GuardianSim.gauntletDuration, 1)
        case .weakpoint: return Double(brokenCount) / Double(GuardianSim.weakPointCount)
        }
    }

    /// Distance from the chaser to the runner (chase mode only).
    func chaseGap(runnerX: Double) -> Double { runnerX - chaserX }

    func step(_ dt: Double, runner: RunnerSim, course: Course,
              events: inout [GuardianEvent], runnerEvents: inout [RunnerEvent]) {
        guard !finished else { return }
        elapsed += dt

        switch mode {
        case .chase:
            stepChase(dt, runner: runner, events: &events, runnerEvents: &runnerEvents)
        case .gauntlet:
            spawnTimer -= dt
            if spawnTimer <= 0 {
                spawnTimer = tuning.gauntletInterval * rng.range(0.8, 1.2)
                launch(at: runner.x + 950, kind: rng.unit() < 0.65 ? .low : .high, events: &events)
            }
            if elapsed >= GuardianSim.gauntletDuration {
                finish(&events)
            }
        case .weakpoint:
            stepWeakPoints(runner: runner, course: course, events: &events)
            spawnTimer -= dt
            // Hold fire while a weak point is close, so the player gets a clean shot at it.
            let clearShot = weakPoint.map { $0.x - runner.x < 900 } ?? false
            if spawnTimer <= 0, !clearShot {
                spawnTimer = tuning.gauntletInterval * 1.6 * rng.range(0.8, 1.2)
                launch(at: runner.x + 950, kind: .low, events: &events)
            }
        }

        stepProjectiles(dt, runner: runner, course: course, events: &events, runnerEvents: &runnerEvents)
    }

    // MARK: Modes

    private func stepChase(_ dt: Double, runner: RunnerSim,
                           events: inout [GuardianEvent], runnerEvents: inout [RunnerEvent]) {
        let gap = chaseGap(runnerX: runner.x)
        var speed = runner.config.baseSpeed * (1.0 + tuning.guardianAggression)
        // Rubber band: never fall hopelessly far behind, ease off when very close.
        if gap > 800 { speed += (gap - 800) * 0.6 }
        if gap < 160 { speed *= 0.92 }
        chaserX += speed * dt

        if gap < 40 {
            events.append(.caught)
            runner.hurt(events: &runnerEvents)
            chaserX = runner.x - 520
        }
        if runner.x - startX >= GuardianSim.escapeDistance {
            finish(&events)
        }
    }

    private func stepWeakPoints(runner: RunnerSim, course: Course, events: inout [GuardianEvent]) {
        if weakPoint == nil, brokenCount < GuardianSim.weakPointCount {
            spawnWeakPoint(at: runner.x + 1000, events: &events)
        }
        guard let wp = weakPoint else { return }

        let wy = course.surface(at: wp.x) + wp.lift
        let dx = runner.x - wp.x
        let dy = (runner.y + 24) - wy
        if dx * dx + dy * dy < 50 * 50 {
            brokenCount += 1
            weakPoint = nil
            events.append(.weakPointBroken(index: wp.index))
            if brokenCount >= GuardianSim.weakPointCount { finish(&events) }
        } else if dx > 70 {
            events.append(.weakPointMissed(index: wp.index))
            weakPoint = nil
            spawnWeakPoint(at: runner.x + 1000, events: &events)
        }
    }

    private func spawnWeakPoint(at x: Double, events: inout [GuardianEvent]) {
        let lift = tuning.band == .sprout ? 120.0 : rng.range(130, 175)
        weakPoint = WeakPoint(index: brokenCount, x: x, lift: lift)
        events.append(.weakPointSpawned(index: brokenCount))
    }

    // MARK: Projectiles

    private func launch(at x: Double, kind: Projectile.Kind, events: inout [GuardianEvent]) {
        let p = Projectile(id: nextID, kind: kind, x: x,
                           lift: kind == .low ? 16 : 92,
                           speed: rng.range(160, 240) * (tuning.band == .sprout ? 0.7 : 1.0),
                           warning: 0.9)
        nextID += 1
        projectiles.append(p)
        events.append(.projectileLaunched(id: p.id))
    }

    private func stepProjectiles(_ dt: Double, runner: RunnerSim, course: Course,
                                 events: inout [GuardianEvent], runnerEvents: inout [RunnerEvent]) {
        var i = 0
        while i < projectiles.count {
            var p = projectiles[i]
            if p.warning > 0 {
                // Hold position relative to the runner while the warning shows.
                p.warning -= dt
                p.x += runner.effectiveSpeed * dt
            } else {
                p.x -= p.speed * dt
            }

            let py = course.surface(at: p.x) + p.lift
            let dx = abs(p.x - runner.x)
            // Runner body spans roughly y...y+44.
            let hit = p.warning <= 0 && dx < 22 && py > runner.y - 6 && py < runner.y + 44

            if hit {
                events.append(.projectileHit(id: p.id))
                runner.hurt(events: &runnerEvents)
                projectiles.remove(at: i)
                continue
            }
            if p.x < runner.x - 600 {
                events.append(.projectileGone(id: p.id))
                projectiles.remove(at: i)
                continue
            }
            projectiles[i] = p
            i += 1
        }
    }

    private func finish(_ events: inout [GuardianEvent]) {
        guard !finished else { return }
        finished = true
        for p in projectiles { events.append(.projectileGone(id: p.id)) }
        projectiles.removeAll()
        weakPoint = nil
        events.append(.defeated)
    }
}
