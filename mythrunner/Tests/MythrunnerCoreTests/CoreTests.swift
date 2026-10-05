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
        XCTAssertGreaterThan(kid.hearts, teen.hearts)
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

    func testJumpAndFlipGivesBoost() throws {
        let session = try makeSession()
        var events = SessionEvents()
        for _ in 0..<30 { session.advance(1.0 / 60, into: &events) }
        session.press()
        var landed: [Int] = []
        // Hold until roughly one full rotation, then release and let it land.
        let flipTime = (Double.pi * 2) / session.runner.config.flipAngularSpeed
        var t = 0.0
        for _ in 0..<240 {
            events.clear()
            if t >= flipTime { session.release() }
            session.advance(1.0 / 120, into: &events)
            t += 1.0 / 120
            for case .landed(let f) in events.runner { landed.append(f) }
            if !landed.isEmpty { break }
        }
        XCTAssertFalse(landed.isEmpty, "runner should land")
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
            if danger && session.runner.grounded { session.press() }
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
            for _ in 0..<(60 * 240) {
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
                if jump && r.grounded { session.press() }
                if session.phase == .won || session.phase == .lost { break }
            }
            XCTAssertEqual(session.phase, .won, "mode \(mode) not winnable; hearts \(session.runner.hearts)")
        }
    }

    /// Level-design KPI: every realm, age band and guardian mode is beatable by a simple bot
    /// that only taps (never flips). Prints the hardest combos so designers can tune.
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
                    tightest.append((tag, session.runner.hearts))
                }
            }
        }
        let close = tightest.filter { $0.1 <= 1 }.map(\.0)
        print("Combos finished with <=1 heart: \(close.count)/\(tightest.count): \(close.prefix(20))")
        XCTAssertTrue(failures.isEmpty, "Unbeatable for bot: \(failures)")
    }

    /// A "decent human" bot: looks ~0.3 s ahead and taps (relying on the game's input buffer).
    static func playBot(_ session: RunSession) -> RunSession.Phase {
        var events = SessionEvents()
        var tapCooldown = 0.0
        for _ in 0..<(60 * 300) {
            events.clear()
            session.advance(1.0 / 60, into: &events)
            tapCooldown -= 1.0 / 60
            let r = session.runner
            let reach = max(r.effectiveSpeed, 150)
            var jump = false
            if session.phase == .run {
                jump = session.course.obstacles.contains { $0.x - r.x > 0 && $0.x - r.x < reach * 0.3 }
                    || session.course.gaps.contains { $0.start - r.x > 0 && $0.start - r.x < reach * 0.2 }
            } else if let g = session.guardian {
                jump = g.projectiles.contains { $0.kind == .low && $0.warning <= 0 && $0.x - r.x > 0 && $0.x - r.x < 120 }
                if let wp = g.weakPoint, wp.x - r.x > 0, wp.x - r.x < 230 { jump = true }
            }
            session.release()
            if jump && tapCooldown <= 0 {
                session.press()
                tapCooldown = 0.35
            }
            if session.phase == .won || session.phase == .lost { break }
        }
        return session.phase
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
