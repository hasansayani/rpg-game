import Foundation

/// One line Lumi will say. `loreID` is set when the line should be recorded in the Codex.
struct CompanionLine: Equatable {
    var text: String
    var loreID: String?
    var priority: Int
    /// Drop the line if it waited longer than this in the queue (used for tips that go stale).
    var expiresAfter: Double? = nil

    enum Priority {
        static let tip = 0
        static let lore = 2
        static let guardian = 3
        static let outcome = 4
    }
}

/// Navi-style companion pacing: never blocks play, never stacks bubbles,
/// keeps a breather between lines so the player isn't flooded with text.
struct CompanionDirector {
    private(set) var queue: [CompanionLine] = []
    private var waited: [Double] = []
    private(set) var current: CompanionLine?
    private(set) var remaining: Double = 0
    private var cooldown: Double = 0.8
    let durationScale: Double

    init(durationScale: Double) {
        self.durationScale = durationScale
    }

    static func duration(for text: String, scale: Double) -> Double {
        min((1.6 + Double(text.count) * 0.04) * scale, 7.5)
    }

    mutating func say(_ line: CompanionLine) {
        // Higher priority lines jump the queue; ties keep arrival order.
        let index = queue.firstIndex(where: { $0.priority < line.priority }) ?? queue.count
        queue.insert(line, at: index)
        waited.insert(0, at: index)
    }

    /// Returns a line when a new bubble should appear.
    mutating func step(_ dt: Double) -> CompanionLine? {
        for i in waited.indices { waited[i] += dt }
        if current != nil {
            remaining -= dt
            if remaining <= 0 {
                current = nil
                cooldown = 0.6
            }
            return nil
        }
        for i in stride(from: queue.count - 1, through: 0, by: -1) {
            if let limit = queue[i].expiresAfter, waited[i] > limit {
                queue.remove(at: i)
                waited.remove(at: i)
            }
        }
        cooldown -= dt
        guard cooldown <= 0, !queue.isEmpty else { return nil }
        let line = queue.removeFirst()
        waited.removeFirst()
        current = line
        remaining = CompanionDirector.duration(for: line.text, scale: durationScale)
        return line
    }

    var isSpeaking: Bool { current != nil }
}
