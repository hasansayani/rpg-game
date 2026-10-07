import Foundation

/// Age bands chosen at the first-launch age gate.
enum AgeBand: String, Codable, CaseIterable {
    /// Ages up to 9: brighter, rounder, slower, more forgiving, simple language.
    case sprout
    /// Ages 10–13: the baseline experience.
    case explorer
    /// Ages 14+: moodier atmosphere, faster, fuller historical detail.
    case legend

    init(age: Int) {
        switch age {
        case ..<10: self = .sprout
        case 10...13: self = .explorer
        default: self = .legend
        }
    }

    var title: String {
        switch self {
        case .sprout: return "Sprout (under 10)"
        case .explorer: return "Explorer (10–13)"
        case .legend: return "Legend (14+)"
        }
    }
}

/// Every age-dependent knob in one place, so designers can tune by data.
struct AgeTuning: Equatable {
    var band: AgeBand

    // Gameplay
    var speedScale: Double
    /// Distance between checkpoints: younger players restart closer to where they failed.
    var checkpointSpacing: Double
    var obstacleScale: Double
    var gapScale: Double
    /// Max angle (radians) between board and slope that still counts as a clean landing.
    var landingTolerance: Double
    /// Extra guardian speed over the runner's base speed in chase mode.
    var guardianAggression: Double
    var gauntletInterval: Double

    // Visuals
    var saturation: Double
    var brightness: Double
    var fogStrength: Double
    var vignette: Double
    var particleScale: Double
    var screenShake: Bool
    var cuteGuardians: Bool

    // Companion
    var loreVariant: LoreVariant
    var textScale: Double
    var bubbleDurationScale: Double

    static func forAge(_ age: Int) -> AgeTuning { forBand(AgeBand(age: age)) }

    static func forBand(_ band: AgeBand) -> AgeTuning {
        switch band {
        case .sprout:
            return AgeTuning(band: band, speedScale: 0.82, checkpointSpacing: 1400, obstacleScale: 0.5, gapScale: 0.4,
                             landingTolerance: 1.05, guardianAggression: 0.0, gauntletInterval: 2.4,
                             saturation: 1.2, brightness: 1.08, fogStrength: 0.12, vignette: 0.0,
                             particleScale: 1.1, screenShake: false, cuteGuardians: true,
                             loreVariant: .kid, textScale: 1.25, bubbleDurationScale: 1.4)
        case .explorer:
            return AgeTuning(band: band, speedScale: 1.0, checkpointSpacing: 2000, obstacleScale: 1.0, gapScale: 1.0,
                             landingTolerance: 0.8, guardianAggression: 0.04, gauntletInterval: 1.8,
                             saturation: 1.0, brightness: 1.0, fogStrength: 0.28, vignette: 0.15,
                             particleScale: 1.0, screenShake: true, cuteGuardians: false,
                             loreVariant: .standard, textScale: 1.0, bubbleDurationScale: 1.0)
        case .legend:
            return AgeTuning(band: band, speedScale: 1.12, checkpointSpacing: 2600, obstacleScale: 1.3, gapScale: 1.25,
                             landingTolerance: 0.65, guardianAggression: 0.08, gauntletInterval: 1.4,
                             saturation: 0.88, brightness: 0.94, fogStrength: 0.42, vignette: 0.32,
                             particleScale: 1.3, screenShake: true, cuteGuardians: false,
                             loreVariant: .standard, textScale: 0.95, bubbleDurationScale: 0.9)
        }
    }
}
