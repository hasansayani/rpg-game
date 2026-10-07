import SpriteKit
import UIKit

/// Renders a RunSession. All game rules live in Core/RunSession; this class only draws,
/// plays feedback, and forwards touches — which keeps a Godot port mechanical.
final class GameScene: SKScene {
    struct Setup {
        var realm: Realm
        var totalRealms: Int
        var tuning: AgeTuning
        var mode: GuardianMode
        var companion: CompanionScript
        var haptics: Bool
        /// A fresh random layout for every run (terrain, hazards, scenery).
        var variation: UInt64 = .random(in: 1...UInt64.max)
    }

    var onFinish: ((RunResult) -> Void)?
    var onPause: (() -> Void)?

    let setup: Setup
    let session: RunSession
    private let palette: ResolvedPalette

    // Layers
    private let cam = SKCameraNode()
    private let world = SKNode()
    private let skyLayer = SKNode()
    private var parallax: [(node: SKNode, sprites: [SKSpriteNode], factor: CGFloat, yFactor: CGFloat, baseY: CGFloat)] = []
    private let hud = SKNode()

    // Actors
    private var player: PlayerNode!
    private var lumi: CompanionNode!
    private var bubble: SpeechBubble!
    private var guardianNode: GuardianNode!
    private var relicNodes: [SKSpriteNode] = []
    private var projectileNodes: [Int: SKSpriteNode] = [:]
    private var warningNodes: [Int: SKSpriteNode] = [:]
    private var weakPointNode: SKSpriteNode!
    private var moteNodes: [SKSpriteNode] = []
    private var gateNodes: [SKSpriteNode] = []
    private var springNodes: [SKSpriteNode] = []
    private var checkpointNodes: [SKNode] = []

    // Terrain chunks (generated lazily, recycled)
    private let chunkWidth: CGFloat = 600
    private var chunks: [Int: SKSpriteNode] = [:]

    // HUD
    private var checkpointLabel: SKLabelNode!
    /// Full-screen fade used between a failure and the respawn.
    private var fade: SKSpriteNode!
    private var progressFill: SKSpriteNode!
    private var progressTrack: SKShapeNode!
    private var relicLabel: SKLabelNode!
    private var pauseButton: SKShapeNode!
    private var banner: SKNode!
    private var vignette: SKSpriteNode?

    // Cached textures
    private var dot: SKTexture!
    private var lowTex: SKTexture!
    private var highTex: SKTexture!
    private var warnTex: SKTexture!

    private var events = SessionEvents()
    private var lastTime: TimeInterval = 0
    private var finishTimer: Double?
    private var built = false
    private let haptics = Haptics()

    init(size: CGSize, setup: Setup) {
        self.setup = setup
        session = RunSession(realm: setup.realm, totalRealms: setup.totalRealms, tuning: setup.tuning,
                             mode: setup.mode, companion: setup.companion, variation: setup.variation)
        palette = ResolvedPalette(palette: setup.realm.palette, guardianHex: setup.realm.guardian.color,
                                  tuning: setup.tuning)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = palette.skyBottom.skColor
        haptics.enabled = setup.haptics
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Build

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        view.ignoresSiblingOrder = true

        dot = TextureFactory.softDot()
        lowTex = TextureFactory.projectile(color: palette.guardian.lighter(0.1), high: false)
        highTex = TextureFactory.projectile(color: palette.accent, high: true)
        warnTex = TextureFactory.warningMarker(color: palette.accent)

        addChild(cam)
        camera = cam
        addChild(world)
        cam.addChild(skyLayer)
        cam.addChild(hud)
        skyLayer.zPosition = -100
        hud.zPosition = 100

        buildSky()
        buildParallax()
        buildActors()
        buildHUD()
        layout()

        cam.position = CGPoint(x: CGFloat(session.runner.x) + size.width * 0.18, y: max(CGFloat(session.runner.y) + 40, size.height / 2))
        updateChunks()
        showBanner(title: setup.realm.name,
                   subtitle: "\(setup.realm.culture) · \(setup.realm.place) · \(setup.realm.era)", hold: 2.8)
    }

    private func buildSky() {
        let sky = SKSpriteNode(texture: TextureFactory.skyGradient(top: palette.skyTop, bottom: palette.skyBottom))
        sky.name = "sky"
        skyLayer.addChild(sky)

        // Sun or moon, with a soft halo.
        let halo = SKSpriteNode(texture: dot)
        halo.color = palette.accent.lighter(0.4).skColor
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        halo.alpha = 0.6
        halo.name = "halo"
        skyLayer.addChild(halo)
        let sun = SKSpriteNode(texture: TextureFactory.disc(diameter: 64, color: palette.skyBottom.lighter(0.65)))
        sun.name = "sun"
        skyLayer.addChild(sun)

        if setup.realm.scenery.weather == .aurora {
            for i in 0..<3 {
                let band = SKSpriteNode(texture: dot)
                band.color = (i == 1 ? RGBA(hex: "#B388FF") : palette.accent).skColor
                band.colorBlendFactor = 1
                band.blendMode = .add
                band.alpha = 0.22
                band.name = "aurora\(i)"
                band.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 2 + Double(i)),
                                                   .fadeAlpha(to: 0.12, duration: 2 + Double(i))])))
                skyLayer.addChild(band)
            }
        }
    }

    private func buildParallax() {
        let s = setup.realm.scenery
        let seed = setup.realm.seed ^ setup.variation
        let layers: [(SceneryPainter.Depth, RGBA, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            // depth, color, texture height, x factor, y factor, base y (fraction of screen from bottom)
            (.far, palette.far, 300, 0.08, 0.05, 0.10),
            (.mid, palette.mid, 240, 0.22, 0.12, 0.02),
            (.near, palette.near, 200, 0.45, 0.25, -0.10),
        ]
        for (i, l) in layers.enumerated() {
            let tex = SceneryPainter.layer(scenery: s, depth: l.0, color: l.1, height: l.2, seed: seed &+ UInt64(i))
            let node = SKNode()
            node.zPosition = -90 + CGFloat(i) * 5
            var sprites: [SKSpriteNode] = []
            for j in 0..<3 {
                let sp = SKSpriteNode(texture: tex)
                sp.anchorPoint = CGPoint(x: 0, y: 0)
                sp.position.x = CGFloat(j) * SceneryPainter.tileWidth
                node.addChild(sp)
                sprites.append(sp)
            }
            cam.addChild(node)
            parallax.append((node: node, sprites: sprites, factor: l.3, yFactor: l.4, baseY: l.5))

            // Atmospheric fog in front of each distant layer (stronger for older players).
            if i < 2 {
                let fog = SKSpriteNode(texture: TextureFactory.verticalFade(color: palette.skyBottom, topAlpha: 0,
                                                                             bottomAlpha: setup.tuning.fogStrength + 0.25))
                fog.anchorPoint = CGPoint(x: 0.5, y: 0)
                fog.zPosition = node.zPosition + 2
                fog.name = "fog\(i)"
                cam.addChild(fog)
            }
        }
    }

    private func buildActors() {
        // Obstacles (static; created once).
        let rockTex = TextureFactory.rock(color: palette.near.mixed(with: palette.groundEdge, 0.35))
        let water = session.course.isWater
        // Obstacles come from the culture's world (jars, rune stones, lanterns…), varied per position.
        let propTex = (setup.realm.scenery.props ?? []).map {
            TextureFactory.prop($0, tint: palette.near, accent: palette.accent, motif: setup.realm.motif)
        }
        let coralTex = water ? (0..<3).map { TextureFactory.coral(color: [palette.accent, RGBA(hex: "#FF6F91"), palette.mid][$0], seed: $0) } : []
        for (i, o) in session.course.obstacles.enumerated() {
            let rock = SKSpriteNode(texture: water ? coralTex[i % 3] : propTex.isEmpty ? rockTex : propTex[Int(o.x) % propTex.count])
            rock.anchorPoint = CGPoint(x: 0.5, y: 0)
            rock.size = CGSize(width: o.width + 8, height: o.height + 6)
            rock.position = CGPoint(x: o.x, y: session.course.surface(at: o.x) - 6)
            rock.zPosition = 5
            world.addChild(rock)
        }
        if !water { buildPathScenery() }
        if water {
            buildWater()
            // No sun or aurora underwater: the light comes down in shafts instead.
            for name in ["sun", "halo", "aurora0", "aurora1", "aurora2"] { skyLayer.childNode(withName: name)?.isHidden = true }
        }

        let relicTex = TextureFactory.relic(color: palette.accent)
        for r in session.course.relics {
            let node = SKSpriteNode(texture: relicTex)
            node.position = CGPoint(x: r.x, y: session.course.surface(at: r.x) + r.lift)
            node.zPosition = 6
            node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 0.7), .moveBy(x: 0, y: -8, duration: 0.7)])))
            node.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.5), .scale(to: 1, duration: 0.5)])))
            world.addChild(node)
            relicNodes.append(node)
        }

        buildInteractables()

        player = PlayerNode(look: RunnerLook(cloak: RGBA(hex: "#2B2D42"), trim: palette.accent.lighter(0.15),
                                             motif: setup.realm.motif),
                            accent: palette.accent, dustColor: palette.ground.mixed(with: palette.groundEdge, 0.5), spark: dot)
        player.zPosition = 10
        player.setTrailTarget(world)
        world.addChild(player)

        lumi = CompanionNode(dot: dot, color: palette.accent.lighter(0.3))
        lumi.zPosition = 12
        lumi.position = CGPoint(x: session.runner.x, y: session.runner.y + 90)
        world.addChild(lumi)

        guardianNode = GuardianNode(realm: setup.realm, color: palette.guardian,
                                    eye: palette.accent, cute: setup.tuning.cuteGuardians, dot: dot)
        guardianNode.zPosition = 8
        guardianNode.alpha = 0
        guardianNode.isHidden = true
        world.addChild(guardianNode)

        weakPointNode = SKSpriteNode(texture: dot)
        weakPointNode.color = palette.accent.skColor
        weakPointNode.colorBlendFactor = 1
        weakPointNode.blendMode = .add
        weakPointNode.size = CGSize(width: 70, height: 70)
        weakPointNode.zPosition = 9
        weakPointNode.isHidden = true
        weakPointNode.run(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.3), .scale(to: 0.9, duration: 0.3)])))
        world.addChild(weakPointNode)

        if !session.course.isWater, let weather = WeatherFactory.make(setup.realm.scenery.weather, palette: palette, dot: dot,
                                             width: size.width, height: size.height,
                                             scale: setup.tuning.particleScale) {
            weather.targetNode = world
            weather.zPosition = 20
            weather.name = "weather"
            cam.addChild(weather)
            weather.advanceSimulationTime(5)
        }
    }

    // MARK: Path scenery

    /// The realm's landmarks (palms, pines, torii, yurts, granaries…) standing along the path behind
    /// the runner, at random spacing that changes every run. Purely decorative: nothing collides.
    private func buildPathScenery() {
        let course = session.course
        let kinds = setup.realm.scenery.landmarks
        guard !kinds.isEmpty else { return }
        let color = palette.near.mixed(with: palette.mid, 0.35)
        let textures = kinds.map { kind in
            TextureFactory.image(size: CGSize(width: 160, height: 110)) { ctx in
                LandmarkPainter.draw(kind, ctx: ctx, at: CGPoint(x: 80, y: 106), scale: 1, color: color)
            }
        }
        var rng = SeededRandom(seed: setup.realm.seed ^ setup.variation ^ 0xD1CE)
        var x = 420.0
        let end = course.runLength + 4000
        while x < end {
            x += rng.range(260, 720)
            guard course.gap(at: x) == nil, course.gap(at: x - 60) == nil, course.gap(at: x + 60) == nil else { continue }
            let n = SKSpriteNode(texture: textures[Int(rng.next() % UInt64(textures.count))])
            n.anchorPoint = CGPoint(x: 0.5, y: 4 / 110)
            n.setScale(CGFloat(rng.range(0.55, 0.95)))
            n.position = CGPoint(x: x, y: CGFloat(course.surface(at: x)) - 10)
            n.zPosition = 3
            n.alpha = 0.9
            world.addChild(n)
        }
    }

    // MARK: Water realms

    private var waterTint: SKSpriteNode?
    private var waterSurfaceTiles: [SKSpriteNode] = []
    private var lightShafts: [SKSpriteNode] = []

    /// Underwater look: a tint over everything below the surface, the surface (sea ice or ripples)
    /// seen from below, swaying light shafts, rising bubbles, and things hanging from the surface.
    private func buildWater() {
        let course = session.course
        let ice = setup.realm.scenery.far == .icebergs

        let tint = SKSpriteNode(texture: TextureFactory.verticalFade(color: palette.near.darker(0.3), topAlpha: 0.25, bottomAlpha: 0.6))
        tint.anchorPoint = CGPoint(x: 0.5, y: 1)
        tint.zPosition = 15
        cam.addChild(tint)
        waterTint = tint

        let surfaceTex = TextureFactory.waterSurface(ice: ice, tint: palette.skyBottom)
        for _ in 0..<8 {
            let s = SKSpriteNode(texture: surfaceTex)
            s.anchorPoint = CGPoint(x: 0, y: 0)
            s.zPosition = 16
            cam.addChild(s)
            waterSurfaceTiles.append(s)
        }

        let shaftTex = TextureFactory.lightShaft()
        for k in 0..<4 {
            let s = SKSpriteNode(texture: shaftTex)
            s.anchorPoint = CGPoint(x: 0.5, y: 1)
            s.blendMode = .add
            s.alpha = 0.35
            s.zPosition = 14
            s.run(.repeatForever(.sequence([.rotate(toAngle: 0.08, duration: 2.5 + Double(k) * 0.4),
                                            .rotate(toAngle: -0.08, duration: 2.5 + Double(k) * 0.4)])))
            cam.addChild(s)
            lightShafts.append(s)
        }

        let bubbles = SKEmitterNode()
        bubbles.particleTexture = TextureFactory.image(size: CGSize(width: 16, height: 16)) { ctx in
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: CGRect(x: 2, y: 2, width: 12, height: 12))
        }
        bubbles.particleBirthRate = 10 * CGFloat(setup.tuning.particleScale)
        bubbles.particleLifetime = 6
        bubbles.particlePositionRange = CGVector(dx: size.width * 1.4, dy: 10)
        bubbles.position = CGPoint(x: size.width * 0.2, y: -size.height / 2)
        bubbles.emissionAngle = .pi / 2
        bubbles.emissionAngleRange = 0.3
        bubbles.particleSpeed = 60
        bubbles.particleSpeedRange = 30
        bubbles.particleScale = 0.6
        bubbles.particleScaleRange = 0.4
        bubbles.particleAlpha = 0.8
        bubbles.xAcceleration = -10
        bubbles.targetNode = world
        bubbles.zPosition = 20
        bubbles.name = "weather"
        cam.addChild(bubbles)
        bubbles.advanceSimulationTime(5)

        // Hanging hazards: icicles under sea ice, drifting jellyfish in open sea.
        let hangTex = ice ? TextureFactory.icicle() : TextureFactory.jellyfish(color: palette.accent.mixed(with: RGBA(hex: "#C77DFF"), 0.5))
        for h in course.hangers {
            let n = SKSpriteNode(texture: hangTex)
            n.anchorPoint = CGPoint(x: 0.5, y: 1)
            n.size = CGSize(width: h.width + 6, height: h.length + 4)
            n.position = CGPoint(x: h.x, y: course.waterSurface + 2)
            n.zPosition = 5
            if !ice {
                n.run(.repeatForever(.sequence([.scaleY(to: 0.92, duration: 0.7), .scaleY(to: 1.0, duration: 0.7)])))
            }
            world.addChild(n)
        }
    }

    private func updateWater(time: TimeInterval) {
        guard let tint = waterTint else { return }
        // Screen-space y of the water surface (camera children are centered on the screen).
        let surfaceY = CGFloat(session.course.waterSurface) - cam.position.y
        tint.size = CGSize(width: size.width + 4, height: max(surfaceY + size.height / 2, 0) + 4)
        tint.position = CGPoint(x: 0, y: surfaceY)
        let tile: CGFloat = 256
        let offset = cam.position.x.truncatingRemainder(dividingBy: tile)
        for (i, s) in waterSurfaceTiles.enumerated() {
            s.position = CGPoint(x: -size.width / 2 - offset + CGFloat(i) * tile - tile, y: surfaceY - 6)
        }
        for (i, s) in lightShafts.enumerated() {
            let x = (CGFloat(i) * 260 - cam.position.x * 0.3).truncatingRemainder(dividingBy: size.width + 300)
            s.position = CGPoint(x: (x < -size.width / 2 - 150 ? x + size.width + 300 : x), y: surfaceY)
        }
    }

    private func buildHUD() {
        checkpointLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        checkpointLabel.fontSize = 16
        checkpointLabel.fontColor = .white
        checkpointLabel.horizontalAlignmentMode = .left
        checkpointLabel.verticalAlignmentMode = .center
        hud.addChild(checkpointLabel)

        fade = SKSpriteNode(color: .black, size: CGSize(width: 10, height: 10))
        fade.alpha = 0
        fade.zPosition = 50
        hud.addChild(fade)

        progressTrack = SKShapeNode(rectOf: CGSize(width: 220, height: 10), cornerRadius: 5)
        progressTrack.fillColor = UIColor(white: 0, alpha: 0.25)
        progressTrack.strokeColor = UIColor(white: 1, alpha: 0.6)
        progressTrack.lineWidth = 1.5
        hud.addChild(progressTrack)
        progressFill = SKSpriteNode(color: palette.accent.skColor, size: CGSize(width: 216, height: 6))
        progressFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hud.addChild(progressFill)

        relicLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        relicLabel.fontSize = 16
        relicLabel.fontColor = .white
        relicLabel.horizontalAlignmentMode = .left
        relicLabel.verticalAlignmentMode = .center
        hud.addChild(relicLabel)

        pauseButton = SKShapeNode(circleOfRadius: 20)
        pauseButton.fillColor = UIColor(white: 0, alpha: 0.25)
        pauseButton.strokeColor = UIColor(white: 1, alpha: 0.8)
        pauseButton.lineWidth = 2
        pauseButton.name = "pause"
        for dx in [-5, 5] as [CGFloat] {
            let bar = SKSpriteNode(color: .white, size: CGSize(width: 4, height: 14))
            bar.position.x = dx
            pauseButton.addChild(bar)
        }
        hud.addChild(pauseButton)

        bubble = SpeechBubble(name: setup.companion.name, fill: RGBA(r: 1, g: 1, b: 1),
                              accent: palette.accent.darker(0.15), textScale: CGFloat(setup.tuning.textScale))
        hud.addChild(bubble)

        banner = SKNode()
        hud.addChild(banner)

        if setup.tuning.vignette > 0 {
            let v = SKSpriteNode(texture: TextureFactory.vignette(size: CGSize(width: 256, height: 256)))
            v.alpha = CGFloat(setup.tuning.vignette)
            v.zPosition = -1
            hud.addChild(v)
            vignette = v
        }
        updateHUD()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if built { layout() }
    }

    /// Positions everything that is attached to the camera (screen space, origin at screen center).
    private func layout() {
        let w = size.width, h = size.height
        let safe = view?.safeAreaInsets ?? .zero
        let left = -w / 2 + max(safe.left, 16) + 8, top = h / 2 - max(safe.top, 12) - 16
        let right = w / 2 - max(safe.right, 16) - 8

        if let sky = skyLayer.childNode(withName: "sky") as? SKSpriteNode { sky.size = CGSize(width: w + 4, height: h + 4) }
        if let sun = skyLayer.childNode(withName: "sun") { sun.position = CGPoint(x: w * 0.28, y: h * 0.22) }
        if let halo = skyLayer.childNode(withName: "halo") as? SKSpriteNode {
            halo.position = CGPoint(x: w * 0.28, y: h * 0.22)
            halo.size = CGSize(width: 260, height: 260)
        }
        for i in 0..<3 {
            if let band = skyLayer.childNode(withName: "aurora\(i)") as? SKSpriteNode {
                band.size = CGSize(width: w * 1.3, height: h * 0.35)
                band.position = CGPoint(x: CGFloat(i - 1) * w * 0.2, y: h * 0.25 - CGFloat(i) * 18)
            }
        }
        for (i, layer) in parallax.enumerated() {
            layer.node.position.y = -h / 2 + h * layer.baseY
            if let fog = cam.childNode(withName: "fog\(i)") as? SKSpriteNode {
                fog.size = CGSize(width: w + 4, height: h * 0.45)
                fog.position = CGPoint(x: 0, y: layer.node.position.y)
            }
        }
        if let weather = cam.childNode(withName: "weather") as? SKEmitterNode {
            weather.particlePositionRange.dx = max(weather.particlePositionRange.dx, w * 1.4)
        }

        checkpointLabel.position = CGPoint(x: left, y: top)
        fade.size = CGSize(width: w + 4, height: h + 4)
        relicLabel.position = CGPoint(x: left, y: top - 30)
        progressTrack.position = CGPoint(x: 0, y: top)
        progressFill.position = CGPoint(x: -108, y: top)
        pauseButton.position = CGPoint(x: right - 12, y: top - 4)
        bubble.position = CGPoint(x: 0, y: top - 26)
        banner.position = CGPoint(x: 0, y: h * 0.12)
        vignette?.size = CGSize(width: w, height: h)
    }

    // MARK: Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: hud)
        if pauseButton.contains(p) {
            onPause?()
            return
        }
        session.press()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { session.release() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { session.release() }

    /// Called when resuming from the SwiftUI pause menu so the long pause isn't simulated.
    func resetClock() { lastTime = 0 }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : min(currentTime - lastTime, 1.0 / 20)
        lastTime = currentTime

        events.clear()
        session.advance(dt, into: &events)
        handle(events, time: currentTime)

        let runner = session.runner
        player.update(runner: runner, time: currentTime)
        lumi.follow(player.position, time: currentTime, dt: CGFloat(dt))
        updateCamera(dt: CGFloat(dt))
        updateParallax()
        updateWater(time: currentTime)
        updateChunks()
        updateGuardian(time: currentTime)
        updateHUD()

        if let t = finishTimer {
            finishTimer = t - dt
            if t - dt <= 0 {
                finishTimer = nil
                onFinish?(session.result)
            }
        }
    }

    private func buildInteractables() {
        let course = session.course

        // Motes: tiny additive glows. Static, so hundreds of them cost almost nothing.
        let moteColor = palette.accent.lighter(0.35).skColor
        for (i, m) in course.motes.enumerated() {
            let n = SKSpriteNode(texture: dot)
            n.color = moteColor
            n.colorBlendFactor = 1
            n.blendMode = .add
            n.size = CGSize(width: 18, height: 18)
            n.position = CGPoint(x: m.x, y: course.surface(at: m.x) + m.lift)
            n.zPosition = 6
            // Stagger the shimmer along each trail.
            n.run(.sequence([.wait(forDuration: Double(i % 5) * 0.12),
                             .repeatForever(.sequence([.scale(to: 1.3, duration: 0.45), .scale(to: 0.85, duration: 0.45)]))]))
            world.addChild(n)
            moteNodes.append(n)
        }

        let gateTex = TextureFactory.spiritGate(color: palette.accent)
        for g in course.gates {
            let n = SKSpriteNode(texture: gateTex)
            n.position = CGPoint(x: g.x, y: course.surface(at: g.x) + g.lift)
            n.zPosition = 6
            n.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.9), .moveBy(x: 0, y: -6, duration: 0.9)])))
            world.addChild(n)
            gateNodes.append(n)
        }

        let springTex = TextureFactory.springboard(wood: palette.near.mixed(with: palette.groundEdge, 0.4), glow: palette.accent)
        for sb in course.springboards {
            let n = SKSpriteNode(texture: springTex)
            n.anchorPoint = CGPoint(x: 0.5, y: 0)
            // Sit the ramp's tall end on the springboard x and follow the local slope.
            n.position = CGPoint(x: sb.x - 10, y: course.surface(at: sb.x - 10) - 4)
            n.zRotation = CGFloat(atan(course.slope(at: sb.x)))
            n.zPosition = 5
            // A pulsing glow so it reads as "ride over me", not as a rock.
            let glow = SKSpriteNode(texture: dot)
            glow.color = palette.accent.skColor
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.size = CGSize(width: 90, height: 60)
            glow.position = CGPoint(x: 6, y: 16)
            glow.zPosition = -0.1
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.45), .fadeAlpha(to: 0.9, duration: 0.45)])))
            n.addChild(glow)
            world.addChild(n)
            springNodes.append(n)
        }

        let litTex = TextureFactory.shrine(stone: palette.near.lighter(0.2), flame: palette.accent.lighter(0.2))
        let unlitTex = TextureFactory.shrine(stone: palette.near.lighter(0.2), flame: RGBA(r: 0.35, g: 0.35, b: 0.4))
        let beamTex = TextureFactory.verticalFade(color: palette.accent.lighter(0.4), topAlpha: 0, bottomAlpha: 0.55)
        for cp in course.checkpoints {
            let node = SKNode()
            node.position = CGPoint(x: cp.x, y: course.surface(at: cp.x))
            node.zPosition = 6
            let beam = SKSpriteNode(texture: beamTex)
            beam.name = "beam"
            beam.anchorPoint = CGPoint(x: 0.5, y: 0)
            beam.size = CGSize(width: 34, height: 220)
            beam.blendMode = .add
            beam.alpha = 0
            node.addChild(beam)
            let shrine = SKSpriteNode(texture: unlitTex)
            shrine.name = "shrine"
            shrine.userData = ["lit": litTex]
            shrine.anchorPoint = CGPoint(x: 0.5, y: 0)
            shrine.position = CGPoint(x: 0, y: -4)
            node.addChild(shrine)
            world.addChild(node)
            checkpointNodes.append(node)
        }
    }

    private func handlePickups(_ pickups: [Pickup]) {
        for p in pickups {
            switch p {
            case .mote(let i):
                let n = moteNodes[i]
                n.removeAllActions()
                n.run(.sequence([.group([.scale(to: 2.4, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
            case .gate(let i):
                let n = gateNodes[i]
                n.removeAllActions()
                n.run(.sequence([.group([.scale(to: 1.6, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
                haptics.success()
                popText("BOOST!", at: n.position)
            case .springboard(let i):
                let n = springNodes[i]
                n.run(.sequence([.scaleY(to: 0.6, duration: 0.06), .scaleY(to: 1.15, duration: 0.1), .scaleY(to: 1, duration: 0.12)]))
                haptics.heavy()
            case .checkpoint(let i):
                let n = checkpointNodes[i]
                if let shrine = n.childNode(withName: "shrine") as? SKSpriteNode,
                   let lit = shrine.userData?["lit"] as? SKTexture {
                    shrine.texture = lit
                    shrine.run(.sequence([.scale(to: 1.25, duration: 0.12), .scale(to: 1, duration: 0.2)]))
                }
                n.childNode(withName: "beam")?.run(.sequence([
                    .fadeAlpha(to: 1, duration: 0.25),
                    .repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.8), .fadeAlpha(to: 1, duration: 0.8)])),
                ]))
                haptics.success()
                lumi.ping()
                popText("CHECKPOINT", at: CGPoint(x: n.position.x, y: player.position.y))
            }
        }
    }

    private func handle(_ e: SessionEvents, time: TimeInterval) {
        handlePickups(e.pickups)
        if e.failed {
            // Dip to black, then come back at the checkpoint.
            fade.removeAllActions()
            fade.run(.sequence([.wait(forDuration: 0.35), .fadeAlpha(to: 0.85, duration: 0.45)]))
        }
        if e.respawned {
            fade.removeAllActions()
            fade.run(.fadeOut(withDuration: 0.4))
            // A restarted guardian encounter numbers its attacks from zero again.
            projectileNodes.values.forEach { $0.removeFromParent() }
            warningNodes.values.forEach { $0.removeFromParent() }
            projectileNodes.removeAll()
            warningNodes.removeAll()
            cam.position = CGPoint(x: CGFloat(session.runner.x) + size.width * 0.18, y: max(CGFloat(session.runner.y) + 50, size.height / 2))
        }
        for ev in e.runner {
            switch ev {
            case .jumped: haptics.light()
            case .impact(let v): player.didLand(impact: v)
            case .stumbled: player.didStumble()
            case .bounced: haptics.light(); popText("BOUNCE", at: player.position)
            case .launched: popText("LAUNCH!", at: player.position)
            case .landed(let flips) where flips > 0:
                haptics.success()
                popText(flips > 1 ? "\(flips)× FLIP!" : "FLIP!", at: player.position)
            case .crashed, .fellInGap, .hitObstacle, .hurt:
                haptics.heavy()
                shake()
            default: break
            }
        }
        for i in e.relicsCollected {
            let node = relicNodes[i]
            node.removeAllActions()
            node.run(.sequence([.group([.scale(to: 2.2, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
            haptics.success()
            lumi.ping()
        }
        for ev in e.guardian {
            switch ev {
            case .caught:
                guardianNode.roar()
            case .projectileHit(let id):
                guardianNode.roar()
                projectileNodes.removeValue(forKey: id)?.removeFromParent()
                warningNodes.removeValue(forKey: id)?.removeFromParent()
            case .weakPointBroken:
                haptics.success()
                shake()
                guardianNode.roar()
                popText("HIT!", at: weakPointNode.position)
            case .projectileGone(let id):
                projectileNodes.removeValue(forKey: id)?.removeFromParent()
                warningNodes.removeValue(forKey: id)?.removeFromParent()
            default: break
            }
        }
        if let line = e.companionLine {
            lumi.ping()
            bubble.show(line.text, maxWidth: min(size.width * 0.55, 460),
                        duration: CompanionDirector.duration(for: line.text, scale: setup.tuning.bubbleDurationScale))
        }
        if let phase = e.phaseChanged {
            switch phase {
            case .guardian:
                guardianNode.isHidden = false
                guardianNode.run(.fadeIn(withDuration: 0.6))
                guardianNode.roar()
                shake()
                haptics.heavy()
                showBanner(title: setup.realm.guardian.name.uppercased(),
                           subtitle: session.mode.title + " — " + session.mode.instruction.text(for: session.variant),
                           hold: 3.2)
            case .won:
                guardianNode.run(.sequence([.fadeOut(withDuration: 0.8), .hide()]))
                showBanner(title: "REALM COMPLETE", subtitle: setup.realm.name, hold: 2.5)
                haptics.success()
                finishTimer = 2.6
            case .run: break
            }
        }
    }

    // MARK: Camera, parallax, terrain

    private func updateCamera(dt: CGFloat) {
        let r = session.runner
        // Keep the rider left of center; in chase mode slide right so the pursuer is visible.
        let lead: CGFloat = session.phase == .guardian && session.mode == .chase ? -size.width * 0.08 : size.width * 0.18
        let targetX = CGFloat(r.x) + lead
        let targetY = max(CGFloat(r.y) + 50, size.height / 2)
        let k = min(1, dt * 6)
        cam.position.x += (targetX - cam.position.x) * min(1, dt * 10)
        cam.position.y += (targetY - cam.position.y) * k
    }

    private func updateParallax() {
        let tile = SceneryPainter.tileWidth
        for layer in parallax {
            let offset = (cam.position.x * layer.factor).truncatingRemainder(dividingBy: tile)
            layer.node.position.x = -size.width / 2 - offset
            layer.node.position.y = -size.height / 2 + size.height * layer.baseY
                - (cam.position.y - size.height / 2) * layer.yFactor
        }
    }

    private func updateChunks() {
        let left = cam.position.x - size.width / 2
        let right = cam.position.x + size.width / 2
        let first = Int(floor(left / chunkWidth)) - 1
        let last = Int(floor(right / chunkWidth)) + 1
        var created = 0
        for i in first...last where chunks[i] == nil && i >= -1 {
            // Spread texture generation: at most one new chunk per frame after the first frame.
            if created > 0 && lastTime != 0 { break }
            let height = CGFloat(session.course.maxSurface + 30)
            let tex = TextureFactory.terrainChunk(course: session.course, x0: Double(CGFloat(i) * chunkWidth),
                                                  width: chunkWidth + 2, height: height,
                                                  ground: palette.ground, edge: palette.groundEdge,
                                                  biome: setup.realm.scenery.resolvedBiome, accent: palette.accent)
            let sprite = SKSpriteNode(texture: tex)
            sprite.anchorPoint = .zero
            sprite.position = CGPoint(x: CGFloat(i) * chunkWidth, y: 0)
            sprite.zPosition = 4
            world.addChild(sprite)
            chunks[i] = sprite
            created += 1
        }
        for (i, node) in chunks where i < first - 1 {
            node.removeFromParent()
            chunks.removeValue(forKey: i)
        }
    }

    // MARK: Guardian

    private func updateGuardian(time: TimeInterval) {
        guard let g = session.guardian else { return }
        let r = session.runner
        let course = session.course
        let gx: CGFloat
        switch g.mode {
        case .chase: gx = CGFloat(g.chaserX)
        case .gauntlet: gx = CGFloat(r.x) + size.width * 0.4
        case .weakpoint: gx = CGFloat(g.weakPoint?.x ?? r.x + 700) + 120
        }
        let ground = CGFloat(course.surface(at: Double(gx)))
        // Underwater guardians swim mid-water rather than walking the seabed.
        let swimLift: CGFloat = course.isWater ? 70 : 0
        let gy = ground + guardianNode.hoverHeight + (g.mode == .chase ? 0 : 20) + swimLift
        guardianNode.position = CGPoint(x: gx, y: gy)
        guardianNode.xScale = g.mode == .chase ? 1 : -1  // face the player
        guardianNode.animate(time: time) { CGFloat(course.surface(at: Double($0))) + swimLift }

        // Weak point
        if let wp = g.weakPoint {
            weakPointNode.isHidden = false
            weakPointNode.position = CGPoint(x: wp.x, y: course.surface(at: wp.x) + wp.lift)
        } else {
            weakPointNode.isHidden = true
        }

        // Projectiles + warnings
        for p in g.projectiles {
            if p.warning > 0 {
                let warn = warningNodes[p.id] ?? {
                    let n = SKSpriteNode(texture: warnTex)
                    n.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.12), .fadeAlpha(to: 1, duration: 0.12)])))
                    hud.addChild(n)
                    warningNodes[p.id] = n
                    return n
                }()
                let worldY = CGFloat(course.surface(at: p.x) + p.lift)
                warn.position = CGPoint(x: size.width / 2 - 40, y: min(max(worldY - cam.position.y, -size.height / 2 + 30), size.height / 2 - 60))
            } else {
                warningNodes.removeValue(forKey: p.id)?.removeFromParent()
                let node = projectileNodes[p.id] ?? {
                    let n = SKSpriteNode(texture: p.kind == .low ? lowTex : highTex)
                    n.zPosition = 9
                    n.blendMode = p.kind == .high ? .add : .alpha
                    if p.kind == .low { n.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.6))) }
                    world.addChild(n)
                    projectileNodes[p.id] = n
                    return n
                }()
                node.position = CGPoint(x: p.x, y: course.surface(at: p.x) + p.lift)
            }
        }
    }

    // MARK: HUD & feedback

    private func updateHUD() {
        let reached = session.activeCheckpoint.map { $0 + 1 } ?? 0
        checkpointLabel.text = "⚑ \(reached)/\(session.course.checkpoints.count)"
        progressFill.xScale = CGFloat(session.progress)
        progressFill.color = (session.phase == .run ? palette.accent : RGBA(hex: "#FF4D6D")).skColor
        relicLabel.text = "◆ \(session.collected.count)/\(session.course.relics.count)"
    }

    private func showBanner(title: String, subtitle: String, hold: Double) {
        banner.removeAllChildren()
        banner.removeAllActions()
        let t = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        t.text = title
        t.fontSize = 34 * CGFloat(setup.tuning.textScale)
        t.fontColor = .white
        t.verticalAlignmentMode = .bottom
        let sub = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sub.text = subtitle
        sub.fontSize = 15 * CGFloat(setup.tuning.textScale)
        sub.fontColor = UIColor(white: 1, alpha: 0.92)
        sub.verticalAlignmentMode = .top
        sub.position.y = -6
        sub.numberOfLines = 2
        sub.preferredMaxLayoutWidth = size.width * 0.8
        for label in [t, sub] {
            let shadow = label.copy() as! SKLabelNode
            shadow.fontColor = UIColor(white: 0, alpha: 0.35)
            shadow.position = CGPoint(x: label.position.x + 2, y: label.position.y - 2)
            shadow.zPosition = -1
            banner.addChild(shadow)
            banner.addChild(label)
        }
        banner.alpha = 0
        banner.run(.sequence([.fadeIn(withDuration: 0.3), .wait(forDuration: hold), .fadeOut(withDuration: 0.5)]))
    }

    private func popText(_ text: String, at worldPoint: CGPoint) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        l.text = text
        l.fontSize = 22
        l.fontColor = palette.accent.lighter(0.2).skColor
        l.position = CGPoint(x: worldPoint.x, y: worldPoint.y + 70)
        l.zPosition = 30
        world.addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 40, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
    }

    private func shake() {
        guard setup.tuning.screenShake else { return }
        let amp: CGFloat = 7
        let moves = (0..<6).map { i -> SKAction in
            let s: CGFloat = i % 2 == 0 ? 1 : -1
            return .moveBy(x: s * amp * CGFloat(6 - i) / 6, y: -s * amp * 0.5, duration: 0.03)
        }
        world.removeAction(forKey: "shake")
        world.run(.sequence(moves + [.move(to: .zero, duration: 0.03)]), withKey: "shake")
    }
}

/// Thin wrapper so haptics can be toggled in Settings.
final class Haptics {
    var enabled = true
    private let lightGen = UIImpactFeedbackGenerator(style: .light)
    private let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private let notifyGen = UINotificationFeedbackGenerator()

    func light() { if enabled { lightGen.impactOccurred(intensity: 0.5) } }
    func heavy() { if enabled { heavyGen.impactOccurred() } }
    func success() { if enabled { notifyGen.notificationOccurred(.success) } }
}
