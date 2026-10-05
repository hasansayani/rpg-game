import SwiftUI

@main
struct MythrunnerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}

/// App-wide state: content, settings and progress. Persists to UserDefaults on every change.
@MainActor
final class AppModel: ObservableObject {
    let catalog: RealmCatalog
    private let store = SaveStore(store: UserDefaults.standard)

    @Published var settings: PlayerSettings { didSet { store.save(settings) } }
    @Published var progress: PlayerProgress { didSet { store.save(progress) } }

    init() {
        do {
            catalog = try RealmCatalog.loadBundled()
        } catch {
            fatalError("realms.json missing or invalid: \(error)")
        }
        settings = store.loadSettings()
        progress = store.loadProgress()
    }

    var realms: [Realm] { catalog.realms }
    var tuning: AgeTuning { settings.tuning }

    func isUnlocked(_ realm: Realm) -> Bool {
        progress.isUnlocked(realm, in: realms, unlockAll: settings.unlockAll)
    }

    func next(after realm: Realm) -> Realm? {
        realms.first { $0.order == realm.order + 1 }
    }

    func palette(for realm: Realm) -> ResolvedPalette {
        ResolvedPalette(palette: realm.palette, guardianHex: realm.guardian.color, tuning: tuning)
    }

    func lore(for realm: Realm) -> [LoreEntry] {
        var items = realm.facts.enumerated().map { i, f in
            LoreEntry(id: realm.loreID(.fact(i)), title: "Story \(i + 1)", lore: f)
        }
        items.append(LoreEntry(id: realm.loreID(.relic), title: realm.relic.name, lore: realm.relic.lore))
        items.append(LoreEntry(id: realm.loreID(.guardian), title: realm.guardian.name, lore: realm.guardian.intro))
        return items
    }
}

struct LoreEntry: Identifiable {
    let id: String
    let title: String
    let lore: Lore
}
