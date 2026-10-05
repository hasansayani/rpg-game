import Foundation

/// Everything that happened during one simulation tick, for the renderer to react to.
struct SessionEvents {
    var runner: [RunnerEvent] = []
    var guardian: [GuardianEvent] = []
    var relicsCollected: [Int] = []
    var phaseChanged: RunSession.Phase?
    var companionLine: CompanionLine?

    mutating func clear() {
        runner.removeAll(keepingCapacity: true)
        guardian.removeAll(keepingCapacity: true)
        relicsCollected.removeAll(keepingCapacity: true)
        phaseChanged = nil
        companionLine = nil
    }
}

struct RunResult: Equatable {
    var realmID: String
    var won: Bool
    var relics: Int
    var flips: Int
    var bestCombo: Int
    var loreSeen: [String]
    var time: Double
}

/// The whole game model for one realm: runner + course + guardian + companion.
/// The SpriteKit scene only renders this and forwards touches (and a Godot port would do the same).
final class RunSession {
    enum Phase: Equatable { case run, guardian, won, lost }

    static let fixedStep: Double = 1.0 / 120.0

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
    private(set) var loreSeen: [String] = []
    private(set) var time: Double = 0

    private var nextFact = 0
    private var accumulator: Double = 0
    private var saidRelicTip = false

    init(realm: Realm, totalRealms: Int, tuning: AgeTuning, mode: GuardianMode, companion: CompanionScript) {
        self.realm = realm
        self.tuning = tuning
        self.mode = mode
        self.companionScript = companion
        course = Course(realm: realm, totalRealms: totalRealms, tuning: tuning)
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

    /// 0...1 progress for the HUD: the run section, then the guardian encounter.
    var progress: Double {
        switch phase {
        case .run: return min(runner.x / course.runLength, 1)
        case .guardian, .won, .lost: return guardian?.progress(runnerX: runner.x) ?? 1
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

        runner.step(dt, events: &events.runner)

        if phase == .run {
            checkRelics(&events)
            checkFacts()
            if runner.x >= course.runLength { enterGuardian(&events) }
        } else if let guardian {
            guardian.step(dt, runner: runner, course: course,
                          events: &events.guardian, runnerEvents: &events.runner)
            if guardian.finished { setPhase(.won, &events) }
        }

        if !runner.isAlive { setPhase(.lost, &events) }
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

    private func checkFacts() {
        while nextFact < course.factTriggers.count, runner.x >= course.factTriggers[nextFact] {
            let fact = realm.facts[nextFact]
            companion.say(CompanionLine(text: fact.text(for: variant),
                                        loreID: realm.loreID(.fact(nextFact)), priority: CompanionLine.Priority.lore))
            nextFact += 1
        }
    }

    private func enterGuardian(_ events: inout SessionEvents) {
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
        let lines = newPhase == .won ? companionScript.winLines : newPhase == .lost ? companionScript.loseLines : []
        if !lines.isEmpty {
            let pick = lines[Int(time) % lines.count]
            companion.say(CompanionLine(text: pick.text(for: variant), loreID: nil,
                                        priority: CompanionLine.Priority.outcome))
        }
    }

    var result: RunResult {
        RunResult(realmID: realm.id, won: phase == .won, relics: collected.count,
                  flips: runner.totalFlips, bestCombo: runner.bestCombo,
                  loreSeen: loreSeen, time: time)
    }
}
