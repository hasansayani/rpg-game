import XCTest
@testable import MythrunnerCore

/// Focused, deterministic tests of the runner's mechanics (jump charge, rotation, landing, bounce,
/// swimming), checkpoint/respawn rules, course invariants and progress. Fixed dt of 1/120.
final class MechanicsTests: XCTestCase {
    static let dt = 1.0 / 120
    private static var cached: RealmCatalog?

    private func catalog() throws -> RealmCatalog {
        if let c = Self.cached { return c }
        let c = try loadCatalog()
        Self.cached = c
        return c
    }

    private func course(_ realm: Realm, band: AgeBand = .explorer, variation: UInt64 = 0) -> Course {
        Course(realm: realm, totalRealms: 30, tuning: .forBand(band), variation: variation)
    }

    private func runner(_ realm: Realm, band: AgeBand = .explorer, variation: UInt64 = 0,
                        startX: Double = 80) -> RunnerSim {
        let tuning = AgeTuning.forBand(band)
        return RunnerSim(course: course(realm, band: band, variation: variation),
                         config: RunnerConfig(difficulty: realm.difficulty(totalRealms: 30), tuning: tuning),
                         startX: startX)
    }

    private func landRealm() throws -> Realm { try catalog().realms.first { !$0.isWater }! }
    private func waterRealm() throws -> Realm { try XCTUnwrap(catalog().realms.first { $0.isWater }) }

    @discardableResult
    private func step(_ r: RunnerSim, _ n: Int = 1) -> [RunnerEvent] {
        var all: [RunnerEvent] = []
        for _ in 0..<n {
            var ev: [RunnerEvent] = []
            r.step(Self.dt, events: &ev)
            all += ev
        }
        return all
    }

    // MARK: Crouch-charged jump

    /// Returns the vertical push-off (vy minus the slope component) and the frame the jump fired on.
    private func jumpPower(holdFrames: Int?) throws -> (power: Double, frame: Int, runner: RunnerSim) {
        let r = runner(try landRealm())
        r.press()
        if holdFrames == 0 { r.release() }
        for frame in 1...200 {
            if let h = holdFrames, h > 0, frame == h + 1 { r.release() }
            let ev = step(r)
            if ev.contains(.jumped) {
                return (r.vy - r.effectiveSpeed * r.course.slope(at: r.x), frame, r)
            }
        }
        XCTFail("never jumped")
        return (0, 0, r)
    }

    func testTapGivesExactlyTheShortJump() throws {
        let (power, frame, r) = try jumpPower(holdFrames: 0)
        XCTAssertEqual(power, r.config.shortJumpVelocity, accuracy: 1e-6)
        XCTAssertEqual(frame, 1, "a tap jumps on the very next step")
    }

    func testJumpPowerGrowsWithHoldTime() throws {
        let cfg = try jumpPower(holdFrames: 0).runner.config
        var last = cfg.shortJumpVelocity
        for hold in [3, 8, 13, 18, 23] {
            let (power, frame, _) = try jumpPower(holdFrames: hold)
            XCTAssertEqual(frame, hold + 1, "jump fires on the step after release")
            XCTAssertGreaterThan(power, last, "more crouch = more power (hold \(hold))")
            XCTAssertGreaterThan(power, cfg.shortJumpVelocity)
            XCTAssertLessThan(power, cfg.longJumpVelocity)
            let t = min(Double(hold + 1) * Self.dt / cfg.fullChargeTime, 1)
            XCTAssertEqual(power, cfg.shortJumpVelocity + (cfg.longJumpVelocity - cfg.shortJumpVelocity) * t,
                           accuracy: 1e-6)
            last = power
        }
    }

    func testLongPressAutoFiresFullJumpAtFullCharge() throws {
        let (power, frame, r) = try jumpPower(holdFrames: nil)
        XCTAssertEqual(power, r.config.longJumpVelocity, accuracy: 1e-6)
        XCTAssertEqual(frame, Int((r.config.fullChargeTime / Self.dt).rounded(.up)))
        XCTAssertTrue(r.holding, "still holding: the jump fired by itself")
        XCTAssertNil(r.crouch)
    }

    func testCrouchAmountTracksHoldTime() throws {
        let r = runner(try landRealm())
        r.press()
        step(r, 13)
        XCTAssertTrue(r.grounded)
        XCTAssertEqual(r.crouchAmount, 13 * Self.dt / r.config.fullChargeTime, accuracy: 1e-9)
    }

    func testPressJustBeforeLandingIsBufferedIntoAJump() throws {
        let r = runner(try landRealm())
        r.press(); r.release()
        XCTAssertTrue(step(r).contains(.jumped))
        var pressed = false
        for _ in 0..<200 where !pressed {
            step(r)
            if !r.grounded, r.vy < 0, r.heightAboveGround < 25 { r.press(); r.release(); pressed = true }
        }
        XCTAssertTrue(pressed)
        let ev = step(r, 30)
        let landedAt = try XCTUnwrap(ev.firstIndex(of: .landed(flips: 0)))
        let jumpedAt = try XCTUnwrap(ev.firstIndex(of: .jumped), "buffered press should jump on landing")
        XCTAssertLessThan(landedAt, jumpedAt)
    }

    func testPressTooEarlyInTheAirIsNotBuffered() throws {
        let r = runner(try landRealm())
        r.press(); r.release()
        step(r)
        // At the apex the landing is ~0.35 s away, longer than the 0.12 s buffer.
        while r.vy > 0 { step(r) }
        r.press(); r.release()
        let ev = step(r, 120)
        XCTAssertTrue(ev.contains(.landed(flips: 0)))
        XCTAssertFalse(ev.contains(.jumped))
    }

    private func courseWithGap() throws -> (Realm, Gap) {
        for realm in try catalog().realms where !realm.isWater {
            if let g = course(realm).gaps.first { return (realm, g) }
        }
        throw XCTSkip("no gaps in any course")
    }

    func testCoyoteJumpAfterRunningOffAnEdge() throws {
        let (realm, gap) = try courseWithGap()
        let r = runner(realm, startX: gap.start - 20)
        var steps = 0
        while r.grounded, steps < 60 { step(r); steps += 1 }
        XCTAssertFalse(r.grounded)
        XCTAssertGreaterThan(r.x, gap.start)
        r.press(); r.release()
        let ev = step(r)
        XCTAssertTrue(ev.contains(.jumped), "a press just after the edge still jumps")
        XCTAssertEqual(r.vy, r.config.shortJumpVelocity - r.config.gravity * Self.dt, accuracy: 1e-6)
    }

    func testNoCoyoteJumpLongAfterTheEdge() throws {
        let (realm, gap) = try courseWithGap()
        let r = runner(realm, startX: gap.start - 20)
        while r.grounded { step(r) }
        step(r, 12)  // 0.1 s > coyote time
        r.press(); r.release()
        XCTAssertFalse(step(r, 5).contains(.jumped))
    }

    // MARK: Rigid-body rotation

    func testTuckTorqueRampsSpinUpToTheCap() throws {
        let r = runner(try landRealm())
        r.press()
        while r.grounded { step(r) }  // long press auto-fires
        var spins: [Double] = []
        for _ in 0..<40 where !r.grounded { step(r); spins.append(r.spin) }
        XCTAssertEqual(spins[0], r.config.flipTorque * Self.dt / r.config.tuckInertia, accuracy: 1e-9)
        for (a, b) in zip(spins, spins.dropFirst()) { XCTAssertGreaterThanOrEqual(b, a - 1e-12) }
        XCTAssertLessThanOrEqual(spins.max()!, r.config.maxSpin + 1e-9)
        XCTAssertEqual(spins.last!, r.config.maxSpin, accuracy: 1e-9, "spin is capped at maxSpin")
    }

    func testOpeningUpConservesAngularMomentum() throws {
        let r = runner(try landRealm())
        r.press()
        while r.grounded { step(r) }
        // Wait until the body is far from upright (balance reflex inactive) and spinning flat out.
        var guardSteps = 0
        while RunnerSim.wrapAngle(r.angle) < 1.3 || RunnerSim.wrapAngle(r.angle) > 2.6 {
            step(r); guardSteps += 1
            XCTAssertLessThan(guardSteps, 200); if guardSteps >= 200 { return }
        }
        XCTAssertFalse(r.grounded)
        let tuckedSpin = r.spin
        XCTAssertEqual(tuckedSpin, r.config.maxSpin, accuracy: 1e-9)
        r.release()
        step(r)
        let expected = tuckedSpin * r.config.tuckInertia / r.config.openInertia * exp(-r.config.airSpinDamping * Self.dt)
        XCTAssertEqual(r.spin, expected, accuracy: 1e-9, "L = I·ω is conserved when opening up")
        XCTAssertEqual(r.spin * r.config.openInertia, tuckedSpin * r.config.tuckInertia, accuracy: 0.05,
                       "only light air damping is lost")
    }

    func testPlainHopLandsWithNoFlipsAndNoStumble() throws {
        let r = runner(try landRealm())
        r.press(); r.release()
        var ev: [RunnerEvent] = []
        for _ in 0..<240 { ev += step(r); if r.grounded && ev.contains(.jumped) { break } }
        XCTAssertTrue(ev.contains(.landed(flips: 0)))
        XCTAssertFalse(ev.contains(.crashed))
        XCTAssertFalse(ev.contains(.stumbled))
        XCTAssertFalse(r.failed)
        XCTAssertEqual(r.totalFlips, 0)
        XCTAssertEqual(r.spin, 0)
        // Every landing reports its impact first.
        let impactIndex = try XCTUnwrap(ev.firstIndex { if case .impact = $0 { return true }; return false })
        XCTAssertLessThan(impactIndex, ev.firstIndex(of: .landed(flips: 0))!)
    }

    // MARK: Landing outcomes

    func testHighSpinCleanLandingStumblesButDoesNotFail() throws {
        // Big jump, open up, then tuck again at different moments: some landings come in upright
        // but spinning fast (stumble), others over-rotated (crash).
        let realm = try landRealm()
        var stumbled = false, crashed = false
        for tuckAfter in stride(from: 0, to: 130, by: 2) {
            let r = runner(realm)
            r.press()
            while r.grounded { step(r) }
            r.release()
            var ev: [RunnerEvent] = []
            var frame = 0
            while !r.grounded, !r.failed, frame < 300 {
                if frame == tuckAfter { r.press() }
                ev += step(r); frame += 1
            }
            if ev.contains(.crashed) {
                crashed = true
                XCTAssertTrue(r.failed)
                XCTAssertFalse(ev.contains { if case .landed = $0 { return true }; return false },
                               "a crash is not a landing")
            } else if ev.contains(.stumbled) {
                stumbled = true
                XCTAssertFalse(r.failed, "a stumble is not a failure")
                XCTAssertGreaterThan(r.stumbling, 0)
                XCTAssertEqual(r.effectiveSpeed, min(r.speed + r.boost, r.config.maxSpeed) * 0.65, accuracy: 1e-9)
            }
        }
        XCTAssertTrue(stumbled, "no tuck timing produced an upright, fast-spinning landing")
        XCTAssertTrue(crashed, "no tuck timing produced an over-rotated crash")
    }

    func testHardImpactStumblesButDoesNotFail() throws {
        // Springboard launches onto lower ground hit hard. Any clean landing above hardImpact must stumble.
        var found = false
        realms: for realm in try catalog().realms where !realm.isWater {
            let c = course(realm)
            for x in stride(from: 1000.0, to: c.runLength, by: 40) where c.gap(at: x) == nil {
                let r = runner(realm, startX: x)
                r.hazardsEnabled = false
                var ev: [RunnerEvent] = []
                r.launch(events: &ev)
                XCTAssertEqual(ev, [.launched])
                var frame = 0
                while !r.grounded, !r.failed, frame < 400 { ev += step(r); frame += 1 }
                guard ev.contains(where: { if case .landed = $0 { return true }; return false }) else { continue }
                for case .impact(let v) in ev where v > r.config.hardImpact {
                    XCTAssertTrue(ev.contains(.stumbled), "\(realm.id) x=\(x): impact \(v) without stumble")
                    XCTAssertFalse(r.failed)
                    found = true
                    break realms
                }
            }
        }
        XCTAssertTrue(found, "no launch produced a hard impact")
    }

    func testCrashRespawnsAtStartAfterRespawnDelay() throws {
        let cat = try catalog()
        let session = RunSession(realm: cat.realms[0], totalRealms: 30, tuning: .forBand(.explorer),
                                 mode: .chase, companion: cat.companion)
        var events = SessionEvents()
        // Hold the whole time: full jump + tuck all the way down over-rotates (≈ 8.3 rad) and crashes.
        session.press()
        var failedTick: Int?, respawnTick: Int?
        for tick in 0..<600 {
            events.clear()
            session.advance(Self.dt, into: &events)
            if events.failed {
                XCTAssertNil(failedTick, "only one failure expected")
                failedTick = tick
                XCTAssertTrue(events.runner.contains(.crashed))
            }
            if events.respawned { respawnTick = tick; break }
        }
        let f = try XCTUnwrap(failedTick), s = try XCTUnwrap(respawnTick)
        XCTAssertEqual(Double(s - f) * Self.dt, RunSession.respawnDelay, accuracy: 2 * Self.dt)
        XCTAssertEqual(session.runner.x, 80, accuracy: 0.001, "no checkpoint yet: back to the start line")
        XCTAssertFalse(session.runner.failed)
        XCTAssertTrue(session.runner.grounded)
        XCTAssertEqual(session.runner.invulnerable, session.runner.config.respawnGrace, accuracy: 1e-9)
        XCTAssertEqual(session.retries, 1)
        XCTAssertEqual(session.phase, .run)
    }

    // MARK: Bounce

    func testFallingOntoAnObstacleBouncesWithoutFailing() throws {
        var bounces = 0
        for realm in try catalog().realms.prefix(6) where !realm.isWater {
            let c = course(realm)
            for o in c.obstacles.prefix(4) {
                for d in stride(from: 150.0, to: 650, by: 3) {
                    let r = runner(realm, startX: o.x - d)
                    r.press()
                    var jumped = false
                    for _ in 0..<240 where !r.failed {
                        let vyBefore = r.vy
                        let ev = step(r)
                        if ev.contains(.jumped) { jumped = true; r.release() }
                        guard jumped, ev.contains(.bounced) else { continue }
                        bounces += 1
                        XCTAssertFalse(r.failed, "a bounce is not a failure")
                        XCTAssertFalse(ev.contains(.hitObstacle))
                        let expected = -(vyBefore - r.config.gravity * Self.dt) * r.config.bounceRestitution
                            + r.config.bounceKick
                        XCTAssertEqual(r.vy, expected, accuracy: 1e-6)
                        XCTAssertGreaterThan(r.vy, 0, "bounce reverses vertical velocity")
                        XCTAssertFalse(r.grounded)
                        break
                    }
                    if bounces >= 3 { return }
                }
            }
        }
        XCTAssertGreaterThan(bounces, 0, "no jump came down on top of an obstacle")
    }

    // MARK: Water

    func testSwimStrokeOnlyOnRisingEdgeAndAfterCooldown() throws {
        let r = runner(try waterRealm())
        XCTAssertTrue(r.swimming)
        XCTAssertEqual(r.vy, 0)
        r.press()
        XCTAssertEqual(r.vy, r.config.swimKick, accuracy: 1e-9, "a press kicks upward")
        XCTAssertEqual(step(r).filter { $0 == .stroke }.count, 1)

        // Pressing again while still held is not a new stroke.
        var vy = r.vy
        r.press()
        XCTAssertEqual(r.vy, vy)
        XCTAssertFalse(step(r).contains(.stroke))

        // A fresh press inside the cooldown does not kick.
        r.release()
        vy = r.vy
        r.press()
        XCTAssertEqual(r.vy, vy, "no kick during the stroke cooldown")
        XCTAssertFalse(step(r).contains(.stroke))

        // After the cooldown, a fresh press kicks again.
        r.release()
        step(r, Int(r.config.strokeCooldown / Self.dt) + 2)
        vy = r.vy
        r.press()
        XCTAssertEqual(r.vy, max(vy, 0) + r.config.swimKick, accuracy: 1e-9)
        XCTAssertTrue(step(r).contains(.stroke))
    }

    func testSwimmerNeverLeavesTheWaterColumnUnderRandomInput() throws {
        let r = runner(try waterRealm())
        r.hazardsEnabled = false
        var rng = SeededRandom(seed: 42)
        for frame in 0..<(120 * 25) {
            if frame % 7 == 0 { if rng.unit() < 0.5 { r.press() } else { r.release() } }
            step(r)
            XCTAssertGreaterThanOrEqual(r.y, r.course.surface(at: r.x) - 1e-9)
            XCTAssertLessThanOrEqual(r.y, r.course.waterSurface - RunnerConfig.swimBodyHeight + 1e-9)
            XCTAssertFalse(r.failed)
        }
    }

    func testTouchingAHangerFails() throws {
        let realm = try waterRealm()
        let h = try XCTUnwrap(course(realm).hangers.first)
        let r = runner(realm, startX: h.x - 700)
        r.hazardsEnabled = false
        r.press()  // hold: rise to the surface
        var ev: [RunnerEvent] = []
        while r.x < h.x - 120 { ev += step(r) }
        XCTAssertEqual(r.y, r.course.waterSurface - RunnerConfig.swimBodyHeight, accuracy: 1)
        r.hazardsEnabled = true
        while r.x < h.x + h.width / 2 + 40, !r.failed { ev += step(r) }
        XCTAssertTrue(r.failed, "swimming along the surface must hit the hanger")
        XCTAssertTrue(ev.contains(.hitObstacle))
        XCTAssertEqual(r.x, h.x, accuracy: h.width / 2 + 17)
    }

    // MARK: Session: checkpoints and respawn

    private func tapBot(_ session: RunSession) {
        let x = session.runner.x
        let danger = session.course.obstacles.contains { $0.x - x > 0 && $0.x - x < 100 }
            || session.course.gaps.contains { $0.start - x > 0 && $0.start - x < 75 }
        session.release()
        if danger && session.runner.grounded { session.press(); session.release() }
    }

    func testSpringboardIsUsableAgainAfterRespawn() throws {
        let cat = try catalog()
        guard let realm = cat.realms.first(where: { r in
            let c = course(r)
            guard let s = c.springboards.first else { return false }
            return c.checkpoints.contains { $0.x < s.x }
        }) else { throw XCTSkip("no springboard after a checkpoint") }
        let session = RunSession(realm: realm, totalRealms: 30, tuning: .forBand(.explorer),
                                 mode: .chase, companion: cat.companion)
        var events = SessionEvents()
        var firstSpring: Int?
        var tick = 0
        // A: run to the first springboard.
        while firstSpring == nil, tick < 120 * 120 {
            events.clear(); session.advance(Self.dt, into: &events); tick += 1
            for case .springboard(let i) in events.pickups { firstSpring = i }
            if firstSpring == nil { tapBot(session) }
        }
        let i = try XCTUnwrap(firstSpring)
        let checkpointX = session.respawnX
        XCTAssertLessThan(checkpointX, session.course.springboards[i].x)
        // B: tuck all the way through the launch: over-rotate and crash.
        session.press()
        var failed = false
        for _ in 0..<(120 * 4) where !failed {
            events.clear(); session.advance(Self.dt, into: &events)
            failed = events.failed
        }
        XCTAssertTrue(failed, "holding through a springboard launch should crash")
        session.release()
        // C: back at the checkpoint, the springboard launches again.
        var respawned = false, launchedAgain = false
        for _ in 0..<(120 * 120) where !launchedAgain {
            events.clear(); session.advance(Self.dt, into: &events)
            if events.respawned, !respawned {
                respawned = true
                XCTAssertEqual(session.runner.x, checkpointX, accuracy: 0.001)
            }
            if events.pickups.contains(.springboard(i)) { launchedAgain = true }
            tapBot(session)
        }
        XCTAssertTrue(respawned)
        XCTAssertTrue(launchedAgain, "springboards ahead of the checkpoint reset on respawn")
    }

    func testGuardianFailureRestartsTheEncounter() throws {
        let cat = try catalog()
        let session = RunSession(realm: cat.realms[0], totalRealms: 30, tuning: .forBand(.sprout),
                                 mode: .chase, companion: cat.companion)
        var events = SessionEvents()
        var failures = 0
        for _ in 0..<(120 * 300) where session.phase == .run {
            events.clear(); session.advance(Self.dt, into: &events)
            if events.failed { failures += 1 }
            tapBot(session)
        }
        XCTAssertEqual(session.phase, .guardian)
        let first = try XCTUnwrap(session.guardian)
        let startX = first.startX
        let retriesBefore = session.retries
        XCTAssertEqual(retriesBefore, failures)

        // Keep doing tucked long jumps until one crashes.
        var failedTick: Int?
        var tick = 0
        while failedTick == nil, tick < 120 * 30 {
            if tick % 180 == 0 { session.release(); session.press() }
            events.clear(); session.advance(Self.dt, into: &events); tick += 1
            if events.failed { failedTick = tick }
        }
        XCTAssertNotNil(failedTick, "no crash in the guardian phase")
        session.release()
        var respawned = false
        for _ in 0..<240 where !respawned {
            events.clear(); session.advance(Self.dt, into: &events)
            respawned = events.respawned
        }
        XCTAssertTrue(respawned)
        XCTAssertEqual(session.phase, .guardian, "a failure never ends the run")
        let restarted = try XCTUnwrap(session.guardian)
        XCTAssertFalse(restarted === first, "the encounter starts over")
        XCTAssertEqual(restarted.startX, startX)
        XCTAssertEqual(session.runner.x, startX, accuracy: 0.001)
        XCTAssertEqual(restarted.chaseGap(runnerX: session.runner.x), 650, accuracy: 0.001)
        XCTAssertEqual(session.retries, retriesBefore + 1)
        XCTAssertFalse(session.runner.hazardsEnabled, "guardian hills stay hazard-free after a restart")
    }

    func testAdvanceClampsLongFramesAndUsesFixedSteps() throws {
        let cat = try catalog()
        let session = RunSession(realm: cat.realms[0], totalRealms: 30, tuning: .forBand(.explorer),
                                 mode: .chase, companion: cat.companion)
        var events = SessionEvents()
        session.advance(5.0, into: &events)  // a hitch: clamped to 0.1 s
        XCTAssertEqual(session.time, 0.1, accuracy: RunSession.fixedStep + 1e-9)
        session.advance(RunSession.fixedStep / 3, into: &events)
        XCTAssertEqual(session.time, 0.1, accuracy: RunSession.fixedStep + 1e-9)
    }

    // MARK: Course invariants

    func testCourseInvariantsAcrossVariations() throws {
        for band in AgeBand.allCases {
            for realm in try catalog().realms {
                for variation: UInt64 in [3, 99, 123_456_789, .max] {
                    let a = course(realm, band: band, variation: variation)
                    let b = course(realm, band: band, variation: variation)
                    let tag = "\(realm.id)/\(band)/v\(variation)"
                    XCTAssertEqual(a.gaps, b.gaps, tag)
                    XCTAssertEqual(a.obstacles, b.obstacles, tag)
                    XCTAssertEqual(a.hangers, b.hangers, tag)
                    XCTAssertEqual(a.relics, b.relics, tag)
                    XCTAssertEqual(a.surface(at: 4321), b.surface(at: 4321), tag)

                    func sorted(_ xs: [Double]) -> Bool { zip(xs, xs.dropFirst()).allSatisfy { $0 <= $1 } }
                    XCTAssertTrue(sorted(a.obstacles.map(\.x)), tag)
                    XCTAssertTrue(sorted(a.gaps.map(\.start)), tag)
                    XCTAssertTrue(sorted(a.hangers.map(\.x)), tag)
                    XCTAssertTrue(sorted(a.springboards.map(\.x)), tag)
                    XCTAssertTrue(sorted(a.gates.map(\.x)), tag)
                    XCTAssertTrue(sorted(a.motes.map(\.x)), tag)
                    for g in a.gaps {
                        XCTAssertLessThan(g.start, g.end, tag)
                        XCTAssertLessThan(g.end, a.runLength, tag)
                        for o in a.obstacles {
                            XCTAssertFalse(o.x + o.width / 2 > g.start && o.x - o.width / 2 < g.end,
                                           "\(tag): obstacle overlaps gap at \(Int(o.x))")
                        }
                    }
                    XCTAssertTrue(a.obstacles.allSatisfy { $0.x > Course.safeStart - 60 && $0.x < a.runLength }, tag)
                    let cps = a.checkpoints.map(\.x)
                    XCTAssertTrue(zip(cps, cps.dropFirst()).allSatisfy { $0 < $1 }, "\(tag): checkpoints not increasing")
                    XCTAssertTrue(cps.allSatisfy { $0 > 0 && $0 < a.runLength }, tag)
                    XCTAssertTrue(a.relics.allSatisfy { $0.x > 0 && $0.x < a.runLength }, tag)
                    if realm.isWater {
                        XCTAssertTrue(a.gaps.isEmpty, tag)
                        XCTAssertTrue(a.springboards.isEmpty, tag)
                        XCTAssertGreaterThan(a.waterSurface, a.maxSurface + 150, tag)
                    }
                }
            }
        }
    }

    // MARK: Progress

    func testProgressRecordAndUnlockAll() throws {
        let realms = try catalog().realms
        var progress = PlayerProgress()
        let first = realms[0], second = realms[1], third = realms[2]
        progress.record(RunResult(realmID: first.id, won: false, relics: 1, flips: 4, bestCombo: 2,
                                  loreSeen: [], time: 30))
        XCTAssertFalse(progress.isUnlocked(second, in: realms, unlockAll: false), "a lost run unlocks nothing")
        progress.record(RunResult(realmID: first.id, won: true, relics: 0, flips: 1, bestCombo: 1,
                                  loreSeen: [], time: 40))
        XCTAssertTrue(progress.isUnlocked(second, in: realms, unlockAll: false))
        XCTAssertFalse(progress.isUnlocked(third, in: realms, unlockAll: false))
        XCTAssertEqual(progress.attempts[first.id], 2)
        XCTAssertEqual(progress.relicsFound[first.id], 1, "best relic count is kept")
        XCTAssertEqual(progress.bestFlips[first.id], 4, "best flip count is kept")
        XCTAssertTrue(realms.allSatisfy { progress.isUnlocked($0, in: realms, unlockAll: true) })
        XCTAssertTrue(PlayerProgress().isUnlocked(realms.last!, in: realms, unlockAll: true))
    }

    // MARK: Review regressions

    /// Running into a chasm without jumping is a fall: the runner must not be snapped up onto the far rim.
    func testRunningIntoAChasmIsAFall() throws {
        let (realm, gap) = try courseWithGap()
        let r = runner(realm, startX: gap.start - 60)
        var events: [RunnerEvent] = []
        for _ in 0..<600 where !r.failed { events += step(r) }
        XCTAssertTrue(r.failed, "a runner that never jumps must fall into the chasm")
        XCTAssertTrue(events.contains(.fellInGap))
        XCTAssertFalse(events.contains { if case .landed = $0 { return true } else { return false } },
                       "no landing inside or on the far wall of the chasm")
    }

    /// Holding a crouch right up to a ledge still pushes off instead of dropping the jump.
    func testCrouchingOffALedgeStillJumps() throws {
        let (realm, gap) = try courseWithGap()
        let r = runner(realm, startX: gap.start - 15)
        r.press()
        var events: [RunnerEvent] = []
        for _ in 0..<20 { events += step(r) }
        XCTAssertTrue(events.contains(.jumped), "leaving the ground mid-crouch fires the charged jump")
    }

    /// In the app a failure waits for the player's choice instead of respawning on its own.
    func testFailureWaitsForContinueWhenAutoRespawnIsOff() throws {
        let catalog = try catalog()
        let session = RunSession(realm: catalog.realms[0], totalRealms: 30, tuning: .forBand(.explorer),
                                 mode: .chase, companion: catalog.companion, variation: 3)
        session.autoRespawn = false
        var events = SessionEvents()
        var sawWait = false
        // Never jump: the runner fails at the first hazard, then must wait.
        for _ in 0..<(60 * 60) {
            events.clear()
            session.advance(1.0 / 60, into: &events)
            if events.awaitingContinue { sawWait = true; break }
            XCTAssertFalse(events.respawned, "no automatic respawn")
        }
        XCTAssertTrue(sawWait)
        XCTAssertTrue(session.awaitingContinue)
        // Time passes, nothing happens.
        for _ in 0..<180 {
            events.clear()
            session.advance(1.0 / 60, into: &events)
            XCTAssertFalse(events.respawned)
        }
        session.continueFromCheckpoint()
        events.clear()
        session.advance(1.0 / 60, into: &events)
        XCTAssertTrue(events.respawned)
        XCTAssertFalse(session.awaitingContinue)
        XCTAssertFalse(session.runner.failed)
    }
}
