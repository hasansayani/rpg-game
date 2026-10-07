import SpriteKit
import UIKit

/// Time of day, the night sky, life in the daytime sky, and passing weather.
///
/// - Each checkpoint moves the clock on one phase (day → dusk → night → dawn → day), blended
///   gradually over a few seconds.
/// - At night: stars, a moon, a bright planet, and a constellation the realm's culture knew.
/// - By day: silhouetted local birds or mythical creatures cross the sky now and then.
/// - Weather suited to the biome (rain, mist, snow, sand, embers…) comes and goes at random.
final class SkyDirector {
    enum Constellation { case orion, dipper, pleiades, southernCross, taurus, sirius }
    enum Flyer { case flock, crane, raven, raptor, longTail, pegasus }

    private let realm: Realm
    private let palette: ResolvedPalette
    private let dot: SKTexture
    private let skyLayer: SKNode
    private let cam: SKNode
    private let sunNodes: [SKNode]
    private let water: Bool
    private let particleScale: Double
    private var rng: SeededRandom

    private let tint = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: 10))
    private let shade = SKSpriteNode(color: .clear, size: CGSize(width: 10, height: 10))
    private let stars = SKNode()
    private let constellationNode = SKNode()
    private let moon = SKNode()
    private let flash = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
    private var size: CGSize

    /// Continuous time of day: 0 day, 1 dusk, 2 night, 3 dawn (wraps at 4).
    private var clock: CGFloat = 0
    private var target: CGFloat = 0
    private var flyerTimer: Double = 4
    private var weatherTimer: Double
    private var weather: SKEmitterNode?
    private var raining = false
    private var lightningTimer: Double = 3

    init(realm: Realm, palette: ResolvedPalette, size: CGSize, dot: SKTexture, skyLayer: SKNode, cam: SKNode,
         sunNodes: [SKNode], water: Bool, particleScale: Double, seed: UInt64) {
        self.realm = realm
        self.palette = palette
        self.size = size
        self.dot = dot
        self.skyLayer = skyLayer
        self.cam = cam
        self.sunNodes = sunNodes
        self.water = water
        self.particleScale = particleScale
        rng = SeededRandom(seed: seed ^ 0x5EED_5C1E)
        weatherTimer = rng.range(10, 20)

        tint.zPosition = 1
        tint.alpha = 0
        skyLayer.addChild(tint)
        stars.zPosition = 2
        stars.alpha = 0
        skyLayer.addChild(stars)
        constellationNode.zPosition = 3
        constellationNode.alpha = 0
        skyLayer.addChild(constellationNode)
        moon.zPosition = 2
        moon.alpha = 0
        skyLayer.addChild(moon)
        shade.zPosition = 17
        shade.alpha = 0
        cam.addChild(shade)
        flash.zPosition = 19
        flash.alpha = 0
        flash.blendMode = .add
        cam.addChild(flash)

        buildStars()
        buildMoon()
        if !water { buildConstellation() }
        layout(size: size)
    }

    // MARK: Build

    private func buildStars() {
        var r = SeededRandom(seed: realm.seed &+ 11)
        for _ in 0..<90 {
            let s = SKSpriteNode(texture: dot)
            let big = r.unit() < 0.15
            s.size = CGSize(width: big ? 5 : 3, height: big ? 5 : 3)
            s.position = CGPoint(x: r.range(-0.5, 0.5), y: r.range(0.0, 0.5))  // normalized; scaled in layout
            s.userData = ["n": NSValue(cgPoint: s.position)]
            s.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: r.range(0.6, 1.6)),
                                            .fadeAlpha(to: 1, duration: r.range(0.6, 1.6))])))
            stars.addChild(s)
        }
    }

    private func buildMoon() {
        let glow = SKSpriteNode(texture: dot)
        glow.color = UIColor(white: 0.95, alpha: 1); glow.colorBlendFactor = 1; glow.blendMode = .add
        glow.size = CGSize(width: 150, height: 150); glow.alpha = 0.5
        moon.addChild(glow)
        let disc = SKSpriteNode(texture: TextureFactory.image(size: CGSize(width: 48, height: 48)) { ctx in
            ctx.addEllipse(in: CGRect(x: 1, y: 1, width: 46, height: 46))
            ctx.clip()
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 0.99, b: 0.92), RGBA(r: 0.86, g: 0.86, b: 0.8)],
                                          center: CGPoint(x: 20, y: 18), radius: 26)
            ctx.setFillColor(RGBA(r: 0.75, g: 0.75, b: 0.72).cgColor)
            for c in [CGRect(x: 12, y: 14, width: 9, height: 7), CGRect(x: 26, y: 26, width: 11, height: 9), CGRect(x: 28, y: 10, width: 5, height: 5)] {
                ctx.fillEllipse(in: c)
            }
        })
        moon.addChild(disc)
        // A bright planet near the moon.
        let planet = SKSpriteNode(texture: dot)
        planet.color = UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1); planet.colorBlendFactor = 1; planet.blendMode = .add
        planet.size = CGSize(width: 16, height: 16)
        planet.position = CGPoint(x: 150, y: -40)
        moon.addChild(planet)
    }

    /// The constellation shown at night, and what this culture called it (only well-attested names).
    static func constellation(for realmID: String) -> (Constellation, String)? {
        switch realmID {
        case "greek", "hittite": return (.orion, "Orion")
        case "egyptian": return (.orion, "Sah — Orion, star of Osiris")
        case "norse": return (.dipper, "Karlsvagn — the Wagon")
        case "japanese": return (.pleiades, "Subaru — the Pleiades")
        case "aztec": return (.pleiades, "Tianquiztli — the Marketplace")
        case "celtic": return (.dipper, "The Plough")
        case "hindu": return (.dipper, "Saptarishi — the Seven Sages")
        case "sumerian": return (.taurus, "The Bull of Heaven")
        case "persian": return (.taurus, "Taurus")
        case "maori", "rapanui": return (.pleiades, "Matariki")
        case "chinese": return (.dipper, "Běidǒu — the Northern Dipper")
        case "maya": return (.pleiades, "The Pleiades")
        case "slavic", "etruscan", "ainu": return (.dipper, "The Great Bear")
        case "zulu": return (.pleiades, "Isilimela — the Pleiades")
        case "hawaiian": return (.pleiades, "Makaliʻi — the Pleiades")
        case "inca": return (.southernCross, "Chakana — the Southern Cross")
        case "guarani": return (.southernCross, "The Southern Cross")
        case "finnish": return (.dipper, "Otava")
        case "mongolian": return (.dipper, "Doloon Burkhan — the Seven Gods")
        case "dogon": return (.sirius, "Sigi Tolo — Sirius")
        case "yoruba", "akan", "taino", "san": return (.orion, "Orion")
        default: return nil
        }
    }

    private func buildConstellation() {
        guard let (kind, name) = SkyDirector.constellation(for: realm.id) else { return }
        let w: CGFloat = 200, h: CGFloat = 130
        let (stars, links): ([CGPoint], [(Int, Int)]) = {
            switch kind {
            case .orion:
                return ([CGPoint(x: 0.2, y: 0.85), CGPoint(x: 0.78, y: 0.8), CGPoint(x: 0.4, y: 0.5), CGPoint(x: 0.5, y: 0.47),
                         CGPoint(x: 0.6, y: 0.44), CGPoint(x: 0.25, y: 0.08), CGPoint(x: 0.75, y: 0.12)],
                        [(0, 2), (1, 4), (2, 3), (3, 4), (2, 5), (4, 6)])
            case .dipper:
                return ([CGPoint(x: 0, y: 0.75), CGPoint(x: 0.18, y: 0.68), CGPoint(x: 0.34, y: 0.62), CGPoint(x: 0.5, y: 0.55),
                         CGPoint(x: 0.55, y: 0.25), CGPoint(x: 0.85, y: 0.2), CGPoint(x: 0.9, y: 0.52)],
                        [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 3)])
            case .pleiades:
                return ([CGPoint(x: 0.4, y: 0.55), CGPoint(x: 0.5, y: 0.62), CGPoint(x: 0.58, y: 0.5), CGPoint(x: 0.47, y: 0.44),
                         CGPoint(x: 0.62, y: 0.62), CGPoint(x: 0.36, y: 0.42), CGPoint(x: 0.53, y: 0.36)], [])
            case .southernCross:
                return ([CGPoint(x: 0.5, y: 0.95), CGPoint(x: 0.5, y: 0.1), CGPoint(x: 0.22, y: 0.55), CGPoint(x: 0.8, y: 0.6),
                         CGPoint(x: 0.66, y: 0.35)], [(0, 1), (2, 3)])
            case .taurus:
                return ([CGPoint(x: 0.5, y: 0.25), CGPoint(x: 0.38, y: 0.5), CGPoint(x: 0.62, y: 0.5), CGPoint(x: 0.25, y: 0.75),
                         CGPoint(x: 0.75, y: 0.75), CGPoint(x: 0.05, y: 0.95), CGPoint(x: 0.95, y: 0.95)],
                        [(0, 1), (0, 2), (1, 3), (2, 4), (3, 5), (4, 6)])
            case .sirius:
                return ([CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.56, y: 0.44)], [])
            }
        }()
        let pts = stars.map { CGPoint(x: ($0.x - 0.5) * w, y: ($0.y - 0.5) * h) }
        let lines = CGMutablePath()
        for (a, b) in links { lines.move(to: pts[a]); lines.addLine(to: pts[b]) }
        let shape = SKShapeNode(path: lines)
        shape.strokeColor = UIColor(white: 1, alpha: 0.35)
        shape.lineWidth = 1.2
        constellationNode.addChild(shape)
        for (i, p) in pts.enumerated() {
            let s = SKSpriteNode(texture: dot)
            s.blendMode = .add
            let big = kind == .sirius && i == 0
            s.size = CGSize(width: big ? 22 : 12, height: big ? 22 : 12)
            s.color = big ? UIColor(red: 0.8, green: 0.9, blue: 1, alpha: 1) : .white
            s.colorBlendFactor = 1
            s.position = p
            constellationNode.addChild(s)
        }
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = name
        label.fontSize = 12
        label.fontColor = UIColor(white: 1, alpha: 0.75)
        label.position = CGPoint(x: 0, y: -h / 2 - 16)
        constellationNode.addChild(label)
    }

    func layout(size: CGSize) {
        self.size = size
        tint.size = CGSize(width: size.width + 4, height: size.height + 4)
        shade.size = tint.size
        flash.size = tint.size
        for case let s as SKSpriteNode in stars.children {
            if let n = (s.userData?["n"] as? NSValue)?.cgPointValue {
                s.position = CGPoint(x: n.x * size.width, y: n.y * size.height)
            }
        }
        moon.position = CGPoint(x: -size.width * 0.28, y: size.height * 0.28)
        constellationNode.position = CGPoint(x: size.width * 0.12, y: size.height * 0.3)
    }

    // MARK: Clock

    /// Called when a checkpoint is reached: start blending to the next phase of the day.
    func advancePhase() { target += 1 }

    /// Jumps straight to a phase (0 day … 3 dawn), for QA screenshots.
    func setPhase(_ phase: Int) { clock = CGFloat(phase); target = clock }

    /// Weight of each phase at the current clock (they blend linearly between neighbours).
    private func weight(_ phase: CGFloat) -> CGFloat {
        let c = clock.truncatingRemainder(dividingBy: 4)
        var d = abs(c - phase)
        d = min(d, 4 - d)
        return max(0, 1 - d)
    }

    // MARK: Per frame

    func update(dt: CGFloat, camX: CGFloat) {
        // Ease the clock toward its target (about six seconds per phase).
        if clock < target { clock = min(target, clock + dt / 6) }
        let day = weight(0), dusk = weight(1), night = weight(2), dawn = weight(3)

        // Sky tint and world shading.
        let colors: [(RGBA, CGFloat, CGFloat)] = [
            (RGBA(r: 1, g: 0.45, b: 0.25), 0.4, 0.12),   // dusk
            (RGBA(r: 0.04, g: 0.06, b: 0.2), 0.82, 0.4), // night
            (RGBA(r: 1, g: 0.65, b: 0.62), 0.3, 0.08),   // dawn
        ]
        let ws = [dusk, night, dawn]
        let total = max(ws.reduce(0, +), 0.0001)
        var mix = RGBA(r: 0, g: 0, b: 0)
        for (w, c) in zip(ws, colors) {
            mix = RGBA(r: mix.r + c.0.r * Double(w / total), g: mix.g + c.0.g * Double(w / total), b: mix.b + c.0.b * Double(w / total))
        }
        tint.color = mix.skColor
        tint.alpha = zip(ws, colors).reduce(0) { $0 + $1.0 * $1.1.1 }
        shade.color = RGBA(r: 0.05, g: 0.06, b: 0.18).skColor
        shade.alpha = zip(ws, colors).reduce(0) { $0 + $1.0 * $1.1.2 }

        let starAlpha = water ? 0 : min(1, night + 0.4 * (dusk + dawn) * night)
        stars.alpha = starAlpha
        constellationNode.alpha = water ? 0 : night
        moon.alpha = water ? 0 : night + 0.35 * dawn
        for n in sunNodes { n.alpha = water ? 0 : (day + 0.6 * dusk + 0.6 * dawn) * (n.name == "halo" ? 0.6 : 1) }

        updateFlyers(dt: Double(dt), daylight: day + 0.5 * (dusk + dawn))
        updateWeather(dt: Double(dt), night: night)
    }

    // MARK: Sky life

    static func flyer(for realmID: String) -> Flyer {
        switch realmID {
        case "greek": return .pegasus
        case "norse", "akan": return .raven
        case "japanese", "chinese", "ainu", "finnish", "egyptian": return .crane
        case "hindu", "sumerian", "zulu", "inca", "mongolian", "hittite", "maori": return .raptor
        case "aztec", "maya", "slavic", "persian": return .longTail
        default: return .flock
        }
    }

    private func flyerFrames(_ kind: Flyer, color: RGBA) -> [SKTexture] {
        [true, false].map { up in
            TextureFactory.image(size: CGSize(width: 90, height: 50)) { ctx in
                ctx.setFillColor(color.cgColor)
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineCap(.round)
                let wingY: CGFloat = up ? 6 : 42
                func wings(span: CGFloat, at c: CGPoint) {
                    ctx.setLineWidth(4)
                    ctx.move(to: CGPoint(x: c.x - span, y: wingY))
                    ctx.addQuadCurve(to: c, control: CGPoint(x: c.x - span * 0.4, y: (wingY + c.y) / 2 - 4))
                    ctx.addQuadCurve(to: CGPoint(x: c.x + span, y: wingY), control: CGPoint(x: c.x + span * 0.4, y: (wingY + c.y) / 2 - 4))
                    ctx.strokePath()
                }
                switch kind {
                case .flock:
                    for (dx, dy) in [(0.0, 0.0), (-16.0, 8.0), (-30.0, 14.0), (14.0, 9.0)] as [(CGFloat, CGFloat)] {
                        ctx.setLineWidth(2)
                        let c = CGPoint(x: 45 + dx, y: 24 + dy)
                        ctx.move(to: CGPoint(x: c.x - 7, y: c.y + (up ? -5 : 4)))
                        ctx.addLine(to: c)
                        ctx.addLine(to: CGPoint(x: c.x + 7, y: c.y + (up ? -5 : 4)))
                        ctx.strokePath()
                    }
                case .crane:
                    ctx.setLineWidth(3)
                    ctx.move(to: CGPoint(x: 10, y: 26)); ctx.addLine(to: CGPoint(x: 80, y: 24)); ctx.strokePath()  // neck to legs
                    wings(span: 26, at: CGPoint(x: 45, y: 25))
                case .raven:
                    ctx.fillEllipse(in: CGRect(x: 34, y: 20, width: 24, height: 10))
                    ctx.fillEllipse(in: CGRect(x: 54, y: 19, width: 9, height: 8))
                    wings(span: 24, at: CGPoint(x: 44, y: 24))
                case .raptor:
                    ctx.fillEllipse(in: CGRect(x: 30, y: 20, width: 30, height: 11))
                    ctx.move(to: CGPoint(x: 30, y: 25)); ctx.addLine(to: CGPoint(x: 18, y: 20)); ctx.addLine(to: CGPoint(x: 18, y: 30)); ctx.fillPath()
                    wings(span: 40, at: CGPoint(x: 45, y: 25))
                case .longTail:
                    ctx.fillEllipse(in: CGRect(x: 40, y: 20, width: 22, height: 10))
                    ctx.setLineWidth(3)
                    ctx.move(to: CGPoint(x: 42, y: 25)); ctx.addCurve(to: CGPoint(x: 2, y: 30), control1: CGPoint(x: 26, y: 40), control2: CGPoint(x: 14, y: 16)); ctx.strokePath()
                    wings(span: 28, at: CGPoint(x: 50, y: 24))
                case .pegasus:
                    // A winged horse in flight.
                    ctx.fillEllipse(in: CGRect(x: 28, y: 24, width: 36, height: 14))
                    ctx.setLineWidth(5)
                    ctx.move(to: CGPoint(x: 60, y: 28)); ctx.addLine(to: CGPoint(x: 72, y: 16)); ctx.strokePath()
                    ctx.fillEllipse(in: CGRect(x: 68, y: 10, width: 14, height: 9))
                    ctx.setLineWidth(3)
                    for x in [34.0, 40.0, 56.0, 60.0] as [CGFloat] {
                        ctx.move(to: CGPoint(x: x, y: 36)); ctx.addLine(to: CGPoint(x: x - 6, y: 46)); ctx.strokePath()
                    }
                    ctx.move(to: CGPoint(x: 30, y: 30)); ctx.addLine(to: CGPoint(x: 16, y: 36)); ctx.strokePath()
                    wings(span: 22, at: CGPoint(x: 46, y: 26))
                }
            }
        }
    }

    private func updateFlyers(dt: Double, daylight: CGFloat) {
        guard !water else { return }
        flyerTimer -= dt
        guard flyerTimer <= 0 else { return }
        flyerTimer = rng.range(7, 15)
        guard daylight > 0.5 else { return }
        let kind = SkyDirector.flyer(for: realm.id)
        // Every few passes, the realm's own creature; otherwise a small flock.
        let chosen: Flyer = rng.unit() < 0.45 ? kind : .flock
        let color = palette.skyTop.mixed(with: RGBA(r: 0, g: 0, b: 0), 0.55)
        let frames = flyerFrames(chosen, color: color)
        let n = SKSpriteNode(texture: frames[0])
        let big = chosen == .pegasus || chosen == .raptor || chosen == .longTail
        n.setScale(big ? CGFloat(rng.range(0.8, 1.1)) : CGFloat(rng.range(0.5, 0.75)))
        n.zPosition = 4
        let y = size.height * CGFloat(rng.range(0.12, 0.36))
        n.position = CGPoint(x: size.width / 2 + 80, y: y)
        n.run(.repeatForever(.animate(with: frames, timePerFrame: big ? 0.35 : 0.18)))
        let duration = rng.range(10, 16)
        n.run(.sequence([.group([.moveTo(x: -size.width / 2 - 100, duration: duration),
                                 .sequence([.moveBy(x: 0, y: 14, duration: duration / 2), .moveBy(x: 0, y: -10, duration: duration / 2)])]),
                         .removeFromParent()]))
        skyLayer.addChild(n)
    }

    // MARK: Weather

    private func weatherChoices(night: CGFloat) -> [Weather] {
        switch realm.scenery.resolvedBiome {
        case .forest: return night > 0.5 ? [.fireflies, .mist] : [.rain, .mist, .leaves]
        case .jungle: return night > 0.5 ? [.fireflies, .rain] : [.rain, .mist]
        case .mountain: return [.snow, .mist]
        case .desert: return [.sand]
        case .savanna: return [.rain, .sand]
        case .steppe: return [.snow, .sand]
        case .tundra: return [.snow]
        case .coast: return [.rain, .mist]
        case .market: return [.rain, .leaves]
        case .farmland: return [.rain, .mist]
        case .volcanic: return [.embers, .rain]
        }
    }

    private func updateWeather(dt: Double, night: CGFloat) {
        guard !water else { return }
        if raining {
            lightningTimer -= dt
            if lightningTimer <= 0 {
                lightningTimer = rng.range(4, 9)
                flash.removeAllActions()
                flash.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.05), .fadeOut(withDuration: 0.2),
                                     .fadeAlpha(to: 0.2, duration: 0.05), .fadeOut(withDuration: 0.3)]))
            }
        }
        weatherTimer -= dt
        guard weatherTimer <= 0 else { return }
        if let w = weather {
            // End the current spell of weather: stop emitting and let the last particles fall.
            weather = nil
            raining = false
            w.particleBirthRate = 0
            w.run(.sequence([.wait(forDuration: 6), .removeFromParent()]))
            weatherTimer = rng.range(14, 28)
            return
        }
        let options = weatherChoices(night: night)
        let kind = options[Int(rng.next() % UInt64(options.count))]
        guard let e = WeatherFactory.make(kind, palette: palette, dot: dot, width: size.width, height: size.height,
                                          scale: particleScale) else { return }
        let rate = e.particleBirthRate
        e.particleBirthRate = 0
        e.zPosition = 21
        e.targetNode = cam.parent
        cam.addChild(e)
        e.run(.customAction(withDuration: 2.5) { node, t in
            (node as? SKEmitterNode)?.particleBirthRate = rate * t / 2.5
        })
        weather = e
        raining = kind == .rain
        weatherTimer = rng.range(9, 16)
    }
}
