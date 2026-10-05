import SpriteKit
import UIKit

/// Procedural guardian visuals for the 7 shape archetypes. Built from a few cached textures and
/// animated with SKActions (no per-frame path rebuilding). `cute` adds big friendly eyes for young players.
final class GuardianNode: SKNode {
    let shape: GuardianShape
    private var segments: [SKSpriteNode] = []
    private let body = SKNode()
    private let color: RGBA
    private let eyeColor: RGBA
    private let cute: Bool

    init(shape: GuardianShape, color: RGBA, eye: RGBA, cute: Bool, dot: SKTexture) {
        self.shape = shape
        self.color = color
        self.eyeColor = eye
        self.cute = cute
        super.init()
        addChild(body)
        build(dot: dot)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Build

    private func build(dot: SKTexture) {
        switch shape {
        case .giant: buildGiant()
        case .serpent: buildSerpent()
        case .beast: buildBeast()
        case .bird: buildBird()
        case .wave: buildWave(dot: dot)
        case .storm: buildStorm(dot: dot)
        case .spirit: buildSpirit()
        }
    }

    private func sprite(_ size: CGSize, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5),
                        _ draw: @escaping (CGContext, CGSize) -> Void) -> SKSpriteNode {
        let tex = TextureFactory.image(size: size) { ctx in draw(ctx, size) }
        let s = SKSpriteNode(texture: tex)
        s.anchorPoint = anchor
        return s
    }

    private func drawEyes(_ ctx: CGContext, at points: [CGPoint], r: CGFloat) {
        for p in points {
            if cute {
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - r * 1.6, y: p.y - r * 1.6, width: r * 3.2, height: r * 3.2))
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - r * 0.4, y: p.y - r * 0.9, width: r * 1.6, height: r * 1.6))
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x + r * 0.3, y: p.y - r * 0.7, width: r * 0.5, height: r * 0.5))
            } else {
                TextureFactory.radialGradient(ctx, colors: [eyeColor.lighter(0.6), eyeColor, eyeColor.withAlpha(0)],
                                              center: p, radius: r * 1.8)
            }
        }
    }

    private func buildGiant() {
        let c = color, dark = color.darker(0.25)
        let torso = sprite(CGSize(width: 150, height: 200), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
            ctx.setFillColor(dark.cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 40, y: 130, width: 26, height: 70), cornerRadius: 10).cgPath)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 84, y: 130, width: 26, height: 70), cornerRadius: 10).cgPath)
            ctx.fillPath()
            ctx.setFillColor(c.cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 22, y: 48, width: 106, height: 96), cornerRadius: 30).cgPath)
            ctx.fillPath()
            ctx.fillEllipse(in: CGRect(x: 47, y: 0, width: 56, height: 58))
            ctx.setFillColor(c.lighter(0.2).cgColor)
            ctx.fill(CGRect(x: 34, y: 92, width: 82, height: 6))
            self.drawEyes(ctx, at: [CGPoint(x: 66, y: 26), CGPoint(x: 86, y: 26)], r: 5)
        }
        body.addChild(torso)
        for side in [-1.0, 1.0] as [CGFloat] {
            let arm = sprite(CGSize(width: 24, height: 90), anchor: CGPoint(x: 0.5, y: 0.92)) { ctx, s in
                ctx.setFillColor(c.darker(0.1).cgColor)
                ctx.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: s), cornerRadius: 12).cgPath)
                ctx.fillPath()
            }
            arm.position = CGPoint(x: side * 58, y: 150)
            arm.zPosition = side > 0 ? 1 : -1
            arm.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.5 * side, duration: 0.35), .rotate(toAngle: -0.5 * side, duration: 0.35),
            ])))
            body.addChild(arm)
        }
        body.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.18), .moveBy(x: 0, y: -6, duration: 0.18)])))
    }

    private func buildSerpent() {
        let c = color
        let segTex = TextureFactory.image(size: CGSize(width: 44, height: 44)) { ctx in
            ctx.setFillColor(c.cgColor)
            ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 40, height: 40))
            ctx.setFillColor(c.lighter(0.25).cgColor)
            ctx.fillEllipse(in: CGRect(x: 10, y: 22, width: 24, height: 16))
        }
        for i in 0..<14 {
            let s = SKSpriteNode(texture: segTex)
            s.setScale(1.0 - CGFloat(i) * 0.045)
            s.zPosition = -CGFloat(i)
            segments.append(s)
            body.addChild(s)
        }
        let head = sprite(CGSize(width: 80, height: 56)) { [self] ctx, s in
            ctx.setFillColor(c.cgColor)
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 0, y: 28))
            p.addQuadCurve(to: CGPoint(x: 80, y: 30), controlPoint: CGPoint(x: 40, y: -12))
            p.addQuadCurve(to: CGPoint(x: 0, y: 28), controlPoint: CGPoint(x: 40, y: 70))
            ctx.addPath(p.cgPath); ctx.fillPath()
            self.drawEyes(ctx, at: [CGPoint(x: 50, y: 22)], r: 5)
        }
        head.zPosition = 2
        segments.insert(head, at: 0)
        body.addChild(head)
    }

    private func buildBeast() {
        let c = color, dark = color.darker(0.25)
        for (i, x) in ([-44, -26, 30, 48] as [CGFloat]).enumerated() {
            let leg = sprite(CGSize(width: 18, height: 54), anchor: CGPoint(x: 0.5, y: 1)) { ctx, s in
                ctx.setFillColor(dark.cgColor)
                ctx.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: s), cornerRadius: 8).cgPath)
                ctx.fillPath()
            }
            leg.position = CGPoint(x: x, y: 58)
            let phase = i % 2 == 0 ? 0.45 : -0.45
            leg.zRotation = phase
            leg.run(.repeatForever(.sequence([.rotate(toAngle: -phase, duration: 0.18), .rotate(toAngle: phase, duration: 0.18)])))
            body.addChild(leg)
        }
        let torso = sprite(CGSize(width: 190, height: 100), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
            ctx.setFillColor(c.cgColor)
            ctx.fillEllipse(in: CGRect(x: 20, y: 26, width: 130, height: 56))
            // head + snout
            ctx.fillEllipse(in: CGRect(x: 126, y: 6, width: 52, height: 46))
            ctx.fill(CGRect(x: 160, y: 28, width: 30, height: 18))
            // ears
            ctx.move(to: CGPoint(x: 134, y: 14)); ctx.addLine(to: CGPoint(x: 140, y: 0)); ctx.addLine(to: CGPoint(x: 150, y: 10)); ctx.fillPath()
            // tail
            ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(9); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 26, y: 46)); ctx.addQuadCurve(to: CGPoint(x: 0, y: 20), control: CGPoint(x: 4, y: 50)); ctx.strokePath()
            self.drawEyes(ctx, at: [CGPoint(x: 160, y: 22)], r: 4.5)
        }
        torso.position = CGPoint(x: 0, y: 30)
        body.addChild(torso)
        body.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.18), .moveBy(x: 0, y: -5, duration: 0.18)])))
    }

    private func buildBird() {
        let c = color
        for side in [-1.0, 1.0] as [CGFloat] {
            let wing = sprite(CGSize(width: 130, height: 60), anchor: CGPoint(x: 0.5, y: 0.1)) { ctx, s in
                ctx.setFillColor(c.darker(side > 0 ? 0 : 0.2).cgColor)
                ctx.move(to: CGPoint(x: 0, y: 54))
                ctx.addQuadCurve(to: CGPoint(x: 130, y: 0), control: CGPoint(x: 40, y: 0))
                ctx.addQuadCurve(to: CGPoint(x: 0, y: 54), control: CGPoint(x: 80, y: 40))
                ctx.fillPath()
            }
            wing.position = CGPoint(x: -10, y: 20)
            wing.zPosition = side
            wing.run(.repeatForever(.sequence([.scaleY(to: -0.6, duration: 0.25), .scaleY(to: 1, duration: 0.25)])))
            body.addChild(wing)
        }
        let torso = sprite(CGSize(width: 110, height: 60)) { [self] ctx, s in
            ctx.setFillColor(c.cgColor)
            ctx.fillEllipse(in: CGRect(x: 10, y: 16, width: 76, height: 36))
            ctx.fillEllipse(in: CGRect(x: 66, y: 4, width: 34, height: 30))
            ctx.setFillColor(UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1).cgColor)
            ctx.move(to: CGPoint(x: 96, y: 14)); ctx.addLine(to: CGPoint(x: 110, y: 22)); ctx.addLine(to: CGPoint(x: 96, y: 26)); ctx.fillPath()
            ctx.setFillColor(c.darker(0.2).cgColor)
            ctx.move(to: CGPoint(x: 14, y: 30)); ctx.addLine(to: CGPoint(x: 0, y: 18)); ctx.addLine(to: CGPoint(x: 2, y: 46)); ctx.fillPath()
            self.drawEyes(ctx, at: [CGPoint(x: 86, y: 16)], r: 4)
        }
        body.addChild(torso)
        body.run(.repeatForever(.sequence([.moveBy(x: 0, y: 14, duration: 0.5), .moveBy(x: 0, y: -14, duration: 0.5)])))
    }

    private func buildWave(dot: SKTexture) {
        let c = color
        let wave = sprite(CGSize(width: 260, height: 240), anchor: CGPoint(x: 0.75, y: 0)) { [self] ctx, s in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 0, y: 240))
            p.addCurve(to: CGPoint(x: 200, y: 30), controlPoint1: CGPoint(x: 60, y: 200), controlPoint2: CGPoint(x: 90, y: 20))
            p.addQuadCurve(to: CGPoint(x: 230, y: 110), controlPoint: CGPoint(x: 270, y: 50))
            p.addQuadCurve(to: CGPoint(x: 260, y: 240), controlPoint: CGPoint(x: 200, y: 160))
            p.close()
            ctx.saveGState()
            ctx.addPath(p.cgPath); ctx.clip()
            TextureFactory.linearGradient(ctx, colors: [c.lighter(0.35), c, c.darker(0.3)],
                                          from: CGPoint(x: 0, y: 20), to: CGPoint(x: 0, y: 240))
            ctx.restoreGState()
            if self.cute { self.drawEyes(ctx, at: [CGPoint(x: 170, y: 90), CGPoint(x: 200, y: 92)], r: 6) }
        }
        body.addChild(wave)
        let foam = SKEmitterNode()
        foam.particleTexture = dot
        foam.particleBirthRate = 50
        foam.particleLifetime = 1.0
        foam.particlePositionRange = CGVector(dx: 30, dy: 150)
        foam.position = CGPoint(x: 40, y: 120)
        foam.emissionAngle = .pi / 3
        foam.particleSpeed = 120
        foam.particleScale = 0.2; foam.particleScaleSpeed = -0.2
        foam.particleColor = c.lighter(0.7).skColor; foam.particleColorBlendFactor = 1
        foam.particleAlphaSpeed = -1
        body.addChild(foam)
        body.run(.repeatForever(.sequence([.scaleY(to: 1.06, duration: 0.4), .scaleY(to: 0.96, duration: 0.4)])))
    }

    private func buildStorm(dot: SKTexture) {
        let c = color
        let spin = SKNode()
        for i in 0..<9 {
            let puff = SKSpriteNode(texture: dot)
            puff.color = c.mixed(with: RGBA(r: 0.5, g: 0.5, b: 0.55), CGFloat(i % 3) * 0.2).skColor
            puff.colorBlendFactor = 1
            let r = CGFloat(30 + (i % 3) * 22)
            let a = CGFloat(i) * 0.7
            puff.position = CGPoint(x: cos(a) * r, y: CGFloat(i) * 20 + sin(a) * 10)
            puff.size = CGSize(width: 110 - CGFloat(i) * 4, height: 80)
            spin.addChild(puff)
        }
        spin.run(.repeatForever(.sequence([.scaleX(to: -1, duration: 0.45), .scaleX(to: 1, duration: 0.45)])))
        body.addChild(spin)
        if cute {
            let face = sprite(CGSize(width: 60, height: 30)) { [self] ctx, _ in
                self.drawEyes(ctx, at: [CGPoint(x: 18, y: 15), CGPoint(x: 42, y: 15)], r: 5)
            }
            face.position = CGPoint(x: 0, y: 110)
            face.zPosition = 2
            body.addChild(face)
        } else {
            let flash = SKSpriteNode(texture: dot)
            flash.color = eyeColor.skColor; flash.colorBlendFactor = 1; flash.blendMode = .add
            flash.size = CGSize(width: 200, height: 200); flash.position = CGPoint(x: 0, y: 100); flash.alpha = 0
            flash.run(.repeatForever(.sequence([.wait(forDuration: 1.3, withRange: 1.2),
                                                .fadeAlpha(to: 0.8, duration: 0.05), .fadeOut(withDuration: 0.25)])))
            body.addChild(flash)
        }
    }

    private func buildSpirit() {
        let c = color
        let robe = sprite(CGSize(width: 110, height: 200), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 55, y: 0))
            p.addQuadCurve(to: CGPoint(x: 100, y: 200), controlPoint: CGPoint(x: 110, y: 40))
            for i in 0..<5 {
                let x = 100 - CGFloat(i + 1) * 18
                p.addLine(to: CGPoint(x: x + 9, y: 178 + CGFloat(i % 2) * 10))
                p.addLine(to: CGPoint(x: x, y: 200))
            }
            p.addQuadCurve(to: CGPoint(x: 55, y: 0), controlPoint: CGPoint(x: 0, y: 40))
            ctx.saveGState()
            ctx.addPath(p.cgPath); ctx.clip()
            TextureFactory.linearGradient(ctx, colors: [c, c.withAlpha(0.35)], from: .zero, to: CGPoint(x: 0, y: 200))
            ctx.restoreGState()
            ctx.setFillColor(c.darker(0.5).cgColor)
            ctx.fillEllipse(in: CGRect(x: 34, y: 22, width: 42, height: 40))
            self.drawEyes(ctx, at: [CGPoint(x: 46, y: 42), CGPoint(x: 64, y: 42)], r: 4.5)
        }
        robe.position = CGPoint(x: 0, y: 20)
        body.addChild(robe)
        body.run(.repeatForever(.sequence([.moveBy(x: 0, y: 16, duration: 0.8), .moveBy(x: 0, y: -16, duration: 0.8)])))
    }

    // MARK: Per-frame

    /// Only the serpent needs per-frame work: its segments slither along a sine behind the head.
    func animate(time: TimeInterval, groundAt: (CGFloat) -> CGFloat) {
        guard shape == .serpent, !segments.isEmpty else { return }
        let t = CGFloat(time)
        for (i, seg) in segments.enumerated() {
            let fi = CGFloat(i)
            let lx = -fi * 26
            let wx = position.x + lx
            let lift = 30 + sin(t * 5 - fi * 0.6) * 22
            seg.position = CGPoint(x: lx, y: groundAt(wx) - position.y + lift)
        }
    }

    /// Height offset so the guardian sits naturally on the ground or in the air.
    var hoverHeight: CGFloat {
        switch shape {
        case .bird: return 120
        case .spirit: return 10
        case .storm: return 0
        default: return 0
        }
    }

    func roar() {
        removeAction(forKey: "roar")
        run(.sequence([.scale(to: 1.15, duration: 0.12), .scale(to: 1, duration: 0.25)]), withKey: "roar")
    }
}
