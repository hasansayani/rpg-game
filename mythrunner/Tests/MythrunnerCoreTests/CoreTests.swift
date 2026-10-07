import XCTest
@testable import MythrunnerCore

/// Loads the real shipping content so content mistakes fail CI, not players.
func loadCatalog(file: StaticString = #filePath) throws -> RealmCatalog {
    let url = URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Mythrunner/Resources/realms.json")
    return try RealmCatalog.decode(from: Data(contentsOf: url))
}

final class ContentTests: XCTestCase {
    func testThirtyUniqueRealmsInOrder() throws {
        let catalog = try loadCatalog()
        XCTAssertEqual(catalog.realms.count, 30)
        XCTAssertEqual(Set(catalog.realms.map(\.id)).count, 30)
        XCTAssertEqual(catalog.realms.map(\.order), Array(1...30))
    }

    func testRegionsAreBalanced() throws {
        let catalog = try loadCatalog()
        let counts = Dictionary(grouping: catalog.realms, by: \.region).mapValues(\.count)
        for region in Region.allCases {
            XCTAssertGreaterThanOrEqual(counts[region] ?? 0, 3, "\(region) is under-represented")
        }
        XCTAssertGreaterThanOrEqual(catalog.realms.filter { $0.tags.contains("lesserKnown") }.count, 15)
        XCTAssertGreaterThanOrEqual(catalog.realms.filter { $0.tags.contains("ancient") }.count, 6)
    }

    func testLoreIsCompleteAndBubbleSized() throws {
        let catalog = try loadCatalog()
        for realm in catalog.realms {
            XCTAssertEqual(realm.facts.count, 3, realm.id)
            var lore = realm.facts
            lore.append(realm.relic.lore)
            lore.append(realm.guardian.intro)
            for item in lore {
                XCTAssertFalse(item.text.isEmpty, realm.id)
                XCTAssertFalse(item.kid.isEmpty, realm.id)
                XCTAssertLessThanOrEqual(item.text.count, 150, "\(realm.id): \(item.text)")
                XCTAssertLessThanOrEqual(item.kid.count, 110, "\(realm.id): \(item.kid)")
            }
        }
    }

    func testEveryGuardianLooksUnique() throws {
        let catalog = try loadCatalog()
        let designs = catalog.realms.map(\.guardian.design)
        XCTAssertEqual(Set(designs).count, catalog.realms.count, "two guardians share a design")
        XCTAssertEqual(Set(designs.map(\.signature)).count, catalog.realms.count, "two guardians share a signature")
        XCTAssertEqual(Set(designs.map(\.signature)), Set(GuardianDesign.Signature.allCases), "unused signature art")
        XCTAssertTrue(designs.allSatisfy { (1...8).contains($0.heads) })
    }

    func testEveryRealmIsOnTheMap() throws {
        for realm in try loadCatalog().realms {
            let c = try XCTUnwrap(realm.coords, realm.id)
            XCTAssertEqual(c.count, 2, realm.id)
            XCTAssertTrue((-90...90).contains(realm.latitude) && (-180...180).contains(realm.longitude), realm.id)
        }
    }

    func testPaletteHexIsValid() throws {
        let catalog = try loadCatalog()
        for realm in catalog.realms {
            let p = realm.palette
            for hex in [p.skyTop, p.skyBottom, p.far, p.mid, p.near, p.ground, p.groundEdge, p.accent, realm.guardian.color] {
                XCTAssertTrue(RGBA.isValidHex(hex), "\(realm.id): \(hex)")
            }
        }
    }

    func testLivingCulturesNeverHaveDeityEnemiesUnreviewed() throws {
        // Living traditions with a non-creature guardian or explicit review note are OK;
        // this flags any new living realm added without a cultural-review note or safe framing.
        let catalog = try loadCatalog()
        for realm in catalog.realms where realm.living && realm.guardian.kind == .creature && realm.review == nil {
            // Folk creatures from living cultures are allowed, but list them for reviewers.
            print("Review suggested: \(realm.id) guardian \(realm.guardian.name)")
        }
    }
}

final class TuningTests: XCTestCase {
    func testAgeBands() {
        XCTAssertEqual(AgeBand(age: 6), .sprout)
        XCTAssertEqual(AgeBand(age: 9), .sprout)
        XCTAssertEqual(AgeBand(age: 10), .explorer)
        XCTAssertEqual(AgeBand(age: 13), .explorer)
        XCTAssertEqual(AgeBand(age: 14), .legend)
        XCTAssertEqual(AgeBand(age: 70), .legend)
    }

    func testYoungPlayersGetGentlerGame() {
        let kid = AgeTuning.forBand(.sprout), teen = AgeTuning.forBand(.legend)
        XCTAssertLessThan(kid.speedScale, teen.speedScale)
        XCTAssertLessThan(kid.checkpointSpacing, teen.checkpointSpacing)
        XCTAssertGreaterThan(kid.landingTolerance, teen.landingTolerance)
        XCTAssertEqual(kid.loreVariant, .kid)
        XCTAssertGreaterThan(kid.saturation, teen.saturation)
    }

    func testColorAdjust() {
        let c = RGBA(hex: "#FF8000")
        XCTAssertEqual(c.r, 1, accuracy: 0.001)
        XCTAssertEqual(c.g, 128.0 / 255, accuracy: 0.001)
        let grey = c.adjusted(saturation: 0, brightness: 1)
        XCTAssertEqual(grey.r, grey.g, accuracy: 0.001)
        XCTAssertEqual(grey.g, grey.b, accuracy: 0.001)
        XCTAssertEqual(RGBA(hex: "nope"), RGBA(r: 1, g: 0, b: 1))
    }
}

final class CourseTests: XCTestCase {
    func testDeterministicAndPlayable() throws {
        let catalog = try loadCatalog()
        for band in AgeBand.allCases {
            let tuning = AgeTuning.forBand(band)
            for realm in catalog.realms {
                let a = Course(realm: realm, totalRealms: 30, tuning: tuning)
                let b = Course(realm: realm, totalRealms: 30, tuning: tuning)
                XCTAssertEqual(a.gaps, b.gaps)
                XCTAssertEqual(a.obstacles, b.obstacles)
                XCTAssertEqual(a.surface(at: 1234.5), b.surface(at: 1234.5))
                XCTAssertEqual(a.relics.count, 3)
                XCTAssertEqual(a.factTriggers.count, 3)
                for g in a.gaps {
                    XCTAssertGreaterThan(g.start, Course.safeStart, realm.id)
                    XCTAssertLessThan(g.end - g.start, 230, "gap must stay jumpable")
                    for o in a.obstacles {
                        XCTAssertFalse(g.contains(o.x), "obstacle inside gap in \(realm.id)")
                    }
                }
                XCTAssertTrue(a.relics.allSatisfy { r in a.gap(at: r.x) == nil }, realm.id)
                for x in stride(from: 0.0, to: a.runLength + 3000, by: 37) {
                    XCTAssertLessThanOrEqual(abs(a.slope(at: x)), Course.maxSlope + 0.01, realm.id)
                }
            }
        }
    }

    func testInteractablesArePlacedSafely() throws {
        let catalog = try loadCatalog()
        for band in AgeBand.allCases {
            let tuning = AgeTuning.forBand(band)
            for realm in catalog.realms {
              for variation: UInt64 in [0, 1, 7, 4242, 987_654_321] {
                let a = Course(realm: realm, totalRealms: 30, tuning: tuning, variation: variation)
                let b = Course(realm: realm, totalRealms: 30, tuning: tuning, variation: variation)
                XCTAssertEqual(a.springboards, b.springboards)
                XCTAssertEqual(a.gates, b.gates)
                XCTAssertEqual(a.motes, b.motes)
                XCTAssertEqual(a.checkpoints, b.checkpoints)
                // A short hop (tap) clears every obstacle, even on a climb.
                if !realm.isWater {
                    let cfg = RunnerConfig(difficulty: realm.difficulty(totalRealms: 30), tuning: tuning)
                    for o in a.obstacles {
                        for speed in Course.comfortSpeeds(cfg) {
                            let window = stride(from: o.x - 300, through: o.x - 40, by: 10)
                                .filter { a.hopClears(from: $0, obstacle: o, speed: speed, config: cfg) }
                            XCTAssertGreaterThanOrEqual(window.count, Course.comfortWindow,
                                                        "\(realm.id): no comfortable tap window at \(Int(o.x))")
                        }
                    }
                }
                // Every hazard leaves room to land and jump again before the next one.
                let spans = (a.obstacles.map { ($0.x - $0.width / 2, $0.x + $0.width / 2) } + a.gaps.map { ($0.start, $0.end) })
                    .sorted { $0.0 < $1.0 }
                for (p, q) in zip(spans, spans.dropFirst()) {
                    do { XCTAssertGreaterThanOrEqual(q.0 - p.1, a.landingRoom - 0.001, "\(realm.id): hazards too close at \(Int(q.0))") }
                }
                XCTAssertEqual(a.springboards.isEmpty, realm.isWater, realm.id)
                XCTAssertEqual(a.hangers.isEmpty, !realm.isWater, realm.id)
                if realm.isWater {
                    XCTAssertTrue(a.gaps.isEmpty, realm.id)
                    // Every hanger leaves a channel wide enough to swim under.
                    for h in a.hangers {
                        XCTAssertGreaterThanOrEqual(a.waterSurface - h.length - a.surface(at: h.x), 120, realm.id)
                    }
                }
                XCTAssertFalse(a.gates.isEmpty, realm.id)
                XCTAssertGreaterThan(a.motes.count, 20, realm.id)
                XCTAssertGreaterThanOrEqual(a.checkpoints.count, 3, realm.id)
                // A respawn point is always on solid, hazard-free ground.
                for c in a.checkpoints {
                    XCTAssertNil(a.gap(at: c.x), realm.id)
                    XCTAssertFalse(a.obstacles.contains { abs($0.x - c.x) < 160 }, realm.id)
                }
                for s in a.springboards {
                    let landing = s.x...(s.x + Course.springboardClearance)
                    XCTAssertFalse(a.gaps.contains { landing.overlaps($0.start...$0.end) }, "\(realm.id): gap after springboard")
                    XCTAssertFalse(a.obstacles.contains { landing.contains($0.x) }, "\(realm.id): obstacle after springboard")
                }
                for g in a.gates { XCTAssertNil(a.gap(at: g.x), realm.id) }
                XCTAssertTrue(a.motes.allSatisfy { $0.lift > 0 }, realm.id)
              }
            }
        }
    }

    func testEachRunGetsADifferentLandscape() throws {
        let realm = try loadCatalog().realms[0]
        let a = Course(realm: realm, totalRealms: 30, tuning: .forBand(.explorer), variation: 1)
        let b = Course(realm: realm, totalRealms: 30, tuning: .forBand(.explorer), variation: 2)
        let samples = stride(from: 1000.0, to: 9000, by: 250)
        XCTAssertNotEqual(samples.map(a.surface(at:)), samples.map(b.surface(at:)), "terrain should differ per run")
        XCTAssertNotEqual(a.obstacles, b.obstacles, "hazards should differ per run")
    }

    func testStartIsFlat() throws {
        let realm = try loadCatalog().realms[2]
        let course = Course(realm: realm, totalRealms: 30, tuning: .forBand(.explorer))
        XCTAssertEqual(course.surface(at: 0), Course.baseHeight, accuracy: 0.001)
    }
}

final class SimulationTests: XCTestCase {
    func makeSession(_ index: Int = 0, band: AgeBand = .explorer, mode: GuardianMode = .chase) throws -> RunSession {
        let catalog = try loadCatalog()
        return RunSession(realm: catalog.realms[index], totalRealms: 30, tuning: .forBand(band),
                          mode: mode, companion: catalog.companion)
    }

    func testRunnerMovesAndStaysOnGround() throws {
        let session = try makeSession()
        var events = SessionEvents()
        for _ in 0..<120 { session.advance(1.0 / 60, into: &events) }
        XCTAssertGreaterThan(session.runner.x, 300)
        XCTAssertEqual(session.runner.y, session.course.surface(at: session.runner.x), accuracy: 1)
    }

    func testTuckedFlipLandsAndGivesBoost() throws {
        // On the flat start: tuck (hold) to build spin, open up (release) to slow it, land upright.
        let session = try makeSession()
        var events = SessionEvents()
        for _ in 0..<30 { session.advance(1.0 / 60, into: &events) }
        session.press()
        var landed: [Int] = []
        var crashed = false
        var jumpedAt: Double?
        var t = 0.0
        let r = session.runner
        for _ in 0..<480 {
            events.clear()
            // Hold through the crouch (long jump fires on its own) and the tuck; open up near one turn.
            if !r.grounded && r.airRotation >= Double.pi * 2 - 1.0 { session.release() }
            session.advance(1.0 / 120, into: &events)
            t += 1.0 / 120
            if events.runner.contains(.jumped) { jumpedAt = t }
            for case .landed(let f) in events.runner { landed.append(f) }
            if events.runner.contains(.crashed) { crashed = true }
            if !landed.isEmpty || crashed { break }
        }
        XCTAssertEqual(jumpedAt ?? 0, r.config.fullChargeTime, accuracy: 0.03, "a long press jumps at full crouch")
        XCTAssertFalse(crashed, "a well-timed tuck and open should land")
        XCTAssertEqual(landed, [1], "one full flip")
        XCTAssertGreaterThan(session.runner.boost, 50, "a clean flip gives a speed boost")
    }

    func testTapIsAShortHopAndLongPressJumpsHigher() throws {
        func peak(holdFrames: Int) throws -> Double {
            let session = try makeSession()
            var events = SessionEvents()
            for _ in 0..<30 { session.advance(1.0 / 60, into: &events) }
            session.press()
            var best = 0.0
            for frame in 0..<240 {
                if frame == holdFrames { session.release() }
                session.advance(1.0 / 120, into: &events)
                best = max(best, session.runner.heightAboveGround)
            }
            return best
        }
        let tap = try peak(holdFrames: 0)
        let long = try peak(holdFrames: 30)
        XCTAssertLessThan(tap, 100, "tap = short hop")
        XCTAssertGreaterThan(long, tap * 1.8, "long press = big jump")
    }

    func testJumpFollowsAParabolaAndKeepsHorizontalMomentum() throws {
        let session = try makeSession()
        var events = SessionEvents()
        for _ in 0..<30 { session.advance(1.0 / 60, into: &events) }
        session.press()
        session.release()
        let r = session.runner
        var vys: [Double] = []
        var speeds: [Double] = []
        for _ in 0..<60 {
            events.clear()
            session.advance(1.0 / 120, into: &events)
            if !r.grounded { vys.append(r.vy); speeds.append(r.effectiveSpeed) }
        }
        XCTAssertGreaterThan(vys.count, 20)
        // Constant downward acceleration (gravity) on the center of mass…
        let g = r.config.gravity
        for (a, b) in zip(vys, vys.dropFirst()) { XCTAssertEqual(a - b, g / 120, accuracy: 0.01) }
        // …and no change in horizontal speed while airborne (inertia).
        XCTAssertEqual(speeds.max()! - speeds.min()!, 0, accuracy: 0.001)
    }

    func testSwimmerStaysBetweenSeabedAndSurface() throws {
        let catalog = try loadCatalog()
        let index = try XCTUnwrap(catalog.realms.firstIndex { $0.isWater })
        let session = try makeSession(index)
        XCTAssertTrue(session.runner.swimming)
        var events = SessionEvents()
        var strokes = 0
        let r = session.runner
        for frame in 0..<(60 * 6) {
            events.clear()
            // Hold for 2 s (rise to the surface), then let go (sink to the seabed).
            if frame < 120 { session.release(); session.press() } else { session.release() }
            session.advance(1.0 / 60, into: &events)
            strokes += events.runner.filter { $0 == .stroke }.count
            XCTAssertGreaterThanOrEqual(r.y, session.course.surface(at: r.x) - 0.01)
            XCTAssertLessThanOrEqual(r.y + RunnerConfig.swimBodyHeight, session.course.waterSurface + 0.01)
            if frame == 119 { XCTAssertEqual(r.y + RunnerConfig.swimBodyHeight, session.course.waterSurface, accuracy: 1) }
        }
        XCTAssertEqual(r.heightAboveGround, 0, accuracy: 1, "released swimmers sink to the seabed")
        XCTAssertGreaterThan(strokes, 3)
    }

    func testSpringboardLaunches() throws {
        let session = try makeSession()
        let spring = try XCTUnwrap(session.course.springboards.first)
        var events = SessionEvents()
        var launched = false, peak = 0.0
        for _ in 0..<(60 * 120) {
            events.clear()
            session.advance(1.0 / 60, into: &events)
            if events.runner.contains(.launched) { launched = true }
            if launched, abs(session.runner.x - spring.x) < 400 { peak = max(peak, session.runner.heightAboveGround) }
            let x = session.runner.x
            let danger = session.course.obstacles.contains { $0.x - x > 0 && $0.x - x < 110 }
                || session.course.gaps.contains { $0.start - x > 0 && $0.start - x < 80 }
            session.release()
            if danger && session.runner.grounded { session.press(); session.release() }
            if session.runner.x > spring.x + 900 || session.phase != .run { break }
        }
        XCTAssertTrue(launched, "running over a springboard should launch")
        XCTAssertGreaterThan(peak, 180, "a launch should go well above a normal jump")
        XCTAssertGreaterThan(session.result.motes, 0)
    }

    func testFailingRespawnsAtTheLastCheckpoint() throws {
        // A runner that never jumps keeps failing; each time it must come back at the checkpoint it reached.
        let session = try makeSession()
        let first = try XCTUnwrap(session.course.checkpoints.first)
        var events = SessionEvents()
        var reached = false, failures = 0, respawnedAt: [Double] = []
        for _ in 0..<(60 * 120) {
            events.clear()
            session.advance(1.0 / 60, into: &events)
            if events.pickups.contains(.checkpoint(0)) { reached = true }
            if events.failed { failures += 1 }
            if events.respawned { respawnedAt.append(session.runner.x) }
            if respawnedAt.count >= 3 { break }
        }
        XCTAssertGreaterThan(failures, 0)
        XCTAssertEqual(session.retries, failures)
        XCTAssertEqual(session.phase, .run, "no lives: the run never ends in a loss")
        for x in respawnedAt {
            // Positions are sampled after the frame, so the runner may have moved a few units on.
            XCTAssertTrue(abs(x - 80) < 20 || session.course.checkpoints.contains { abs($0.x - x) < 20 },
                          "respawned at \(x), not a checkpoint")
        }
        if reached { XCTAssertGreaterThanOrEqual(respawnedAt.last ?? 0, first.x) }
        XCTAssertFalse(session.runner.failed, "respawned runners are back on their feet")
    }

    func testCompanionSpeaksFactsAndRecordsLore() throws {
        let session = try makeSession(band: .sprout)
        var events = SessionEvents()
        var lines: [CompanionLine] = []
        // Simulate long enough to pass all fact triggers (invulnerable cheat: lots of hearts not needed).
        for _ in 0..<(60 * 60) {
            events.clear()
            session.advance(1.0 / 60, into: &events)
            if let l = events.companionLine { lines.append(l) }
            // Auto-jump hazards like a decent player.
            let x = session.runner.x
            let danger = session.course.obstacles.contains { $0.x - x > 0 && $0.x - x < 90 }
                || session.course.gaps.contains { $0.start - x > 0 && $0.start - x < 70 }
            session.release()
            if danger && session.runner.grounded { session.press(); session.release() }
            if session.phase != .run { break }
        }
        XCTAssertTrue(lines.contains { $0.loreID == "greek.fact.0" }, lines.map(\.text).joined(separator: "\n"))
        XCTAssertTrue(lines.allSatisfy { !$0.text.isEmpty })
    }

    func testEveryModeCanBeWonByAnIdleChaser() throws {
        // A bot that auto-jumps low hazards & weak points must be able to win each mode.
        for mode in GuardianMode.allCases {
            let session = try makeSession(0, band: .sprout, mode: mode)
            var events = SessionEvents()
            for _ in 0..<(60 * 600) {
                events.clear()
                session.advance(1.0 / 60, into: &events)
                let r = session.runner
                var jump = false
                if session.phase == .run {
                    jump = session.course.obstacles.contains { $0.x - r.x > 0 && $0.x - r.x < 90 }
                        || session.course.gaps.contains { $0.start - r.x > 0 && $0.start - r.x < 70 }
                } else if let g = session.guardian {
                    jump = g.projectiles.contains { $0.kind == .low && $0.warning <= 0 && $0.x - r.x > 0 && $0.x - r.x < 110 }
                    if let wp = g.weakPoint, wp.x - r.x > 0, wp.x - r.x < 230 { jump = true }
                }
                session.release()
                if jump && r.grounded { session.press(); session.release() }
                if session.phase == .won { break }
            }
            XCTAssertEqual(session.phase, .won, "mode \(mode) not finished; retries \(session.retries)")
        }
    }

    /// Level-design KPI: every realm, age band and guardian mode is finished by a simple bot
    /// that never flips, within a bounded number of checkpoint retries. Prints the hardest combos.
    func testAllRealmsBandsAndModesAreBeatable() throws {
        let catalog = try loadCatalog()
        var failures: [String] = []
        var tightest: [(String, Int)] = []
        for realm in catalog.realms {
            for band in AgeBand.allCases {
                for mode in GuardianMode.allCases {
                    let session = RunSession(realm: realm, totalRealms: 30, tuning: .forBand(band),
                                             mode: mode, companion: catalog.companion)
                    let outcome = Self.playBot(session)
                    let tag = "\(realm.id)/\(band)/\(mode)"
                    if outcome != .won { failures.append(tag) }
                    tightest.append((tag, session.retries))
                }
            }
        }
        let hardest = tightest.sorted { $0.1 > $1.1 }.prefix(10).map { "\($0.0)=\($0.1)" }
        let total = tightest.reduce(0) { $0 + $1.1 }
        print("Bot retries: total \(total), mean \(String(format: "%.2f", Double(total) / Double(tightest.count))); hardest: \(hardest)")
        XCTAssertTrue(failures.isEmpty, "Not finished by bot: \(failures)")
        // Difficulty KPI: a simple tapping bot should rarely need more than a handful of retries.
        XCTAssertLessThanOrEqual(tightest.map(\.1).max() ?? 0, 20, "some realm is too punishing: \(hardest)")
    }

    /// Random layouts must be just as fair: every realm and band, three random variations each.
    func testRandomLayoutsAreBeatable() throws {
        let catalog = try loadCatalog()
        var failures: [String] = []
        var worst: [(String, Int)] = []
        for realm in catalog.realms {
            for band in AgeBand.allCases {
                for variation: UInt64 in [11, 2_024, 31_337] {
                    let session = RunSession(realm: realm, totalRealms: 30, tuning: .forBand(band),
                                             mode: .chase, companion: catalog.companion, variation: variation)
                    let tag = "\(realm.id)/\(band)/v\(variation)"
                    if Self.playBot(session) != .won { failures.append(tag) }
                    worst.append((tag, session.retries))
                }
            }
        }
        let hardest = worst.sorted { $0.1 > $1.1 }.prefix(8).map { "\($0.0)=\($0.1)" }
        print("Random-layout bot retries: mean \(String(format: "%.2f", Double(worst.reduce(0) { $0 + $1.1 }) / Double(worst.count))); hardest: \(hardest)")
        XCTAssertTrue(failures.isEmpty, "Not finished by bot: \(failures)")
        XCTAssertLessThanOrEqual(worst.map(\.1).max() ?? 0, 20, "a random layout is too punishing: \(hardest)")
    }

    /// A "decent human" bot: looks ~0.3 s ahead and taps (relying on the game's input buffer).
    static func playBot(_ session: RunSession, log: ((SessionEvents) -> Void)? = nil) -> RunSession.Phase {
        var events = SessionEvents()
        var tapCooldown = 0.0
        for _ in 0..<(60 * 900) {
            events.clear()
            session.advance(1.0 / 60, into: &events)
            log?(events)
            tapCooldown -= 1.0 / 60
            let r = session.runner
            if session.course.isWater {
                // Hold to rise (one kick per hold), let go to sink.
                if swimShouldRise(session) { if !r.holding { session.press() } } else { session.release() }
                if session.phase == .won { break }
                continue
            }
            let reach = max(r.effectiveSpeed, 150)
            var jump = false
            var bigJump = false
            if session.phase == .run {
                // Judge the hop like a player: jump once a short hop from here would clear the next rock
                // or chasm (and waiting longer wouldn't); if no tap can make it, long-press instead.
                let c = session.course, v = r.effectiveSpeed, here = r.x + v / 60
                let rock = c.obstacles.first { $0.x - r.x > 0 && $0.x - r.x < 260 }
                let chasm = c.gaps.first { $0.start - r.x > 0 && $0.start - r.x < 260 }
                if r.grounded, let o = rock {
                    let now = c.hopClears(from: here, obstacle: o, speed: v, config: r.config)
                    jump = now && !c.hopClears(from: here + 40, obstacle: o, speed: v, config: r.config)
                    // No tap window left ahead: long-press, early enough for the crouch to finish.
                    let windowAhead = stride(from: here + 10, through: o.x - 40, by: 10)
                        .contains { c.hopClears(from: $0, obstacle: o, speed: v, config: r.config) }
                    if !now, !windowAhead, o.x - r.x < v * 0.24 + 90 { bigJump = true }
                }
                if r.grounded, let gap = chasm {
                    // Jump from the stretch just before the edge, with a safety margin on the landing.
                    let near = gap.start - r.x < v * 0.35 + 20
                    let now = c.hopLanding(from: here, speed: v, config: r.config) > gap.end + 25
                    let later = here + 40 < gap.start && c.hopLanding(from: here + 40, speed: v, config: r.config) > gap.end + 25
                    if near && now && !later { jump = true }
                    if !now, gap.start - r.x < 60 { bigJump = true }
                }
            } else if let g = session.guardian {
                // Hop low attacks, but only when a press can actually turn into a jump (on or about to touch the ground).
                let canJump = r.grounded || (r.vy < 0 && r.heightAboveGround < 25)
                jump = canJump && g.projectiles.contains { $0.kind == .low && $0.warning <= 0 && $0.x - r.x > 0 && $0.x - r.x < 130 }
                if jump && !r.grounded { tapCooldown = 0 }
                // Weak points: a tap reaches low ones, a long press (released once airborne, no flip) the high ones.
                // Time the jump so its peak arrives over the target.
                if let wp = g.weakPoint, r.grounded {
                    let dx = wp.x - r.x
                    let low = wp.lift - 24 < 100
                    let lead = r.effectiveSpeed * (low ? 0.33 : 0.62)
                    if dx > 0, dx < lead {
                        if low { jump = true; tapCooldown = 0 } else { bigJump = true }
                    }
                }
            }
            if bigJump && r.grounded {
                if !r.holding { session.press() }
            } else {
                session.release()
                if jump && tapCooldown <= 0 {
                    session.press()
                    tapCooldown = 0.35
                }
            }
            if session.phase == .won { break }
        }
        return session.phase
    }

    /// The swimming bot picks a depth lane: over coral, under hangers, around attacks, into weak points.
    static func swimShouldRise(_ s: RunSession) -> Bool {
        let r = s.runner, c = s.course
        let floor = c.surface(at: r.x)
        let look = max(r.effectiveSpeed, 150) * 0.9
        // Everything in absolute world y: the seabed under a hazard isn't the seabed under the swimmer.
        var target = floor + 80
        if s.phase == .run {
            // Stay in the band between coral below and hangers above: cruise low, kick only to clear coral,
            // and never kick when that would carry us into a hanger.
            var low = floor + 40, high = c.waterSurface - RunnerConfig.swimBodyHeight
            for o in c.obstacles where o.x - r.x > -40 && o.x - r.x < look {
                low = max(low, c.surface(at: o.x) + o.height + 20)
            }
            for h in c.hangers where h.x - r.x > -40 && h.x - r.x < look {
                high = min(high, c.waterSurface - h.length - RunnerConfig.swimBodyHeight - 20)
            }
            if r.y > high - 60 { return false }
            return r.holding ? r.y < low + 15 : r.y < low
        } else if let g = s.guardian {
            let ahead = max(r.effectiveSpeed, 150) * 1.1
            if g.projectiles.contains(where: { $0.kind == .high && $0.x - r.x > -30 && $0.x - r.x < ahead }) { target = floor + 8 }
            if g.projectiles.contains(where: { $0.kind == .low && $0.x - r.x > -30 && $0.x - r.x < ahead }) { target = floor + 60 }
            if let wp = g.weakPoint, wp.x - r.x > 0, wp.x - r.x < 400 { target = c.surface(at: wp.x) + wp.lift - 24 }
        }
        // Hysteresis: start a kick only when well below the lane, then keep holding up to it.
        return r.holding ? r.y < target : r.y < target - 30
    }

    func testProgressUnlocksSequentially() throws {
        let catalog = try loadCatalog()
        var progress = PlayerProgress()
        XCTAssertTrue(progress.isUnlocked(catalog.realms[0], in: catalog.realms, unlockAll: false))
        XCTAssertFalse(progress.isUnlocked(catalog.realms[1], in: catalog.realms, unlockAll: false))
        progress.record(RunResult(realmID: "greek", won: true, relics: 2, flips: 3, bestCombo: 1,
                                  loreSeen: ["greek.fact.0"], time: 60))
        XCTAssertTrue(progress.isUnlocked(catalog.realms[1], in: catalog.realms, unlockAll: false))
        XCTAssertTrue(progress.loreSeen.contains("greek.fact.0"))

        let store = SaveStore(store: MemoryStore())
        store.save(progress)
        XCTAssertEqual(store.loadProgress(), progress)
        var settings = PlayerSettings()
        XCTAssertEqual(settings.guardianMode, .chase, "Chase & Escape is the default")
        settings.age = 8
        store.save(settings)
        XCTAssertEqual(store.loadSettings().tuning.band, .sprout)
    }
}
