// swift-tools-version:5.9
// Builds the engine-agnostic game core (Mythrunner/Core) so it can be unit-tested
// on any platform with `swift test` — no Xcode or simulator required.
// The iOS app itself is built from Mythrunner.xcodeproj.
import PackageDescription

let package = Package(
    name: "MythrunnerCore",
    products: [
        .library(name: "MythrunnerCore", targets: ["MythrunnerCore"]),
    ],
    targets: [
        .target(name: "MythrunnerCore", path: "Mythrunner/Core"),
        .testTarget(name: "MythrunnerCoreTests", dependencies: ["MythrunnerCore"],
                    path: "Tests/MythrunnerCoreTests"),
    ],
    swiftLanguageVersions: [.v5]
)
