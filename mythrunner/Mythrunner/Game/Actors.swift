import SpriteKit
import UIKit

// MARK: - Player

/// The Wayfarer on foot (or swimming). Picks an animation frame from the runner's state and rotates
/// the body about its center of mass, so flips and leans match the physics.
final class PlayerNode: SKNode {
    private let frames: RunnerFrames
    /// Pivot at the center of mass; the sprite hangs from it.
    private let bodyPivot = SKNode()
    private let sprite: SKSpriteNode
    private let boostTrail: SKEmitterNode
    private let dust: SKEmitterNode
    private var stride: CGFloat = 0
    private var lastTime: TimeInterval = 0
    private var landTimer: CGFloat = 0
    private var stumbleTimer: CGFloat = 0

    init(look: RunnerLook, accent: RGBA, dustColor: RGBA, spark: SKTexture) {
        frames = RunnerFrames(look: look)
        sprite = SKSpriteNode(texture: frames.run[0])
        // Anchor the sprite at its hip, which sits at the center of mass.
        sprite.anchorPoint = CGPoint(x: TextureFactory.runnerHip.x / TextureFactory.runnerCanvas.width,
                                     y: 1 - TextureFactory.runnerHip.y / TextureFactory.runnerCanvas.height)
        boostTrail = SKEmitterNode()
        dust = SKEmitterNode()
        super.init()
        bodyPivot.position = CGPoint(x: 0, y: 20)
        bodyPivot.addChild(sprite)
        addChild(bodyPivot)

        boostTrail.particleTexture = spark
        boostTrail.particleBirthRate = 0
        boostTrail.particleLifetime = 0.5
        boostTrail.particleSpeed = 20
        boostTrail.particleSpeedRange = 20
        boostTrail.emissionAngle = .pi
        boostTrail.particleAlpha = 0.9
        boostTrail.particleAlphaSpeed = -1.8
        boostTrail.particleScale = 0.16
        boostTrail.particleScaleSpeed = -0.3
        boostTrail.particleColor = accent.lighter(0.4).skColor
        boostTrail.particleColorBlendFactor = 1
        boostTrail.particleBlendMode = .add
        boostTrail.position = CGPoint(x: -12, y: 18)
        addChild(boostTrail)

        // Landing dust: a quick burst from the feet, scaled by impact speed.
        dust.particleTexture = spark
        dust.particleBirthRate = 0
        dust.numParticlesToEmit = 0
        dust.particleLifetime = 0.45
        dust.particleSpeed = 70
        dust.particleSpeedRange = 40
        dust.emissionAngle = .pi / 2
        dust.emissionAngleRange = 2.4
        dust.particleAlpha = 0.7
        dust.particleAlphaSpeed = -1.6
        dust.particleScale = 0.22
        dust.particleScaleSpeed = 0.3
        dust.particleColor = dustColor.skColor
        dust.particleColorBlendFactor = 1
        dust.yAcceleration = -120
        addChild(dust)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setTrailTarget(_ node: SKNode) {
        boostTrail.targetNode = node
        dust.targetNode = node
    }

    /// Called on landing; `impact` is the normal speed from the physics.
    func didLand(impact: Double) {
        landTimer = 0.12
        let strength = CGFloat(min(max((impact - 300) / 700, 0), 1))
        guard strength > 0 else { return }
        dust.resetSimulation()
        dust.particleBirthRate = 400
        dust.numParticlesToEmit = Int(6 + 18 * strength)
    }

    func didStumble() { stumbleTimer = 0.4 }

    func update(runner: RunnerSim, time: TimeInterval) {
        let dt = CGFloat(lastTime == 0 ? 1.0 / 60 : min(time - lastTime, 0.05))
        lastTime = time
        landTimer = max(0, landTimer - dt)
        stumbleTimer = max(0, stumbleTimer - dt)

        position = CGPoint(x: runner.x, y: runner.y)
        bodyPivot.zRotation = CGFloat(runner.angle)
        let speed = CGFloat(runner.effectiveSpeed)

        let texture: SKTexture
        if runner.swimming {
            bodyPivot.position = CGPoint(x: 0, y: 14)
            stride += dt * (runner.holding ? 14 : 8)
            texture = frames.swim[Int(stride) % frames.swim.count]
        } else {
            bodyPivot.position = CGPoint(x: 0, y: 20)
            if runner.failed || stumbleTimer > 0 {
                texture = frames.stumble
            } else if runner.grounded {
                if runner.crouchAmount > 0.05 {
                    texture = frames.crouch
                } else if landTimer > 0 {
                    texture = frames.land
                } else {
                    // Stride length ~70 pt: the cycle advances with distance, not time.
                    stride += speed * dt / 70 * CGFloat(frames.run.count)
                    texture = frames.run[Int(stride) % frames.run.count]
                }
            } else if runner.tucked {
                texture = frames.tuck
            } else {
                texture = runner.vy > 0 ? frames.jump : frames.fall
            }
        }
        if sprite.texture !== texture { sprite.texture = texture }

        let boosting = runner.boost > 20
        boostTrail.particleBirthRate = boosting ? CGFloat(40 + runner.boost * 0.6) : 0
        sprite.alpha = runner.invulnerable > 0 && Int(time * 12) % 2 == 0 ? 0.4 : 1
        if dust.numParticlesToEmit > 0, dust.particleBirthRate > 0, landTimer < 0.06 { dust.particleBirthRate = 0 }
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
