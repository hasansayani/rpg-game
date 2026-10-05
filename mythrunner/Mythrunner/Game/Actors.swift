import SpriteKit
import UIKit

// MARK: - Player

/// The Wayfarer on a sky-board, with a flowing scarf (Alto's signature silhouette cue).
final class PlayerNode: SKNode {
    private let sprite: SKSpriteNode
    private let scarf = SKShapeNode()
    private let boostTrail: SKEmitterNode
    private var scarfPoints: [CGPoint] = []

    init(body: RGBA, board: RGBA, scarfColor: RGBA, spark: SKTexture) {
        sprite = SKSpriteNode(texture: TextureFactory.rider(body: body, board: board))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.04)
        boostTrail = SKEmitterNode()
        super.init()

        scarf.strokeColor = scarfColor.skColor
        scarf.lineWidth = 4
        scarf.lineCap = .round
        scarf.lineJoin = .round
        scarf.zPosition = -1
        addChild(scarf)
        addChild(sprite)

        boostTrail.particleTexture = spark
        boostTrail.particleBirthRate = 0
        boostTrail.particleLifetime = 0.5
        boostTrail.particleSpeed = 20
        boostTrail.particleSpeedRange = 20
        boostTrail.emissionAngle = .pi
        boostTrail.particleAlpha = 0.9
        boostTrail.particleAlphaSpeed = -1.8
        boostTrail.particleScale = 0.18
        boostTrail.particleScaleSpeed = -0.3
        boostTrail.particleColor = board.lighter(0.4).skColor
        boostTrail.particleColorBlendFactor = 1
        boostTrail.particleBlendMode = .add
        boostTrail.position = CGPoint(x: -20, y: 4)
        addChild(boostTrail)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setTrailTarget(_ node: SKNode) { boostTrail.targetNode = node }

    func update(runner: RunnerSim, time: TimeInterval) {
        position = CGPoint(x: runner.x, y: runner.y)
        zRotation = CGFloat(runner.angle)
        let boosting = runner.boost > 20
        boostTrail.particleBirthRate = boosting ? CGFloat(40 + runner.boost * 0.6) : 0
        sprite.alpha = runner.invulnerable > 0 && Int(time * 12) % 2 == 0 ? 0.35 : 1

        // Scarf: a short trail of the neck position in local space, waving with speed.
        let neck = CGPoint(x: 0, y: 40)
        let speed = CGFloat(runner.effectiveSpeed)
        scarfPoints = (0..<6).map { i in
            let t = CGFloat(i)
            let wave = sin(CGFloat(time) * 14 - t * 0.9) * (2 + t * 0.9)
            return CGPoint(x: neck.x - t * (5 + speed * 0.012), y: neck.y - t * 1.2 + wave)
        }
        let path = CGMutablePath()
        path.addLines(between: scarfPoints)
        scarf.path = path
    }
}

// MARK: - Companion

/// Lumi: a Navi-style wisp that floats near the player and lights up when speaking.
final class CompanionNode: SKNode {
    private let glow: SKSpriteNode
    private let core: SKSpriteNode
    private var velocity = CGVector.zero

    init(dot: SKTexture, color: RGBA) {
        glow = SKSpriteNode(texture: dot)
        glow.color = color.skColor
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.size = CGSize(width: 46, height: 46)
        core = SKSpriteNode(texture: dot)
        core.size = CGSize(width: 14, height: 14)
        super.init()
        addChild(glow)
        addChild(core)
        glow.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.6), .scale(to: 0.9, duration: 0.6)])))
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Critically-damped follow so Lumi lags playfully behind the rider.
    func follow(_ target: CGPoint, time: TimeInterval, dt: CGFloat) {
        let bob = CGPoint(x: cos(CGFloat(time) * 1.7) * 10, y: sin(CGFloat(time) * 2.3) * 8)
        let goal = CGPoint(x: target.x - 34 + bob.x, y: target.y + 86 + bob.y)
        let k: CGFloat = 40, d: CGFloat = 12
        velocity.dx += ((goal.x - position.x) * k - velocity.dx * d) * dt
        velocity.dy += ((goal.y - position.y) * k - velocity.dy * d) * dt
        position.x += velocity.dx * dt
        position.y += velocity.dy * dt
    }

    func ping() {
        glow.run(.sequence([.scale(to: 1.9, duration: 0.12), .scale(to: 1.0, duration: 0.3)]))
    }
}

/// Screen-space speech bubble. Rebuilt only when a new line arrives (cheap).
final class SpeechBubble: SKNode {
    private let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let nameTag = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var background = SKShapeNode()
    private let fill: RGBA
    private let accent: RGBA
    private let textScale: CGFloat

    init(name: String, fill: RGBA, accent: RGBA, textScale: CGFloat) {
        self.fill = fill
        self.accent = accent
        self.textScale = textScale
        super.init()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.fontSize = 15 * textScale
        label.fontColor = fill.readableText.skColor
        nameTag.text = name.uppercased()
        nameTag.fontSize = 11 * textScale
        nameTag.fontColor = accent.skColor
        nameTag.horizontalAlignmentMode = .left
        nameTag.verticalAlignmentMode = .top
        addChild(background)
        addChild(nameTag)
        addChild(label)
        alpha = 0
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ text: String, maxWidth: CGFloat, duration: Double) {
        label.preferredMaxLayoutWidth = maxWidth
        label.text = text
        let pad: CGFloat = 12
        let textSize = label.frame.size
        let w = min(maxWidth, textSize.width) + pad * 2
        let h = textSize.height + nameTag.frame.height + pad * 2 + 4

        background.removeFromParent()
        background = SKShapeNode(rect: CGRect(x: -w / 2, y: -h, width: w, height: h), cornerRadius: 14)
        background.fillColor = fill.withAlpha(0.92).skColor
        background.strokeColor = accent.skColor
        background.lineWidth = 2
        insertChild(background, at: 0)
        nameTag.position = CGPoint(x: -w / 2 + pad, y: -pad + 2)
        label.position = CGPoint(x: -w / 2 + pad, y: -pad - nameTag.frame.height - 4)

        removeAllActions()
        setScale(0.92)
        run(.sequence([
            .group([.fadeIn(withDuration: 0.18), .scale(to: 1, duration: 0.18)]),
            .wait(forDuration: max(duration - 0.4, 0.5)),
            .fadeOut(withDuration: 0.22),
        ]))
    }
}

// MARK: - Weather

enum WeatherFactory {
    static func make(_ weather: Weather, palette: ResolvedPalette, dot: SKTexture, width: CGFloat,
                     height: CGFloat, scale: Double) -> SKEmitterNode? {
        let e = SKEmitterNode()
        e.particleTexture = dot
        e.particleColorBlendFactor = 1
        e.particlePositionRange = CGVector(dx: width * 1.4, dy: 10)
        e.position = CGPoint(x: width * 0.2, y: height / 2 + 20)
        e.emissionAngle = -.pi / 2
        e.particleLifetime = 6
        let s = CGFloat(scale)
        switch weather {
        case .none:
            return nil
        case .snow, .aurora:
            e.particleBirthRate = 40 * s
            e.particleSpeed = 50; e.particleSpeedRange = 30
            e.emissionAngleRange = 0.6
            e.particleScale = 0.1; e.particleScaleRange = 0.08
            e.particleColor = .white; e.particleAlpha = 0.85
            e.xAcceleration = -18
        case .sand:
            e.position = CGPoint(x: width * 0.7, y: 0)
            e.particlePositionRange = CGVector(dx: 10, dy: height)
            e.emissionAngle = .pi
            e.particleBirthRate = 70 * s
            e.particleSpeed = 260; e.particleSpeedRange = 80
            e.particleScale = 0.05; e.particleScaleRange = 0.04
            e.particleColor = palette.ground.lighter(0.2).skColor; e.particleAlpha = 0.5
            e.particleLifetime = 4
        case .leaves, .petals:
            e.particleBirthRate = 10 * s
            e.particleSpeed = 50; e.particleSpeedRange = 30
            e.emissionAngleRange = 1.0
            e.particleScale = 0.14; e.particleScaleRange = 0.06
            e.particleScaleSequence = nil
            e.particleRotationSpeed = 2.5; e.particleRotationRange = 6
            e.particleColor = weather == .petals ? RGBA(hex: "#FFC4D6").skColor : palette.mid.lighter(0.2).skColor
            e.particleAlpha = 0.95
            e.xAcceleration = -30
        case .rain:
            e.particleBirthRate = 140 * s
            e.particleSpeed = 700; e.particleSpeedRange = 100
            e.emissionAngle = -.pi / 2 - 0.25
            e.particleSize = CGSize(width: 2, height: 18); e.particleScale = 1
            e.particleColor = palette.skyBottom.lighter(0.5).skColor; e.particleAlpha = 0.45
            e.particleLifetime = 1.5
        case .mist:
            e.position = CGPoint(x: width * 0.7, y: -height * 0.15)
            e.particlePositionRange = CGVector(dx: 10, dy: height * 0.4)
            e.emissionAngle = .pi
            e.particleBirthRate = 2 * s
            e.particleSpeed = 40
            e.particleScale = 4; e.particleScaleRange = 2
            e.particleColor = .white; e.particleAlpha = 0.12; e.particleAlphaRange = 0.06
            e.particleLifetime = 18
        case .embers, .lanterns, .fireflies:
            e.position = CGPoint(x: width * 0.2, y: -height / 2)
            e.emissionAngle = .pi / 2
            e.emissionAngleRange = 0.8
            e.particleBirthRate = (weather == .lanterns ? 3 : 14) * s
            e.particleSpeed = weather == .embers ? 90 : 35; e.particleSpeedRange = 25
            e.particleScale = weather == .lanterns ? 0.35 : 0.1; e.particleScaleRange = 0.05
            e.particleColor = weather == .lanterns ? RGBA(hex: "#FF4D3D").skColor
                : weather == .embers ? RGBA(hex: "#FFB347").skColor : palette.accent.lighter(0.3).skColor
            e.particleAlpha = 0.9; e.particleAlphaRange = 0.3
            e.particleBlendMode = .add
            e.particleLifetime = weather == .lanterns ? 14 : 7
        }
        return e
    }
}
