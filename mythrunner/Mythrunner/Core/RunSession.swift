import Foundation

/// Everything that happened during one simulation tick, for the renderer to react to.
struct SessionEvents {
    var runner: [RunnerEvent] = []
    var guardian: [GuardianEvent] = []
    var relicsCollected: [Int] = []
    var pickups: [Pickup] = []
    var phaseChanged: RunSession.Phase?
    var companionLine: CompanionLine?
    /// The runner failed this tick; it will respawn after `RunSession.respawnDelay`.
    var failed = false
    /// The runner was just put back at a checkpoint (or the guardian encounter restarted).
    var respawned = false

    mutating func clear() {
        runner.removeAll(keepingCapacity: true)
        guardian.removeAll(keepingCapacity: true)
        relicsCollected.removeAll(keepingCapacity: true)
        pickups.removeAll(keepingCapacity: true)
        phaseChanged = nil
        companionLine = nil
        failed = false
        respawned = false
    }
}

/// Interactive path elements touched this tick (indices into the course arrays).
enum Pickup: Equatable {
    case mote(Int)
    case gate(Int)
    case springboard(Int)
    case checkpoint(Int)
}

struct RunResult: Equatable {
    var realmID: String
    var won: Bool
    var relics: Int
    var flips: Int
    var bestCombo: Int
    var loreSeen: [String]
    var time: Double
    var motes: Int = 0
    var totalMotes: Int = 0
    var gates: Int = 0
    /// How many times the runner was sent back to a checkpoint.
    var retries: Int = 0
}

/// The whole game model for one realm: runner + course + guardian + companion.
/// The SpriteKit scene only renders this and forwards touches (and a Godot port would do the same).
/// There are no lives: a failure sends the runner back to the last checkpoint (or restarts the
/// guardian encounter), so every realm can always be finished.
final class RunSession {
    enum Phase: Equatable { case run, guardian, won }

    static let fixedStep: Double = 1.0 / 120.0
    /// Pause between a failure and the respawn, so the player sees what happened.
    static let respawnDelay: Double = 0.9

    let realm: Realm
    let tuning: AgeTuning
    let mode: GuardianMode
    let course: Course
    let runner: RunnerSim
    let companionScript: CompanionScript
    private(set) var guardian: GuardianSim?
    private(set) var companion: CompanionDirector
    private(set) var phase: Phase = .run
    private(set) var collected: Set<Int> = []
    private(set) var motesCollected = 0
    private(set) var loreSeen: [String] = []
    private(set) var time: Double = 0
    private(set) var retries = 0
    /// Index of the last checkpoint reached (nil = the start line).
    private(set) var activeCheckpoint: Int?
    /// Seconds until the pending respawn (nil when the runner is fine).
    private(set) var respawnTimer: Double?

    private var nextFact = 0
    private var accumulator: Double = 0
    private var saidRelicTip = false
    private var takenMotes: Set<Int> = []
    private var usedGates: Set<Int> = []
    private var countedGates: Set<Int> = []
    private var usedSprings: Set<Int> = []
    private var guardianStartX: Double = 0
    /// Motes are sorted, so the scan starts from the first one not yet behind the runner.
    private var moteCursor = 0

    /// `variation` picks this run's random layout (pass a random value in the app; tests pass fixed ones).
    init(realm: Realm, totalRealms: Int, tuning: AgeTuning, mode: GuardianMode, companion: CompanionScript,
         variation: UInt64 = 0) {
        self.realm = realm
        self.tuning = tuning
        self.mode = mode
        self.companionScript = companion
        course = Course(realm: realm, totalRealms: totalRealms, tuning: tuning, variation: variation)
        runner = RunnerSim(course: course,
                           config: RunnerConfig(difficulty: realm.difficulty(totalRealms: totalRealms), tuning: tuning))
        self.companion = CompanionDirector(durationScale: tuning.bubbleDurationScale)

        // The realm title banner introduces the place; Lumi only adds the controls tip at first.
        if realm.order == 1 {
            self.companion.say(CompanionLine(text: companion.controlsTip.text(for: tuning.loreVariant),
                                             loreID: nil, priority: CompanionLine.Priority.tip, expiresAfter: 8))
        }
    }

    var variant: LoreVariant { tuning.loreVariant }
    var gatesPassed: Int { countedGates.count }
    /// Whether gate `i` has been used on this attempt (gates ahead of a checkpoint reset on respawn).
    func isGateUsed(_ i: Int) -> Bool { usedGates.contains(i) }

    /// Where the runner comes back after a failure in the run section.
    var respawnX: Double { activeCheckpoint.map { course.checkpoints[$0].x } ?? 80 }

    /// 0...1 progress for the HUD: the run section, then the guardian encounter.
    var progress: Double {
        switch phase {
        case .run: return min(runner.x / course.runLength, 1)
        case .guardian, .won: return guardian?.progress(runnerX: runner.x) ?? 1
        }
    }

    func press() { if phase == .run || phase == .guardian { runner.press() } }
    func release() { runner.release() }

    /// Advances by real elapsed time using fixed sub-steps (stable physics at 60 or 120 Hz).
    func advance(_ dt: Double, into events: inout SessionEvents) {
        accumulator += min(dt, 0.1)
        while accumulator >= RunSession.fixedStep {
            accumulator -= RunSession.fixedStep
            tick(RunSession.fixedStep, &events)
        }
    }

    private func tick(_ dt: Double, _ events: inout SessionEvents) {
        if let line = companion.step(dt) {
            if let id = line.loreID, !loreSeen.contains(id) { loreSeen.append(id) }
            events.companionLine = line
        }
        guard phase == .run || phase == .guardian else { return }
        time += dt

        if let t = respawnTimer {
            respawnTimer = t - dt
            if t - dt <= 0 { respawn(&events) }
            return
        }

        runner.step(dt, events: &events.runner)

        if phase == .run {
            checkRelics(&events)
            checkInteractables(&events)
            checkFacts()
            if runner.x >= course.runLength { enterGuardian(&events) }
        } else if let guardian {
            guardian.step(dt, runner: runner, course: course,
                          events: &events.guardian, runnerEvents: &events.runner)
            if guardian.finished { setPhase(.won, &events) }
        }

        if runner.failed, phase != .won {
            respawnTimer = RunSession.respawnDelay
            retries += 1
            events.failed = true
            // An encouraging word now and then (not on every stumble).
            if retries % 3 == 1, !companionScript.loseLines.isEmpty {
                let pick = companionScript.loseLines[retries % companionScript.loseLines.count]
                companion.say(CompanionLine(text: pick.text(for: variant), loreID: nil,
                                            priority: CompanionLine.Priority.tip, expiresAfter: 3))
            }
        }
    }

    private func respawn(_ events: inout SessionEvents) {
        respawnTimer = nil
        events.respawned = true
        switch phase {
        case .run:
            let x = respawnX
            runner.respawn(at: x)
            // Things ahead of the checkpoint can be used again on the next attempt.
            usedSprings = usedSprings.filter { course.springboards[$0].x < x }
            usedGates = usedGates.filter { course.gates[$0].x < x }
            moteCursor = course.motes.firstIndex { $0.x >= x - 40 } ?? course.motes.count
        case .guardian:
            // The encounter itself is the checkpoint: start it over.
            runner.respawn(at: guardianStartX)
            guardian = GuardianSim(mode: mode, startX: guardianStartX, tuning: tuning, seed: realm.seed &+ UInt64(retries))
        case .won:
            break
        }
    }

    private func checkRelics(_ events: inout SessionEvents) {
        for (i, spot) in course.relics.enumerated() where !collected.contains(i) {
            let dx = runner.x - spot.x
            if dx < -40 { break }
            let ry = course.surface(at: spot.x) + spot.lift
            let dy = (runner.y + 22) - ry
            if abs(dx) < 34, abs(dy) < 48 {
                collected.insert(i)
                events.relicsCollected.append(i)
                if collected.count == 1 {
                    companion.say(CompanionLine(text: "\(realm.relic.name)! " + realm.relic.lore.text(for: variant),
                                                loreID: realm.loreID(.relic), priority: CompanionLine.Priority.lore))
                }
            }
        }
        // Point out the first relic before the player reaches it.
        if !saidRelicTip, let first = course.relics.first, runner.x > first.x - 700 {
            saidRelicTip = true
            if realm.order <= 2 {
                companion.say(CompanionLine(text: companionScript.relicTip.text(for: variant),
                                            loreID: nil, priority: CompanionLine.Priority.tip, expiresAfter: 3))
            }
        }
    }

    private func checkInteractables(_ events: inout SessionEvents) {
        let x = runner.x
        let chestY = runner.y + 22  // roughly the runner's chest

        let motes = course.motes
        while moteCursor < motes.count, motes[moteCursor].x < x - 40 { moteCursor += 1 }
        var i = moteCursor
        while i < motes.count, motes[i].x < x + 40 {
            let m = motes[i]
            if !takenMotes.contains(i), abs(m.x - x) < 26,
               abs(chestY - (course.surface(at: m.x) + m.lift)) < 40 {
                takenMotes.insert(i)
                motesCollected += 1
                events.pickups.append(.mote(i))
            }
            i += 1
        }

        for (i, g) in course.gates.enumerated() where !usedGates.contains(i) && abs(g.x - x) < 24 {
            if abs(chestY - (course.surface(at: g.x) + g.lift)) < 46 {
                usedGates.insert(i)
                countedGates.insert(i)
                runner.addBoost(150)
                events.pickups.append(.gate(i))
            }
        }

        for (i, s) in course.springboards.enumerated()
        where !usedSprings.contains(i) && runner.grounded && abs(s.x - x) < 22 {
            usedSprings.insert(i)
            runner.launch(events: &events.runner)
            events.pickups.append(.springboard(i))
        }

        // Checkpoints save progress the moment the runner passes them, at any height.
        let next = (activeCheckpoint ?? -1) + 1
        if next < course.checkpoints.count, x >= course.checkpoints[next].x, !runner.failed {
            activeCheckpoint = next
            events.pickups.append(.checkpoint(next))
        }
    }

    private func checkFacts() {
        while nextFact < course.factTriggers.count, runner.x >= course.factTriggers[nextFact] {
            let fact = realm.facts[nextFact]
            companion.say(CompanionLine(text: fact.text(for: variant),
                                        loreID: realm.loreID(.fact(nextFact)), priority: CompanionLine.Priority.lore))
            nextFact += 1
        }
    }

    private func enterGuardian(_ events: inout SessionEvents) {
        guardianStartX = runner.x
        guardian = GuardianSim(mode: mode, startX: runner.x, tuning: tuning, seed: realm.seed)
        runner.hazardsEnabled = false
        companion.say(CompanionLine(text: realm.guardian.intro.text(for: variant),
                                    loreID: realm.loreID(.guardian), priority: CompanionLine.Priority.guardian))
        setPhase(.guardian, &events)
    }

    private func setPhase(_ newPhase: Phase, _ events: inout SessionEvents) {
        guard phase != newPhase else { return }
        phase = newPhase
        events.phaseChanged = newPhase
        if newPhase == .won, !companionScript.winLines.isEmpty {
            let pick = companionScript.winLines[Int(time) % companionScript.winLines.count]
            companion.say(CompanionLine(text: pick.text(for: variant), loreID: nil,
                                        priority: CompanionLine.Priority.outcome))
        }
    }

    var result: RunResult {
        RunResult(realmID: realm.id, won: phase == .won, relics: collected.count,
                  flips: runner.totalFlips, bestCombo: runner.bestCombo,
                  loreSeen: loreSeen, time: time,
                  motes: motesCollected, totalMotes: course.motes.count, gates: gatesPassed,
                  retries: retries)
    }
}
