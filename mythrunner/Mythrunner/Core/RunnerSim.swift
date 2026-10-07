import Foundation

enum RunnerEvent: Equatable {
    case jumped
    case launched
    case landed(flips: Int)
    case crashed
    case fellInGap
    case hitObstacle
    case hurt          // generic heart loss (guardian hits etc.)
    case outOfHearts
}

struct RunnerConfig {
    var baseSpeed: Double
    var maxSpeed: Double
    var gravity: Double = 1500
    var jumpVelocity: Double = 600
    /// Gravity multiplier while the finger is held during the rising part of a jump.
    var holdGravityScale: Double = 0.55
    var flipAngularSpeed: Double = Double.pi * 2 / 0.85
    var landingTolerance: Double
    var flipBoost: Double = 110
    /// Upward speed from a springboard (≈1.5× a jump).
    var launchVelocity: Double = 900
    var hearts: Int
    var invulnerableTime: Double = 1.4
    var crashStunTime: Double = 0.7
    /// Radians/s the board straightens itself in the air when not flipping.
    var autoLevelSpeed: Double = 3.5

    init(difficulty: Double, tuning: AgeTuning) {
        baseSpeed = (320 + 90 * difficulty) * tuning.speedScale
        maxSpeed = baseSpeed * 1.8
        landingTolerance = tuning.landingTolerance
        hearts = tuning.hearts
    }
}

/// Alto-style slope runner. Pure math, fixed-step friendly.
/// Coordinates: x grows to the right, y grows up. Angles are radians, CCW positive.
final class RunnerSim {
    let config: RunnerConfig
    let course: Course

    private(set) var x: Double
    private(set) var y: Double
    private(set) var vy: Double = 0
    private(set) var speed: Double
    private(set) var boost: Double = 0
    private(set) var angle: Double = 0
    private(set) var grounded = true
    private(set) var airRotation: Double = 0
    private(set) var hearts: Int
    private(set) var invulnerable: Double = 0
    private(set) var stunned: Double = 0
    private(set) var totalFlips = 0
    private(set) var bestCombo = 0

    var holding = false
    var hazardsEnabled = true

    private var jumpBuffer: Double = 0
    private var coyote: Double = 0
    private var holdJumpTime: Double = 0

    var effectiveSpeed: Double { stunned > 0 ? 0 : min(speed + boost, config.maxSpeed) }
    var isAlive: Bool { hearts > 0 }
    var heightAboveGround: Double { y - course.surface(at: x) }

    init(course: Course, config: RunnerConfig, startX: Double = 80) {
        self.course = course
        self.config = config
        x = startX
        y = course.surface(at: startX)
        speed = config.baseSpeed
        hearts = config.hearts
    }

    // MARK: Input

    func press() {
        holding = true
        jumpBuffer = 0.12
    }

    func release() {
        holding = false
    }

    // MARK: Simulation

    func step(_ dt: Double, events: inout [RunnerEvent]) {
        guard isAlive else { return }
        invulnerable = max(0, invulnerable - dt)
        jumpBuffer = max(0, jumpBuffer - dt)

        if stunned > 0 {
            stunned -= dt
            if stunned <= 0 { speed = config.baseSpeed * 0.6 }
            if grounded, let g = course.ground(at: x) { y = g }
            return
        }

        boost *= exp(-dt / 1.6)
        x += effectiveSpeed * dt

        if grounded {
            stepGrounded(dt, events: &events)
        } else {
            stepAir(dt, events: &events)
        }

        if hazardsEnabled { checkObstacles(&events) }
    }

    private func stepGrounded(_ dt: Double, events: inout [RunnerEvent]) {
        guard let ground = course.ground(at: x) else {
            // Ran off a ledge into a gap.
            grounded = false
            coyote = 0.08
            vy = max(0, speed * course.slope(at: x - 4))
            return
        }

        let slope = course.slope(at: x)
        let slopeAngle = atan(slope)

        // Downhill accelerates, uphill slows; drag pulls back toward base speed.
        speed += -sin(slopeAngle) * config.gravity * 0.32 * dt
        speed += (config.baseSpeed - speed) * 0.6 * dt
        speed = min(max(speed, config.baseSpeed * 0.55), config.maxSpeed)

        // Crest launch: if the ground falls away faster than gravity would pull us, go airborne.
        let vyAlong = effectiveSpeed * slope
        let ballisticY = y + vyAlong * dt - 0.5 * config.gravity * dt * dt
        if vyAlong > 120, ground < ballisticY - 2 {
            grounded = false
            vy = vyAlong * 0.85
            y = ballisticY
            airRotation = 0
            return
        }

        y = ground
        angle = slopeAngle

        if jumpBuffer > 0 {
            jump(events: &events)
        }
    }

    private func stepAir(_ dt: Double, events: inout [RunnerEvent]) {
        coyote = max(0, coyote - dt)
        if jumpBuffer > 0, coyote > 0 {
            jump(events: &events)
        }

        var gravity = config.gravity
        if holding, vy > 0, holdJumpTime < 0.22 {
            gravity *= config.holdGravityScale
            holdJumpTime += dt
        }
        vy -= gravity * dt
        y += vy * dt

        if holding {
            let d = config.flipAngularSpeed * dt
            angle += d
            airRotation += d
        } else {
            // Alto-style auto-level: near-upright boards ease toward the slope below,
            // so plain jumps always land. A half-finished flip still crashes.
            let target = atan(course.slope(at: x + effectiveSpeed * 0.15))
            let diff = RunnerSim.wrapAngle(target - angle)
            if abs(diff) < 1.3 {
                angle += max(-config.autoLevelSpeed * dt, min(config.autoLevelSpeed * dt, diff))
            }
        }

        if let ground = course.ground(at: x) {
            if vy <= 0, y <= ground {
                land(on: ground, events: &events)
            }
        } else if y < course.minSurface - 260 {
            fall(events: &events)
        }
    }

    private func jump(events: inout [RunnerEvent]) {
        jumpBuffer = 0
        coyote = 0
        grounded = false
        holdJumpTime = 0
        airRotation = 0
        vy = config.jumpVelocity + max(0, effectiveSpeed * course.slope(at: x)) * 0.4
        events.append(.jumped)
    }

    /// Springboard: throws the runner up from the ground. Holding doesn't add float, so arcs stay predictable.
    func launch(events: inout [RunnerEvent]) {
        guard grounded, stunned <= 0 else { return }
        grounded = false
        coyote = 0
        jumpBuffer = 0
        holdJumpTime = .infinity
        airRotation = 0
        vy = config.launchVelocity
        boost += 60
        events.append(.launched)
    }

    func addBoost(_ amount: Double) {
        boost += amount
    }

    /// Restores one heart. Returns false at full health.
    @discardableResult
    func heal() -> Bool {
        guard hearts < config.hearts else { return false }
        hearts += 1
        return true
    }

    private func land(on ground: Double, events: inout [RunnerEvent]) {
        let slopeAngle = atan(course.slope(at: x))
        let diff = RunnerSim.wrapAngle(angle - slopeAngle)
        y = ground
        vy = 0
        grounded = true

        if abs(diff) <= config.landingTolerance {
            let flips = Int((airRotation + 0.6) / (Double.pi * 2))
            if flips > 0 {
                boost += config.flipBoost * Double(flips)
                totalFlips += flips
                bestCombo = max(bestCombo, flips)
            }
            angle = slopeAngle
            airRotation = 0
            events.append(.landed(flips: flips))
        } else {
            angle = slopeAngle
            airRotation = 0
            crash(events: &events, event: .crashed)
        }
    }

    private func fall(events: inout [RunnerEvent]) {
        // Respawn just past the gap.
        let gapEnd = course.gaps.first(where: { $0.start <= x && x < $0.end + 400 })?.end ?? x
        x = gapEnd + 40
        y = course.surface(at: x)
        vy = 0
        grounded = true
        angle = atan(course.slope(at: x))
        airRotation = 0
        crash(events: &events, event: .fellInGap)
    }

    private func checkObstacles(_ events: inout [RunnerEvent]) {
        guard invulnerable <= 0 else { return }
        // Obstacles are sorted; only check the ones near x.
        for o in course.obstacles {
            if o.x - o.width / 2 > x + 12 { break }
            if o.x + o.width / 2 < x - 12 { continue }
            // Compare against local ground so uphill/downhill approaches feel the same.
            if heightAboveGround < o.height - 4 {
                speed = max(config.baseSpeed * 0.55, speed * 0.55)
                boost = 0
                takeDamage(events: &events, event: .hitObstacle)
                return
            }
        }
    }

    private func crash(events: inout [RunnerEvent], event: RunnerEvent) {
        stunned = config.crashStunTime
        boost = 0
        takeDamage(events: &events, event: event, force: true)
    }

    /// Called by the guardian sim when a hazard connects.
    func hurt(events: inout [RunnerEvent]) {
        guard invulnerable <= 0 else { return }
        boost = 0
        takeDamage(events: &events, event: .hurt)
    }

    private func takeDamage(events: inout [RunnerEvent], event: RunnerEvent, force: Bool = false) {
        guard force || invulnerable <= 0 else { return }
        hearts -= 1
        invulnerable = config.invulnerableTime
        events.append(event)
        if hearts <= 0 { events.append(.outOfHearts) }
    }

    static func wrapAngle(_ a: Double) -> Double {
        var r = a.truncatingRemainder(dividingBy: Double.pi * 2)
        if r > Double.pi { r -= Double.pi * 2 }
        if r < -Double.pi { r += Double.pi * 2 }
        return r
    }
}
