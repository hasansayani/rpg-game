import Foundation

// Pure data models decoded from realms.json.
// Core/ has no SpriteKit/UIKit imports so it can be unit-tested on Linux
// and ported 1:1 to GDScript (see docs/PORTING_GODOT.md).

struct RealmCatalog: Codable {
    var schemaVersion: Int
    var companion: CompanionScript
    var realms: [Realm]

    static func decode(from data: Data) throws -> RealmCatalog {
        var catalog = try JSONDecoder().decode(RealmCatalog.self, from: data)
        catalog.realms.sort { $0.order < $1.order }
        return catalog
    }

    static func loadBundled(from bundle: Bundle = .main) throws -> RealmCatalog {
        guard let url = bundle.url(forResource: "realms", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(from: Data(contentsOf: url))
    }
}

struct CompanionScript: Codable {
    var name: String
    var controlsTip: Lore
    var relicTip: Lore
    var winLines: [Lore]
    var loseLines: [Lore]
}

/// A piece of text with a simplified variant for young players.
struct Lore: Codable, Hashable {
    var text: String
    var kid: String

    func text(for variant: LoreVariant) -> String {
        variant == .kid ? kid : text
    }
}

enum LoreVariant: String, Codable {
    case kid, standard
}

enum Region: String, Codable, CaseIterable {
    case europe, africa, asia, middleEast, americas, oceania

    var displayName: String {
        switch self {
        case .europe: return "Europe"
        case .africa: return "Africa"
        case .asia: return "Asia"
        case .middleEast: return "Middle East"
        case .americas: return "Americas"
        case .oceania: return "Oceania"
        }
    }
}

struct Realm: Codable, Identifiable, Hashable {
    var id: String
    var order: Int
    var name: String
    var culture: String
    var region: Region
    var place: String
    var era: String
    var tags: [String]
    var living: Bool
    var palette: Palette
    var scenery: Scenery
    var facts: [Lore]
    var relic: Relic
    var guardian: Guardian
    /// Cultural-review note for living traditions. Shown in debug builds only.
    var review: String?

    /// 0 for the first realm, 1 for the last. Drives hazard density and speed.
    func difficulty(totalRealms: Int) -> Double {
        guard totalRealms > 1 else { return 0 }
        return Double(order - 1) / Double(totalRealms - 1)
    }

    /// Deterministic seed so a realm's course is identical every run (and in a Godot port).
    var seed: UInt64 {
        // FNV-1a over the id.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    func loreID(_ kind: LoreKind) -> String {
        switch kind {
        case .fact(let index): return "\(id).fact.\(index)"
        case .relic: return "\(id).relic"
        case .guardian: return "\(id).guardian"
        }
    }
}

enum LoreKind: Hashable {
    case fact(Int)
    case relic
    case guardian
}

struct Palette: Codable, Hashable {
    var skyTop: String
    var skyBottom: String
    var far: String
    var mid: String
    var near: String
    var ground: String
    var groundEdge: String
    var accent: String
}

struct Scenery: Codable, Hashable {
    var far: FarStyle
    var landmarks: [Landmark]
    var weather: Weather
    /// Terrain hill height in points.
    var amplitude: Double
    /// Relative hill frequency (1.0 = default rolling).
    var frequency: Double
}

enum FarStyle: String, Codable, CaseIterable {
    case peaks, dunes, rolling, volcano, karst, mesas, icebergs, cliffs
}

enum Landmark: String, Codable, CaseIterable {
    case columns, pine, pyramid, palm, obelisk, longhouse, standingStones, torii, pagoda
    case stepPyramid, cactus, hut, shikhara, ziggurat, baobab, fern, onionDome, birch
    case acacia, inuksuk, igloo, dome, terraces, yurt, cairn, lionGate, moai, granary
}

enum Weather: String, Codable, CaseIterable {
    case none, snow, sand, leaves, petals, rain, mist, embers, fireflies, aurora, lanterns
}

struct Relic: Codable, Hashable {
    var name: String
    var text: String
    var kid: String

    var lore: Lore { Lore(text: text, kid: kid) }
}

struct Guardian: Codable, Hashable {
    var name: String
    var kind: GuardianKind
    var shape: GuardianShape
    var color: String
    var suggestedMode: GuardianMode
    var intro: Lore
}

/// Framing matters for living cultures: a "trial" or "force" is never an evil deity.
enum GuardianKind: String, Codable {
    case creature, force, trial
}

enum GuardianShape: String, Codable, CaseIterable {
    case giant, serpent, beast, bird, wave, storm, spirit
}

enum GuardianMode: String, Codable, CaseIterable, Identifiable {
    case chase, gauntlet, weakpoint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chase: return "Chase & Escape"
        case .gauntlet: return "Survive the Gauntlet"
        case .weakpoint: return "Strike the Weak Points"
        }
    }

    var instruction: Lore {
        switch self {
        case .chase:
            return Lore(text: "It's gaining on us! Flip for speed and escape!",
                        kid: "It's chasing us! Do flips to go faster!")
        case .gauntlet:
            return Lore(text: "Survive its attacks! Jump the low ones, stay grounded under the high ones.",
                        kid: "Jump over the low things, stay down for the high ones!")
        case .weakpoint:
            return Lore(text: "See the three glowing weak points? Jump into them!",
                        kid: "Jump into the three glowing lights!")
        }
    }
}

/// The player's choice in Settings. `.realmChoice` uses each realm's suggestedMode.
enum GuardianModeSetting: String, Codable, CaseIterable, Identifiable {
    case chase, gauntlet, weakpoint, realmChoice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .realmChoice: return "Realm's Choice (mixed)"
        default: return resolve(for: nil).title
        }
    }

    func resolve(for guardian: Guardian?) -> GuardianMode {
        switch self {
        case .chase: return .chase
        case .gauntlet: return .gauntlet
        case .weakpoint: return .weakpoint
        case .realmChoice: return guardian?.suggestedMode ?? .chase
        }
    }
}
