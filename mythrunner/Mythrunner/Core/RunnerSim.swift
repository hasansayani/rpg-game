import Foundation

enum RunnerEvent: Equatable {
    case jumped
    case launched
    case landed(flips: Int)
    /// Speed (pt/s) at which the body hit the ground, along the ground normal. Sent with every landing.
    case impact(Double)
    /// A hard or over-rotated landing: no damage, but the runner staggers and slows.
    case stumbled
    /// Came down on top of an obstacle and bounced off it.
    case bounced
    /// A new swim stroke (water realms).
    case stroke
    case crashed
    case fellInGap
    case hitObstacle
    case hurt          // hit by the guardian or its attacks
}

struct RunnerConfig {
    var baseSpeed: Double
    var maxSpeed: Double
    var gravity: Double = 1500
    /// Vertical push-off impulse: a tap gives a short hop, a full crouch a big jump.
    var shortJumpVelocity: Double = 520
    var longJumpVelocity: Double = 780
    /// Crouch time for a full-power jump; holding this long fires it automatically.
    var fullChargeTime: Double = 0.22
    /// Swimming: a press is a quick upward kick.
    var swimKick: Double = 280
    /// Fraction of the uphill/downhill slope force a runner feels (legs absorb most of it).
    var slopeFactor: Double = 0.2
    var landingTolerance: Double
    var flipBoost: Double = 110
    /// Upward speed from a springboard.
    var launchVelocity: Double = 900
    /// Grace period after respawning at a checkpoint.
    var respawnGrace: Double = 0.8
    var stumbleTime: Double = 0.4
    /// Landing on an obstacle: fraction of downward speed returned, plus a small upward kick.
    var bounceRestitution: Double = 0.55
    var bounceKick: Double = 220

    // Rigid-body rotation in the air. Angular momentum L = I·ω is conserved except for
    // the flip torque (while held), light air damping and the balance reflex near upright.
    /// Moment of inertia while tucked (holding) and while open (released).
    var tuckInertia: Double = 1.0
    var openInertia: Double = 2.4
    /// Angular impulse per second while holding (arm swing / hip drive).
    var flipTorque: Double = 40
    /// Top tucked spin rate, rad/s (≈ one flip in 0.7 s).
    var maxSpin: Double = Double.pi * 2 / 0.7
    var airSpinDamping: Double = 0.35
    /// Balance reflex (a PD controller) that steadies an open body near upright.
    var balanceStiffness: Double = 28
    var balanceDamping: Double = 7
    var balanceRange: Double = 0.9
    /// Height of the center of mass above the feet when standing.
    var comHeight: Double = 22
    /// Normal impact speed above which a clean landing still makes the runner stumble.
    var hardImpact: Double = 1050
    /// Spin rate above which a clean landing still makes the runner stumble.
    var hardSpin: Double = 7

    // Swimming (water realms): thrust while held, buoyancy-adjusted sink, and water drag.
    var swimThrust: Double = 1300
    var swimSink: Double = 520
    var swimDrag: Double = 2.0
    var strokeBoost: Double = 30
    var strokeCooldown: Double = 0.3
    /// Swimmer body height (belly line to back), used against the water ceiling.
    static let swimBodyHeight: Double = 28

    init(difficulty: Double, tuning: AgeTuning) {
        baseSpeed = (320 + 90 * difficulty) * tuning.speedScale
        maxSpeed = baseSpeed * 1.8
        landingTolerance = tuning.landingTolerance
    }
}

/// The Wayfarer on foot (or swimming, in water realms). Pure math, fixed-step friendly.
/// Coordinates: x grows to the right, y grows up. Angles are radians, CCW positive (a backflip).
/// `y` is the feet line of the upright body; the center of mass sits `comHeight` above it. In the
/// air the COM follows a parabola and the body rotates about it with conserved angular momentum.
final class RunnerSim {
    let config: RunnerConfig
    let course: Course

    private(set) var x: Double
    private(set) var y: Double
    private(set) var vy: Double = 0
    /// Horizontal speed (ground speed when grounded; conserved in the air).
    private(set) var speed: Double
    private(set) var boost: Double = 0
    private(set) var angle: Double = 0
    /// Angular velocity, rad/s.
    private(set) var spin: Double = 0
    private(set) var grounded = true
    private(set) var airRotation: Double = 0
    /// Set when the runner fails (hit, crash, fall). The session respawns it at a checkpoint.
    private(set) var failed = false
    private(set) var invulnerable: Double = 0
    private(set) var stumbling: Double = 0
    private(set) var totalFlips = 0
    private(set) var bestCombo = 0

    var holding = false
    var hazardsEnabled = true

    private var jumpBuffer: Double = 0
    private var coyote: Double = 0
    /// Seconds spent crouching for a jump (nil when not crouching).
    private(set) var crouch: Double?
    /// 0…1 crouch depth, for the renderer.
    var crouchAmount: Double { min((crouch ?? 0) / config.fullChargeTime, 1) }
    private var angularMomentum: Double = 0
    private var strokeTimer: Double = 0
    private var strokePending = false
    /// Set for the step in which the runner bounced off an obstacle top.
    private var bouncedThisStep = false

    var swimming: Bool { course.isWater }
    var effectiveSpeed: Double {
        let v = min(speed + boost, config.maxSpeed)
        return stumbling > 0 ? v * 0.65 : v
    }
    var heightAboveGround: Double { y - course.surface(at: x) }
    /// True while tucked into a flip (for the renderer).
    var tucked: Bool { !grounded && !swimming && holding }

    init(course: Course, config: RunnerConfig, startX: Double = 80) {
        self.course = course
        self.config = config
        x = startX
        y = course.surface(at: startX)
        speed = config.baseSpeed
        if course.isWater { y += 90; grounded = false }
    }

    // MARK: Input

    /// Land: press crouches; releasing fires the jump (short tap → short hop), and a long press fires a
    /// full jump at full crouch. Still holding in the air tucks into a flip.
    /// Water: each press is a quick upward kick with a burst of speed; holding keeps swimming up.
    func press() {
        if swimming, !holding, strokeTimer <= 0 {
            strokeTimer = config.strokeCooldown
            boost += config.strokeBoost
            vy = max(vy, 0) + config.swimKick
            strokePending = true
        }
        holding = true
        jumpBuffer = 0.12
    }

    func release() {
        holding = false
    }

    // MARK: Simulation

    func step(_ dt: Double, events: inout [RunnerEvent]) {
        guard !failed else { return }
        invulnerable = max(0, invulnerable - dt)
        jumpBuffer = max(0, jumpBuffer - dt)
        stumbling = max(0, stumbling - dt)

        if swimming {
            stepSwim(dt, events: &events)
            if hazardsEnabled { checkObstacles(&events); checkHangers(&events) }
            return
        }


        let prevX = x, prevY = y
        if grounded {
            // Boost bleeds off through the legs; in the air there is nothing to push against.
            boost *= exp(-dt / 1.6)
            x += effectiveSpeed * dt
            stepGrounded(dt, events: &events)
        } else {
            x += effectiveSpeed * dt
            stepAir(dt, prevX: prevX, prevY: prevY, events: &events)
        }

        if hazardsEnabled, !bouncedThisStep { checkObstacles(&events) }
        bouncedThisStep = false
    }

    /// Lean of the body for a given slope: runners stay mostly upright, leaning a little into hills.
    private func lean(forSlope s: Double) -> Double { atan(s) * 0.3 }

    private func stepGrounded(_ dt: Double, events: inout [RunnerEvent]) {
        guard let ground = course.ground(at: x) else {
            if let c = crouch {
                let t = min(c / config.fullChargeTime, 1)
                jump(slope: course.slope(at: x - 4),
                     power: config.shortJumpVelocity + (config.longJumpVelocity - config.shortJumpVelocity) * t, events: &events)
                return
            }
            // Ran off a ledge into a gap: keep the velocity we had along the slope.
            leaveGround(vy: effectiveSpeed * course.slope(at: x - 4))
            coyote = 0.08
            return
        }

        let slope = course.slope(at: x)
        let slopeAngle = atan(slope)

        // Gravity along the slope (felt only partly by a runner), then drag back toward a cruising pace.
        speed += -sin(slopeAngle) * config.gravity * config.slopeFactor * dt
        speed += (config.baseSpeed - speed) * 0.6 * dt
        speed = min(max(speed, config.baseSpeed * 0.55), config.maxSpeed)

        // A runner's legs keep contact over crests (unlike a board), so the feet follow the ground.
        y = ground
        angle = lean(forSlope: slope)
        takeoff(slope: slope, dt: dt, events: &events)
    }

    private func leaveGround(vy newVy: Double) {
        crouch = nil
        grounded = false
        vy = newVy
        airRotation = 0
        angularMomentum = 0
        spin = 0
    }

    private func stepAir(_ dt: Double, prevX: Double, prevY: Double, events: inout [RunnerEvent]) {
        coyote = max(0, coyote - dt)
        // Just ran off an edge: a press still counts as a (short) jump.
        if jumpBuffer > 0, coyote > 0 {
            jump(slope: 0, power: config.shortJumpVelocity, events: &events)
        }

        // Center of mass: pure projectile motion.
        vy -= config.gravity * dt
        y += vy * dt

        // Rotation: torque from the flip input, then I·ω = L with I depending on tuck.
        let inertia = holding ? config.tuckInertia : config.openInertia
        if holding {
            angularMomentum = min(angularMomentum + config.flipTorque * dt, config.tuckInertia * config.maxSpin)
        } else {
            angularMomentum *= exp(-config.airSpinDamping * dt)
            // Balance reflex: an open body near upright steers itself toward a clean stance.
            let target = lean(forSlope: course.slope(at: x + effectiveSpeed * 0.15))
            let diff = RunnerSim.wrapAngle(angle - target)
            if abs(diff) < config.balanceRange {
                let torque = -config.balanceStiffness * diff - config.balanceDamping * spin
                angularMomentum += torque * inertia * dt
            }
        }
        spin = angularMomentum / inertia
        angle += spin * dt
        airRotation += spin * dt

        // Contact uses the body's lowest point, which moves as it rotates about the COM.
        let reach = config.comHeight * abs(cos(RunnerSim.wrapAngle(angle)))
        let lowest = y + config.comHeight - reach

        // Coming down onto a rock from above: bounce off it (partly elastic, with a small kick up),
        // keeping horizontal momentum. No damage; the bounce usually carries the runner past it.
        if vy <= 0, hazardsEnabled, let o = obstacle(at: x) {
            let t = top(of: o)
            if prevY >= t - 2, lowest <= t {
                y = t - config.comHeight + reach
                vy = -vy * config.bounceRestitution + config.bounceKick
                bouncedThisStep = true
                angularMomentum *= 0.5
                events.append(.bounced)
                return
            }
        }

        if let ground = course.ground(at: x) {
            if course.gap(at: prevX) != nil, prevY + config.comHeight - reach < ground - 6 {
                // Came out of the chasm below its far rim: hit the wall and fall.
                fall(events: &events)
                return
            }
            if lowest <= ground {
                // Find the moment of contact within this step so the body never sinks into the slope.
                var lo = 0.0, hi = 1.0
                for _ in 0..<8 {
                    let mid = (lo + hi) / 2
                    let mx = prevX + (x - prevX) * mid
                    let my = prevY + (y - prevY) * mid + config.comHeight - reach
                    if my > course.surface(at: mx) { lo = mid } else { hi = mid }
                }
                x = prevX + (x - prevX) * hi
                // Never land inside a chasm: contact is on the far rim at the earliest.
                if let gap = course.gap(at: x) { x = gap.end + 0.5 }
                land(at: course.surface(at: x), slope: course.slope(at: x), events: &events)
            }
        } else if y < course.minSurface - 260 {
            fall(events: &events)
        }
    }

    /// Crouch-and-push takeoff. The longer the crouch, the bigger the impulse (up to full power).
    private func takeoff(slope: Double, dt: Double, events: inout [RunnerEvent]) {
        if crouch == nil, jumpBuffer > 0 {
            jumpBuffer = 0
            guard holding else {
                // Tapped and already let go: short hop right away.
                jump(slope: slope, power: config.shortJumpVelocity, events: &events)
                return
            }
            crouch = 0
        }
        guard let c = crouch else { return }
        let held = c + dt
        let t = min(held / config.fullChargeTime, 1)
        if !holding || held >= config.fullChargeTime {
            let power = config.shortJumpVelocity + (config.longJumpVelocity - config.shortJumpVelocity) * t
            jump(slope: slope, power: power, events: &events)
        } else {
            crouch = held
        }
    }

    private func jump(slope: Double, power: Double, events: inout [RunnerEvent]) {
        crouch = nil
        jumpBuffer = 0
        coyote = 0
        // Velocity along the ground (momentum is kept) plus a vertical push-off from the legs.
        leaveGround(vy: effectiveSpeed * slope + power)
        events.append(.jumped)
    }

    private func land(at height: Double, slope s: Double, events: inout [RunnerEvent]) {
        let vx = effectiveSpeed
        let n = sqrt(1 + s * s)
        // Split velocity into normal (absorbed by the legs) and tangential (kept) parts.
        let impact = max(0, -(vy - vx * s) / n)
        let tangentialVx = (vx + vy * s) / (1 + s * s)
        let diff = RunnerSim.wrapAngle(angle - lean(forSlope: s))
        let landingSpin = abs(spin)

        y = height
        vy = 0
        grounded = true
        spin = 0
        angularMomentum = 0
        events.append(.impact(impact))

        guard abs(diff) <= config.landingTolerance else {
            angle = lean(forSlope: s)
            airRotation = 0
            crash(events: &events, event: .crashed)
            return
        }

        // Keep most of the tangential momentum: downhill landings speed you up, uphill ones slow you.
        speed = min(max(speed + (tangentialVx - vx) * 0.7, config.baseSpeed * 0.55), config.maxSpeed)

        let flips = Int((airRotation + 0.6) / (Double.pi * 2))
        if flips > 0 {
            boost += config.flipBoost * Double(flips)
            totalFlips += flips
            bestCombo = max(bestCombo, flips)
        }
        angle = lean(forSlope: s)
        airRotation = 0
        events.append(.landed(flips: flips))

        if impact > config.hardImpact || landingSpin > config.hardSpin {
            stumbling = config.stumbleTime
            boost *= 0.5
            events.append(.stumbled)
        }
    }

    // MARK: Swimming

    private func stepSwim(_ dt: Double, events: inout [RunnerEvent]) {
        strokeTimer = max(0, strokeTimer - dt)
        if strokePending { strokePending = false; events.append(.stroke) }

        boost *= exp(-dt / 1.6)
        speed += (config.baseSpeed - speed) * 0.6 * dt
        x += effectiveSpeed * dt

        // Thrust while held, net sink otherwise, and water drag on vertical speed.
        if holding { vy += config.swimThrust * dt }
        vy -= config.swimSink * dt
        vy *= exp(-config.swimDrag * dt)
        y += vy * dt

        let floor = course.surface(at: x)
        if y < floor { y = floor; vy = max(vy, 0) }
        let ceiling = course.waterSurface - RunnerConfig.swimBodyHeight
        if y > ceiling { y = ceiling; vy = min(vy, 0) }
        grounded = y <= floor + 0.5
        // The body pitches toward its direction of travel.
        angle = atan2(vy, max(effectiveSpeed, 1)) * 0.7
    }

    private func checkHangers(_ events: inout [RunnerEvent]) {
        guard invulnerable <= 0, !failed else { return }
        for h in course.hangers {
            if h.x - h.width / 2 > x + 16 { break }
            if h.x + h.width / 2 < x - 16 { continue }
            if y + RunnerConfig.swimBodyHeight > course.waterSurface - h.length + 4 {
                boost = 0
                fail(events: &events, event: .hitObstacle)
                return
            }
        }
    }

    // MARK: Hazards

    private func top(of o: Obstacle) -> Double { course.surface(at: o.x) + o.height }

    private func obstacle(at x: Double) -> Obstacle? {
        for o in course.obstacles {
            if o.x - o.width / 2 > x { break }
            if abs(o.x - x) <= o.width / 2 { return o }
        }
        return nil
    }

    /// Springboard: throws the runner up from the ground.
    func launch(events: inout [RunnerEvent]) {
        guard grounded, !swimming else { return }
        jumpBuffer = 0
        leaveGround(vy: config.launchVelocity)
        coyote = 0
        boost += 60
        events.append(.launched)
    }

    func addBoost(_ amount: Double) {
        boost += amount
    }

    private func fall(events: inout [RunnerEvent]) {
        crash(events: &events, event: .fellInGap)
    }

    private func checkObstacles(_ events: inout [RunnerEvent]) {
        guard invulnerable <= 0, !failed else { return }
        // Obstacles are sorted; only check the ones near x.
        for o in course.obstacles {
            if o.x - o.width / 2 > x + 12 { break }
            if o.x + o.width / 2 < x - 12 { continue }
            // Hit only if the feet are actually below the obstacle's top (absolute, so slopes are fair).
            if y < top(of: o) - 4 {
                fail(events: &events, event: .hitObstacle)
                return
            }
        }
    }

    private func crash(events: inout [RunnerEvent], event: RunnerEvent) {
        crouch = nil
        fail(events: &events, event: event, force: true)
    }

    /// Called by the guardian sim when a hazard connects.
    func hurt(events: inout [RunnerEvent]) {
        fail(events: &events, event: .hurt)
    }

    /// No hearts: any failure freezes the runner until the session moves it back to a checkpoint.
    private func fail(events: inout [RunnerEvent], event: RunnerEvent, force: Bool = false) {
        guard !failed, force || invulnerable <= 0 else { return }
        failed = true
        boost = 0
        events.append(event)
    }

    /// Puts the runner back on its feet (or in the water) at `checkpointX`, with a short grace period.
    func respawn(at checkpointX: Double) {
        x = checkpointX
        y = course.surface(at: x) + (swimming ? 90 : 0)
        vy = 0
        speed = config.baseSpeed
        boost = 0
        angle = 0
        spin = 0
        angularMomentum = 0
        airRotation = 0
        grounded = !swimming
        crouch = nil
        jumpBuffer = 0
        coyote = 0
        stumbling = 0
        failed = false
        strokeTimer = 0
        strokePending = false
        // Start fresh: a finger still down from the failure doesn't count as a new press.
        holding = false
        invulnerable = config.respawnGrace
    }

    static func wrapAngle(_ a: Double) -> Double {
        var r = a.truncatingRemainder(dividingBy: Double.pi * 2)
        if r > Double.pi { r -= Double.pi * 2 }
        if r < -Double.pi { r += Double.pi * 2 }
        return r
    }
}
