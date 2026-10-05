import Foundation

/// Minimal key-value persistence so Progress is testable without UserDefaults.
protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: KeyValueStore {}

final class MemoryStore: KeyValueStore {
    private var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value as? Data }
}

struct PlayerSettings: Codable, Equatable {
    /// nil until the age gate has been answered.
    var age: Int?
    var guardianMode: GuardianModeSetting = .chase
    var unlockAll = false
    var showFPS = false
    var haptics = true

    var tuning: AgeTuning { AgeTuning.forAge(age ?? 10) }
}

struct PlayerProgress: Codable, Equatable {
    var completed: Set<String> = []
    var loreSeen: Set<String> = []
    var relicsFound: [String: Int] = [:]
    var bestFlips: [String: Int] = [:]
    var attempts: [String: Int] = [:]

    /// Realms unlock in order: the first, plus one past the furthest completed.
    func isUnlocked(_ realm: Realm, in realms: [Realm], unlockAll: Bool) -> Bool {
        if unlockAll || realm.order == 1 { return true }
        guard let previous = realms.first(where: { $0.order == realm.order - 1 }) else { return true }
        return completed.contains(previous.id)
    }

    mutating func record(_ result: RunResult) {
        attempts[result.realmID, default: 0] += 1
        loreSeen.formUnion(result.loreSeen)
        relicsFound[result.realmID] = max(relicsFound[result.realmID] ?? 0, result.relics)
        bestFlips[result.realmID] = max(bestFlips[result.realmID] ?? 0, result.flips)
        if result.won { completed.insert(result.realmID) }
    }
}

final class SaveStore {
    private let store: KeyValueStore
    private let settingsKey = "mythrunner.settings.v1"
    private let progressKey = "mythrunner.progress.v1"

    init(store: KeyValueStore) { self.store = store }

    func loadSettings() -> PlayerSettings { load(settingsKey) ?? PlayerSettings() }
    func loadProgress() -> PlayerProgress { load(progressKey) ?? PlayerProgress() }
    func save(_ settings: PlayerSettings) { save(settings, settingsKey) }
    func save(_ progress: PlayerProgress) { save(progress, progressKey) }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        store.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
