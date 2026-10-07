import SpriteKit
import UIKit

/// A guardian head: drawn facing right, centered on the node. `r` is its radius, so
/// horns, headgear and signature details can be placed the same way on any head.
final class HeadNode: SKNode {
    let r: CGFloat
    init(r: CGFloat) {
        self.r = r
        super.init()
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// Procedural guardian visuals. Seven shared rigs (giant, serpent, beast…) provide the motion;
/// each realm's `GuardianDesign` reshapes the anatomy (heads, eyes, horns, headgear, wings, tail,
/// aura), paints the culture's motif on the body, and adds a one-of-a-kind signature detail
/// (GuardianSignatures.swift). Everything is drawn once into textures and animated with SKActions.
final class GuardianNode: SKNode {
    let shape: GuardianShape
    let design: GuardianDesign
    let motif: Motif
    let color: RGBA
    let eyeColor: RGBA
    let cute: Bool
    let dot: SKTexture

    /// Root of the animated body. Decorations attach here or to a head.
    let body = SKNode()
    /// Serpent body segments (index 0 is the lead head node's neck).
    private(set) var segments: [SKNode] = []
    /// All heads; heads[0] is the main one.
    private(set) var heads: [HeadNode] = []
    /// Extra serpent necks (multi-headed serpents), animated per frame.
    private var extraNecks: [(neck: [SKSpriteNode], head: HeadNode, phase: CGFloat)] = []

    // Anchor points in `body` space, set by each rig for shared features and signatures.
    var backPoint = CGPoint.zero
    var tailPoint = CGPoint.zero
    var chestPoint = CGPoint.zero
    var topY: CGFloat = 0

    init(realm: Realm, color: RGBA, eye: RGBA, cute: Bool, dot: SKTexture) {
        shape = realm.guardian.shape
        design = realm.guardian.design
        motif = realm.motif
        self.color = color
        self.eyeColor = eye
        self.cute = cute
        self.dot = dot
        super.init()
        addChild(body)

        switch shape {
        case .giant: buildGiant()
        case .serpent: buildSerpent()
        case .beast: buildBeast()
        case .bird: buildBird()
        case .wave: buildWave()
        case .storm: buildStorm()
        case .spirit: buildSpirit()
        }
        for head in heads {
            addHorns(to: head)
            addHeadgear(to: head)
        }
        if design.wings && shape != .bird { addWings(at: backPoint, span: shape == .serpent ? 90 : 110) }
        addTail()
        addAura()
        addSignature()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Drawing helpers

    func sprite(_ size: CGSize, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5),
                _ draw: @escaping (CGContext, CGSize) -> Void) -> SKSpriteNode {
        let tex = TextureFactory.image(size: size) { ctx in draw(ctx, size) }
        let s = SKSpriteNode(texture: tex)
        s.anchorPoint = anchor
        return s
    }

    /// Fills a path with a top-lit gradient and a darker rim, the base look for every body part.
    func fillShaded(_ ctx: CGContext, _ path: CGPath, base: RGBA, from: CGFloat, to: CGFloat, rim: Bool = true) {
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        TextureFactory.linearGradient(ctx, colors: [base.lighter(0.22), base, base.darker(0.3)],
                                      from: CGPoint(x: 0, y: from), to: CGPoint(x: 0, y: to))
        ctx.restoreGState()
        if rim {
            ctx.setStrokeColor(base.darker(0.45).cgColor)
            ctx.setLineWidth(2)
            ctx.addPath(path); ctx.strokePath()
        }
    }

    /// Paints the realm's motif in a band clipped to `path`.
    func motifBand(_ ctx: CGContext, clip path: CGPath, band: CGRect, alpha: Double = 0.75) {
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        MotifPainter.band(motif, in: band, ctx: ctx, ink: color.lighter(0.55).withAlpha(alpha),
                          base: color.darker(0.35).withAlpha(0.55))
        ctx.restoreGState()
    }

    /// Where the eyes go for this design, given a "pair" layout.
    func eyeLayout(_ pair: [CGPoint]) -> [CGPoint] {
        guard pair.count == 2 else { return pair }
        let mid = CGPoint(x: (pair[0].x + pair[1].x) / 2, y: (pair[0].y + pair[1].y) / 2)
        switch design.eyes {
        case .single: return [mid]
        case .many:
            let dx = pair[1].x - pair[0].x
            return pair + [CGPoint(x: mid.x, y: mid.y - abs(dx) * 0.7),
                           CGPoint(x: pair[0].x - dx * 0.6, y: pair[0].y - abs(dx) * 0.35)]
        default: return pair
        }
    }

    func drawEyes(_ ctx: CGContext, at points: [CGPoint], r: CGFloat) {
        let single = design.eyes == .single && points.count == 1
        let rr = single ? r * 1.9 : r
        for p in points {
            if cute {
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - rr * 1.6, y: p.y - rr * 1.6, width: rr * 3.2, height: rr * 3.2))
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - rr * 0.4, y: p.y - rr * 0.9, width: rr * 1.6, height: rr * 1.6))
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x + rr * 0.3, y: p.y - rr * 0.7, width: rr * 0.5, height: rr * 0.5))
                continue
            }
            switch design.eyes {
            case .slits:
                ctx.setFillColor(eyeColor.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - rr * 1.3, y: p.y - rr, width: rr * 2.6, height: rr * 2))
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - rr * 0.25, y: p.y - rr * 0.95, width: rr * 0.5, height: rr * 1.9))
            case .hollow:
                ctx.setFillColor(color.darker(0.75).cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - rr * 1.4, y: p.y - rr * 1.3, width: rr * 2.8, height: rr * 2.6))
                TextureFactory.radialGradient(ctx, colors: [eyeColor.lighter(0.7), eyeColor.withAlpha(0)], center: p, radius: rr * 0.9)
            case .mirror:
                TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 1, b: 1), RGBA(r: 0.7, g: 0.75, b: 0.85), RGBA(r: 0.35, g: 0.4, b: 0.5)],
                                              center: CGPoint(x: p.x - rr * 0.3, y: p.y - rr * 0.3), radius: rr * 1.5)
                ctx.setStrokeColor(eyeColor.cgColor); ctx.setLineWidth(1.5)
                ctx.strokeEllipse(in: CGRect(x: p.x - rr * 1.3, y: p.y - rr * 1.3, width: rr * 2.6, height: rr * 2.6))
            default:
                TextureFactory.radialGradient(ctx, colors: [eyeColor.lighter(0.7), eyeColor, eyeColor.withAlpha(0)], center: p, radius: rr * 1.9)
                ctx.setFillColor(UIColor.black.withAlphaComponent(0.8).cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - rr * 0.3, y: p.y - rr * 0.6, width: rr * 0.6, height: rr * 1.2))
            }
        }
    }

    // MARK: Heads

    enum HeadKind { case giant, serpent, beast, dog, bird, spirit }

    func makeHead(_ kind: HeadKind, r: CGFloat, tint: RGBA? = nil) -> HeadNode {
        let head = HeadNode(r: r)
        let c = tint ?? color
        let size = CGSize(width: r * 2.8, height: r * 2.4)
        let s = sprite(size) { [self] ctx, s in
            let cx = s.width / 2, cy = s.height / 2
            switch kind {
            case .giant:
                let skull = UIBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2.05))
                fillShaded(ctx, skull.cgPath, base: c, from: cy - r, to: cy + r)
                // Brow ridge and jaw.
                ctx.setFillColor(c.darker(0.25).cgColor)
                ctx.fill(CGRect(x: cx - r * 0.7, y: cy - r * 0.35, width: r * 1.5, height: r * 0.22))
                ctx.setStrokeColor(c.darker(0.45).cgColor); ctx.setLineWidth(2)
                ctx.move(to: CGPoint(x: cx - r * 0.1, y: cy + r * 0.55)); ctx.addLine(to: CGPoint(x: cx + r * 0.65, y: cy + r * 0.5)); ctx.strokePath()
                drawEyes(ctx, at: eyeLayout([CGPoint(x: cx - r * 0.05, y: cy - r * 0.05), CGPoint(x: cx + r * 0.5, y: cy - r * 0.05)]), r: r * 0.17)
            case .serpent:
                let p = UIBezierPath()
                p.move(to: CGPoint(x: cx - r, y: cy))
                p.addQuadCurve(to: CGPoint(x: cx + r * 1.35, y: cy + r * 0.1), controlPoint: CGPoint(x: cx, y: cy - r * 1.3))
                p.addLine(to: CGPoint(x: cx + r * 1.2, y: cy + r * 0.35))
                p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), controlPoint: CGPoint(x: cx, y: cy + r * 1.2))
                fillShaded(ctx, p.cgPath, base: c, from: cy - r, to: cy + r)
                ctx.setStrokeColor(c.darker(0.5).cgColor); ctx.setLineWidth(1.5)
                ctx.move(to: CGPoint(x: cx - r * 0.2, y: cy + r * 0.35)); ctx.addLine(to: CGPoint(x: cx + r * 1.2, y: cy + r * 0.3)); ctx.strokePath()
                ctx.setFillColor(c.darker(0.6).cgColor)
                ctx.fillEllipse(in: CGRect(x: cx + r * 1.0, y: cy - r * 0.15, width: r * 0.14, height: r * 0.1))
                drawEyes(ctx, at: eyeLayout([CGPoint(x: cx + r * 0.25, y: cy - r * 0.35), CGPoint(x: cx + r * 0.55, y: cy - r * 0.4)]), r: r * 0.16)
            case .beast, .dog:
                let long = kind == .beast
                let skull = UIBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r * 0.85, width: r * 1.7, height: r * 1.6))
                let snout = UIBezierPath(roundedRect: CGRect(x: cx, y: cy - r * 0.15, width: r * (long ? 1.35 : 1.1), height: r * 0.75), cornerRadius: r * 0.3)
                skull.append(snout)
                fillShaded(ctx, skull.cgPath, base: c, from: cy - r, to: cy + r)
                // Ear, nose, teeth.
                ctx.setFillColor(c.darker(0.2).cgColor)
                ctx.move(to: CGPoint(x: cx - r * 0.6, y: cy - r * 0.6)); ctx.addLine(to: CGPoint(x: cx - r * 0.45, y: cy - r * 1.25))
                ctx.addLine(to: CGPoint(x: cx - r * 0.1, y: cy - r * 0.7)); ctx.fillPath()
                ctx.setFillColor(c.darker(0.7).cgColor)
                ctx.fillEllipse(in: CGRect(x: cx + r * (long ? 1.15 : 0.9), y: cy - r * 0.2, width: r * 0.28, height: r * 0.22))
                ctx.setFillColor(UIColor.white.cgColor)
                for k in 0..<3 {
                    let tx = cx + r * (0.35 + CGFloat(k) * 0.28)
                    ctx.move(to: CGPoint(x: tx, y: cy + r * 0.58)); ctx.addLine(to: CGPoint(x: tx + r * 0.08, y: cy + r * 0.78))
                    ctx.addLine(to: CGPoint(x: tx + r * 0.16, y: cy + r * 0.58)); ctx.fillPath()
                }
                drawEyes(ctx, at: eyeLayout([CGPoint(x: cx + r * 0.05, y: cy - r * 0.3), CGPoint(x: cx + r * 0.32, y: cy - r * 0.32)]), r: r * 0.15)
            case .bird:
                let skull = UIBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 1.9, height: r * 1.9))
                fillShaded(ctx, skull.cgPath, base: c, from: cy - r, to: cy + r)
                let beak = UIBezierPath()
                beak.move(to: CGPoint(x: cx + r * 0.7, y: cy - r * 0.35))
                beak.addQuadCurve(to: CGPoint(x: cx + r * 1.4, y: cy + r * 0.25), controlPoint: CGPoint(x: cx + r * 1.4, y: cy - r * 0.45))
                beak.addLine(to: CGPoint(x: cx + r * 0.7, y: cy + r * 0.25))
                beak.close()
                fillShaded(ctx, beak.cgPath, base: RGBA(r: 0.98, g: 0.78, b: 0.25), from: cy - r * 0.4, to: cy + r * 0.3)
                drawEyes(ctx, at: [CGPoint(x: cx + r * 0.3, y: cy - r * 0.25)], r: r * 0.17)
            case .spirit:
                let hoodPath = UIBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r * 1.05, width: r * 2, height: r * 2.1))
                fillShaded(ctx, hoodPath.cgPath, base: c.darker(0.15), from: cy - r, to: cy + r)
                ctx.setFillColor(c.darker(0.7).cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - r * 0.65, y: cy - r * 0.6, width: r * 1.45, height: r * 1.4))
                drawEyes(ctx, at: eyeLayout([CGPoint(x: cx - r * 0.15, y: cy - r * 0.1), CGPoint(x: cx + r * 0.35, y: cy - r * 0.1)]), r: r * 0.16)
            }
        }
        head.addChild(s)
        heads.append(head)
        return head
    }

    // MARK: Rigs

    private func buildGiant() {
        let c = color
        let torso = sprite(CGSize(width: 150, height: 160), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
            // Legs.
            for lx in [40.0, 84.0] as [CGFloat] {
                let leg = UIBezierPath(roundedRect: CGRect(x: lx, y: 96, width: 26, height: 64), cornerRadius: 10)
                fillShaded(ctx, leg.cgPath, base: c.darker(0.2), from: 96, to: 160)
                ctx.setFillColor(c.darker(0.45).cgColor)
                ctx.fill(CGRect(x: lx - 3, y: 150, width: 32, height: 10))
            }
            // Torso with a belt band in the culture's motif.
            let chest = UIBezierPath(roundedRect: CGRect(x: 20, y: 10, width: 110, height: 96), cornerRadius: 32)
            fillShaded(ctx, chest.cgPath, base: c, from: 10, to: 106)
            motifBand(ctx, clip: chest.cgPath, band: CGRect(x: 0, y: 70, width: 150, height: 16))
            // Chest plates.
            ctx.setStrokeColor(c.darker(0.35).withAlpha(0.7).cgColor); ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: 75, y: 22)); ctx.addLine(to: CGPoint(x: 75, y: 64)); ctx.strokePath()
            ctx.addArc(center: CGPoint(x: 56, y: 38), radius: 14, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false); ctx.strokePath()
            ctx.addArc(center: CGPoint(x: 94, y: 38), radius: 14, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false); ctx.strokePath()
        }
        body.addChild(torso)
        let head = makeHead(.giant, r: 30)
        head.position = CGPoint(x: 6, y: 182)
        head.zPosition = 2
        body.addChild(head)
        for side in [-1.0, 1.0] as [CGFloat] {
            let arm = sprite(CGSize(width: 28, height: 96), anchor: CGPoint(x: 0.5, y: 0.92)) { [self] ctx, s in
                let p = UIBezierPath(roundedRect: CGRect(x: 2, y: 0, width: 24, height: 80), cornerRadius: 12)
                fillShaded(ctx, p.cgPath, base: c.darker(0.08), from: 0, to: 80)
                let fist = UIBezierPath(ovalIn: CGRect(x: 0, y: 72, width: 28, height: 24))
                fillShaded(ctx, fist.cgPath, base: c.darker(0.15), from: 72, to: 96)
            }
            arm.name = side > 0 ? "armFront" : "armBack"
            arm.position = CGPoint(x: side * 60, y: 142)
            arm.zPosition = side > 0 ? 1 : -1
            arm.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.5 * side, duration: 0.35), .rotate(toAngle: -0.5 * side, duration: 0.35),
            ])))
            body.addChild(arm)
        }
        // Extra heads (a many-headed giant) fan out around the main head.
        for k in 1..<max(design.heads, 1) {
            let a = CGFloat.pi * (0.15 + 0.7 * CGFloat(k - 1) / CGFloat(max(design.heads - 2, 1)))
            let h = makeHead(.giant, r: 17, tint: color.mixed(with: eyeColor, 0.12 * Double(k % 3)))
            h.position = CGPoint(x: 6 + cos(a) * 52, y: 172 + sin(a) * 40)
            h.zPosition = 1.5
            h.run(.repeatForever(.sequence([.wait(forDuration: 0.1 * Double(k)), .rotate(toAngle: 0.15, duration: 0.5),
                                            .rotate(toAngle: -0.15, duration: 0.5)])))
            body.addChild(h)
        }
        backPoint = CGPoint(x: -40, y: 130)
        tailPoint = CGPoint(x: -55, y: 50)
        chestPoint = CGPoint(x: 0, y: 110)
        topY = 215
        body.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.18), .moveBy(x: 0, y: -6, duration: 0.18)])))
    }

    private func buildSerpent() {
        let c = color
        let segTex = TextureFactory.image(size: CGSize(width: 46, height: 46)) { [self] ctx in
            let p = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 42, height: 42)).cgPath
            fillShaded(ctx, p, base: c, from: 2, to: 44)
            // Belly scales and the culture's pattern on the back.
            ctx.setFillColor(c.lighter(0.35).cgColor)
            ctx.fillEllipse(in: CGRect(x: 10, y: 26, width: 26, height: 14))
            motifBand(ctx, clip: p, band: CGRect(x: 0, y: 6, width: 46, height: 12), alpha: 0.7)
        }
        for i in 0..<14 {
            let s = SKSpriteNode(texture: segTex)
            s.setScale(1.0 - CGFloat(i) * 0.045)
            s.zPosition = -CGFloat(i)
            segments.append(s)
            body.addChild(s)
        }
        let head = makeHead(.serpent, r: 30)
        head.zPosition = 2
        segments.insert(head, at: 0)
        body.addChild(head)

        // Extra heads rise on their own necks from the front coils.
        let extra = max(design.heads - 1, 0)
        for k in 0..<extra {
            var neck: [SKSpriteNode] = []
            for j in 0..<7 {
                let s = SKSpriteNode(texture: segTex)
                s.setScale(0.62 - CGFloat(j) * 0.02)
                s.zPosition = -0.5 - CGFloat(k) * 0.1
                neck.append(s)
                body.addChild(s)
            }
            let h = makeHead(.serpent, r: 19, tint: c.mixed(with: eyeColor, 0.06 * Double(k % 3)))
            h.zPosition = 1 - CGFloat(k) * 0.1
            body.addChild(h)
            extraNecks.append((neck, h, CGFloat(k) * 0.8))
        }
        backPoint = CGPoint(x: -60, y: 60)
        tailPoint = CGPoint(x: -340, y: 30)
        chestPoint = CGPoint(x: -40, y: 40)
        topY = 120
    }

    private func buildBeast() {
        let c = color, dark = color.darker(0.25)
        for (i, x) in ([-44, -26, 30, 48] as [CGFloat]).enumerated() {
            let leg = sprite(CGSize(width: 22, height: 58), anchor: CGPoint(x: 0.5, y: 1)) { [self] ctx, s in
                let p = UIBezierPath(roundedRect: CGRect(x: 2, y: 0, width: 18, height: 50), cornerRadius: 8)
                fillShaded(ctx, p.cgPath, base: dark, from: 0, to: 50)
                // Claws.
                ctx.setFillColor(RGBA(r: 0.95, g: 0.92, b: 0.85).cgColor)
                for k in 0..<3 {
                    let cx = 4 + CGFloat(k) * 6
                    ctx.move(to: CGPoint(x: cx, y: 48)); ctx.addLine(to: CGPoint(x: cx + 6, y: 48)); ctx.addLine(to: CGPoint(x: cx + 5, y: 57)); ctx.fillPath()
                }
            }
            leg.name = "leg\(i)"
            leg.position = CGPoint(x: x, y: 60)
            let phase = i % 2 == 0 ? 0.45 : -0.45
            leg.zRotation = phase
            leg.zPosition = i < 2 ? -0.5 : 0.5
            leg.run(.repeatForever(.sequence([.rotate(toAngle: -phase, duration: 0.18), .rotate(toAngle: phase, duration: 0.18)])))
            body.addChild(leg)
        }
        let torso = sprite(CGSize(width: 150, height: 74), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
            let p = UIBezierPath(ovalIn: CGRect(x: 4, y: 6, width: 142, height: 62)).cgPath
            fillShaded(ctx, p, base: c, from: 6, to: 68)
            motifBand(ctx, clip: p, band: CGRect(x: 0, y: 14, width: 150, height: 14))
            // Belly highlight and ribs.
            ctx.setFillColor(c.lighter(0.25).withAlpha(0.7).cgColor)
            ctx.fillEllipse(in: CGRect(x: 30, y: 44, width: 90, height: 18))
        }
        torso.position = CGPoint(x: -6, y: 36)
        body.addChild(torso)
        let head = makeHead(design.heads > 1 ? .dog : .beast, r: 28)
        head.position = CGPoint(x: 74, y: 98)
        head.zPosition = 2
        body.addChild(head)
        // Many-headed beasts: extra heads fan forward on short necks.
        for k in 1..<max(design.heads, 1) {
            let a = CGFloat.pi * (0.1 + 0.55 * CGFloat(k - 1) / CGFloat(max(design.heads - 2, 1)))
            let h = makeHead(.dog, r: 17, tint: c.mixed(with: eyeColor, 0.05 * Double(k % 3)))
            h.position = CGPoint(x: 40 + cos(a) * 52, y: 96 + sin(a) * 46)
            h.zPosition = 1.5 - CGFloat(k) * 0.05
            h.run(.repeatForever(.sequence([.wait(forDuration: 0.07 * Double(k)), .moveBy(x: 4, y: 3, duration: 0.3),
                                            .moveBy(x: -4, y: -3, duration: 0.3)])))
            body.addChild(h)
        }
        backPoint = CGPoint(x: -20, y: 100)
        tailPoint = CGPoint(x: -76, y: 78)
        chestPoint = CGPoint(x: 40, y: 70)
        topY = 130
        body.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.18), .moveBy(x: 0, y: -5, duration: 0.18)])))
    }

    private func buildBird() {
        let c = color
        addWings(at: CGPoint(x: -10, y: 20), span: 140)
        let torso = sprite(CGSize(width: 110, height: 62)) { [self] ctx, s in
            let p = UIBezierPath(ovalIn: CGRect(x: 8, y: 14, width: 84, height: 40)).cgPath
            fillShaded(ctx, p, base: c, from: 14, to: 54)
            motifBand(ctx, clip: p, band: CGRect(x: 0, y: 36, width: 110, height: 10))
            // Breast feathers.
            ctx.setStrokeColor(c.lighter(0.3).withAlpha(0.8).cgColor); ctx.setLineWidth(1.5)
            for k in 0..<4 {
                ctx.addArc(center: CGPoint(x: 60 + CGFloat(k % 2) * 10, y: 22 + CGFloat(k) * 6), radius: 5,
                           startAngle: 0, endAngle: .pi, clockwise: false)
                ctx.strokePath()
            }
            // Talons.
            ctx.setStrokeColor(RGBA(r: 0.95, g: 0.75, b: 0.2).cgColor); ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: 46, y: 52)); ctx.addLine(to: CGPoint(x: 42, y: 62)); ctx.strokePath()
            ctx.move(to: CGPoint(x: 58, y: 52)); ctx.addLine(to: CGPoint(x: 56, y: 62)); ctx.strokePath()
        }
        body.addChild(torso)
        let head = makeHead(.bird, r: 18)
        head.position = CGPoint(x: 40, y: 12)
        head.zPosition = 2
        body.addChild(head)
        backPoint = CGPoint(x: -10, y: 20)
        tailPoint = CGPoint(x: -48, y: 0)
        chestPoint = CGPoint(x: 12, y: -6)
        topY = 60
        body.run(.repeatForever(.sequence([.moveBy(x: 0, y: 14, duration: 0.5), .moveBy(x: 0, y: -14, duration: 0.5)])))
    }

    private func buildWave() {
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
            TextureFactory.linearGradient(ctx, colors: [c.lighter(0.35), c, c.darker(0.4)],
                                          from: CGPoint(x: 0, y: 20), to: CGPoint(x: 0, y: 240))
            // Flowing inner currents and two motif bands.
            ctx.setStrokeColor(c.lighter(0.4).withAlpha(0.5).cgColor); ctx.setLineWidth(3)
            for k in 0..<4 {
                let y = 90 + CGFloat(k) * 34
                ctx.move(to: CGPoint(x: 40, y: y + 40)); ctx.addQuadCurve(to: CGPoint(x: 250, y: y), control: CGPoint(x: 150, y: y - 30)); ctx.strokePath()
            }
            ctx.restoreGState()
            motifBand(ctx, clip: p.cgPath, band: CGRect(x: 0, y: 150, width: 260, height: 18), alpha: 0.6)
            motifBand(ctx, clip: p.cgPath, band: CGRect(x: 0, y: 200, width: 260, height: 14), alpha: 0.5)
            drawEyes(ctx, at: eyeLayout([CGPoint(x: 172, y: 92), CGPoint(x: 204, y: 94)]), r: 6)
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
        backPoint = CGPoint(x: -40, y: 180)
        tailPoint = CGPoint(x: -150, y: 40)
        chestPoint = CGPoint(x: -20, y: 120)
        topY = 210
        body.run(.repeatForever(.sequence([.scaleY(to: 1.06, duration: 0.4), .scaleY(to: 0.96, duration: 0.4)])))
    }

    private func buildStorm() {
        let c = color
        let spin = SKNode()
        spin.name = "spin"
        let puffTex = TextureFactory.image(size: CGSize(width: 64, height: 64)) { ctx in
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 1, b: 1), RGBA(r: 1, g: 1, b: 1, a: 0.85), RGBA(r: 1, g: 1, b: 1, a: 0)],
                                          center: CGPoint(x: 32, y: 32), radius: 32)
        }
        for i in 0..<11 {
            let puff = SKSpriteNode(texture: puffTex)
            puff.color = c.mixed(with: RGBA(r: 0.5, g: 0.5, b: 0.55), Double(i % 3) * 0.2).darker(Double(i % 2) * 0.15).skColor
            puff.colorBlendFactor = 1
            let r = CGFloat(18 + i * 7)
            let a = CGFloat(i) * 0.7
            puff.position = CGPoint(x: cos(a) * r, y: CGFloat(i) * 18 + sin(a) * 10)
            puff.size = CGSize(width: 60 + CGFloat(i) * 8, height: 64)
            spin.addChild(puff)
        }
        // Motif-painted debris whirling in the funnel.
        let bandTex = TextureFactory.image(size: CGSize(width: 90, height: 14)) { [self] ctx in
            MotifPainter.band(motif, in: CGRect(x: 0, y: 0, width: 90, height: 14), ctx: ctx,
                              ink: c.lighter(0.6), base: c.darker(0.3).withAlpha(0.8))
        }
        for k in 0..<3 {
            let b = SKSpriteNode(texture: bandTex)
            b.position = CGPoint(x: 0, y: 50 + CGFloat(k) * 50)
            b.xScale = 0.9 + CGFloat(k) * 0.3
            spin.addChild(b)
        }
        spin.run(.repeatForever(.sequence([.scaleX(to: -1, duration: 0.45), .scaleX(to: 1, duration: 0.45)])))
        body.addChild(spin)
        if cute {
            let face = sprite(CGSize(width: 60, height: 30)) { [self] ctx, _ in
                drawEyes(ctx, at: [CGPoint(x: 18, y: 15), CGPoint(x: 42, y: 15)], r: 5)
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
        backPoint = CGPoint(x: -30, y: 150)
        tailPoint = CGPoint(x: 0, y: 0)
        chestPoint = CGPoint(x: 0, y: 110)
        topY = 210
    }

    private func buildSpirit() {
        let c = color
        let robe = sprite(CGSize(width: 120, height: 180), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 60, y: 0))
            p.addQuadCurve(to: CGPoint(x: 108, y: 180), controlPoint: CGPoint(x: 120, y: 40))
            for i in 0..<5 {
                let x = 108 - CGFloat(i + 1) * 19
                p.addLine(to: CGPoint(x: x + 9.5, y: 160 + CGFloat(i % 2) * 10))
                p.addLine(to: CGPoint(x: x, y: 180))
            }
            p.addQuadCurve(to: CGPoint(x: 60, y: 0), controlPoint: CGPoint(x: 0, y: 40))
            ctx.saveGState()
            ctx.addPath(p.cgPath); ctx.clip()
            TextureFactory.linearGradient(ctx, colors: [c.lighter(0.1), c, c.withAlpha(0.3)], from: .zero, to: CGPoint(x: 0, y: 180))
            // Folds.
            ctx.setStrokeColor(c.darker(0.4).withAlpha(0.6).cgColor); ctx.setLineWidth(2)
            for fx in [44.0, 62.0, 80.0] as [CGFloat] {
                ctx.move(to: CGPoint(x: fx, y: 40)); ctx.addQuadCurve(to: CGPoint(x: fx - 6, y: 170), control: CGPoint(x: fx + 8, y: 110)); ctx.strokePath()
            }
            ctx.restoreGState()
            motifBand(ctx, clip: p.cgPath, band: CGRect(x: 0, y: 128, width: 120, height: 16))
        }
        robe.position = CGPoint(x: 0, y: 20)
        body.addChild(robe)
        let head = makeHead(.spirit, r: 24)
        head.position = CGPoint(x: 2, y: 204)
        head.zPosition = 2
        body.addChild(head)
        // Thin reaching arms.
        for side in [-1.0, 1.0] as [CGFloat] {
            let arm = sprite(CGSize(width: 70, height: 16), anchor: CGPoint(x: 0, y: 0.5)) { ctx, s in
                ctx.setStrokeColor(c.darker(0.2).cgColor); ctx.setLineWidth(6); ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: 3, y: 8)); ctx.addQuadCurve(to: CGPoint(x: 64, y: 8), control: CGPoint(x: 34, y: 2)); ctx.strokePath()
                ctx.setStrokeColor(c.darker(0.5).cgColor); ctx.setLineWidth(2)
                for k in 0..<3 { ctx.move(to: CGPoint(x: 62, y: 8)); ctx.addLine(to: CGPoint(x: 69, y: 3 + CGFloat(k) * 5)); ctx.strokePath() }
            }
            arm.name = side > 0 ? "armFront" : "armBack"
            arm.position = CGPoint(x: side * 30, y: 160)
            arm.zRotation = side > 0 ? -0.2 : .pi + 0.2
            arm.zPosition = side > 0 ? 1 : -1
            arm.run(.repeatForever(.sequence([.rotate(byAngle: 0.25, duration: 0.7), .rotate(byAngle: -0.25, duration: 0.7)])))
            body.addChild(arm)
        }
        backPoint = CGPoint(x: -30, y: 170)
        tailPoint = CGPoint(x: -40, y: 40)
        chestPoint = CGPoint(x: 0, y: 150)
        topY = 230
        body.run(.repeatForever(.sequence([.moveBy(x: 0, y: 16, duration: 0.8), .moveBy(x: 0, y: -16, duration: 0.8)])))
    }

    // MARK: Shared features

    private func addHorns(to head: HeadNode) {
        let r = head.r
        let hornColor = RGBA(r: 0.92, g: 0.86, b: 0.72)
        switch design.horns {
        case .none: return
        case .ram:
            for side in [-1.0, 1.0] as [CGFloat] {
                let h = sprite(CGSize(width: r * 1.1, height: r * 1.1)) { ctx, s in
                    ctx.setStrokeColor(hornColor.darker(0.15).cgColor); ctx.setLineWidth(r * 0.22); ctx.setLineCap(.round)
                    ctx.addArc(center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width * 0.32,
                               startAngle: -.pi * 0.9, endAngle: .pi * 0.7, clockwise: false)
                    ctx.strokePath()
                }
                h.position = CGPoint(x: side * r * 0.55, y: r * 0.55)
                h.zPosition = side > 0 ? 0.5 : -0.5
                head.addChild(h)
            }
        case .bull, .antlers, .spikes, .single:
            let count = design.horns == .single ? 1 : design.horns == .spikes ? 4 : 2
            for k in 0..<count {
                let h = sprite(CGSize(width: r * 0.8, height: r * (design.horns == .single ? 1.4 : 1.0)), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
                    let w = s.width, ht = s.height
                    let p = UIBezierPath()
                    switch design.horns {
                    case .bull:
                        p.move(to: CGPoint(x: w * 0.2, y: ht)); p.addQuadCurve(to: CGPoint(x: w * 0.9, y: 0), controlPoint: CGPoint(x: w * 0.1, y: ht * 0.2))
                        p.addQuadCurve(to: CGPoint(x: w * 0.75, y: ht), controlPoint: CGPoint(x: w * 0.5, y: ht * 0.4))
                    case .antlers:
                        p.move(to: CGPoint(x: w * 0.45, y: ht)); p.addLine(to: CGPoint(x: w * 0.5, y: 0)); p.addLine(to: CGPoint(x: w * 0.6, y: ht))
                    default:
                        p.move(to: CGPoint(x: w * 0.15, y: ht)); p.addLine(to: CGPoint(x: w * 0.55, y: 0)); p.addLine(to: CGPoint(x: w * 0.85, y: ht))
                    }
                    p.close()
                    fillShaded(ctx, p.cgPath, base: design.horns == .spikes ? color.darker(0.2) : hornColor, from: 0, to: ht, rim: false)
                }
                let spread = CGFloat(k) - CGFloat(count - 1) / 2
                h.position = CGPoint(x: spread * r * 0.45, y: r * 0.65)
                h.zRotation = -spread * 0.35
                h.zPosition = -0.4
                head.addChild(h)
            }
        }
    }

    private func addHeadgear(to head: HeadNode) {
        let r = head.r
        let gold = RGBA(r: 0.98, g: 0.78, b: 0.25)
        switch design.headgear {
        case .none: return
        case .crown:
            let s = sprite(CGSize(width: r * 1.5, height: r * 0.8), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
                let w = s.width, h = s.height
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 0, y: h))
                for k in 0...4 {
                    let x = w * CGFloat(k) / 4
                    p.addLine(to: CGPoint(x: x, y: k % 2 == 0 ? 0 : h * 0.45))
                }
                p.addLine(to: CGPoint(x: w, y: h)); p.close()
                fillShaded(ctx, p.cgPath, base: gold, from: 0, to: h, rim: false)
                ctx.setFillColor(eyeColor.cgColor)
                ctx.fillEllipse(in: CGRect(x: w / 2 - 3, y: h * 0.55, width: 6, height: 6))
            }
            s.position = CGPoint(x: 0, y: r * 0.75)
            head.addChild(s)
        case .helmet:
            // A crested helmet with a horsehair plume.
            let s = sprite(CGSize(width: r * 2.4, height: r * 1.6)) { [self] ctx, s in
                let w = s.width, h = s.height
                let dome = UIBezierPath()
                dome.move(to: CGPoint(x: w * 0.12, y: h * 0.95))
                dome.addQuadCurve(to: CGPoint(x: w * 0.85, y: h * 0.8), controlPoint: CGPoint(x: w * 0.45, y: h * 0.05))
                dome.addLine(to: CGPoint(x: w * 0.85, y: h)); dome.addLine(to: CGPoint(x: w * 0.12, y: h)); dome.close()
                fillShaded(ctx, dome.cgPath, base: color.lighter(0.1), from: 0, to: h)
                let plume = UIBezierPath()
                plume.move(to: CGPoint(x: w * 0.05, y: h * 0.55))
                plume.addQuadCurve(to: CGPoint(x: w * 0.75, y: h * 0.25), controlPoint: CGPoint(x: w * 0.35, y: -h * 0.2))
                plume.addQuadCurve(to: CGPoint(x: w * 0.05, y: h * 0.55), controlPoint: CGPoint(x: w * 0.4, y: h * 0.3))
                fillShaded(ctx, plume.cgPath, base: RGBA(r: 0.8, g: 0.15, b: 0.15), from: 0, to: h * 0.5, rim: false)
            }
            // Sits on the crown of the head, leaving the face visible.
            s.position = CGPoint(x: -r * 0.1, y: r * 1.05)
            s.setScale(0.85)
            s.zPosition = 0.3
            head.addChild(s)
        case .feathers:
            let colors = [RGBA(r: 0.1, g: 0.6, b: 0.35), eyeColor, RGBA(r: 0.15, g: 0.45, b: 0.85), RGBA(r: 0.95, g: 0.3, b: 0.2)]
            for k in 0..<7 {
                let f = sprite(CGSize(width: r * 0.45, height: r * 1.6), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
                    let p = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: s.width, height: s.height))
                    fillShaded(ctx, p.cgPath, base: colors[k % colors.count], from: 0, to: s.height, rim: false)
                    ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor); ctx.setLineWidth(1)
                    ctx.move(to: CGPoint(x: s.width / 2, y: s.height)); ctx.addLine(to: CGPoint(x: s.width / 2, y: 4)); ctx.strokePath()
                }
                f.position = CGPoint(x: -r * 0.2, y: r * 0.5)
                f.zRotation = -0.9 + CGFloat(k) * 0.3
                f.zPosition = -0.6
                head.addChild(f)
            }
        case .hood:
            // A flared hood behind the head (cobra hood or parka, depending on the rig).
            let s = sprite(CGSize(width: r * 2.6, height: r * 2.8)) { [self] ctx, s in
                let p = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: s.width, height: s.height))
                fillShaded(ctx, p.cgPath, base: color.darker(0.1), from: 0, to: s.height)
                motifBand(ctx, clip: p.cgPath, band: CGRect(x: 0, y: s.height * 0.62, width: s.width, height: s.height * 0.16))
            }
            s.position = CGPoint(x: -r * 0.3, y: 0)
            s.zPosition = -0.8
            head.addChild(s)
        case .mane:
            let s = sprite(CGSize(width: r * 2.8, height: r * 2.8)) { [self] ctx, s in
                let cx = s.width / 2, cy = s.height / 2
                ctx.setFillColor(color.darker(0.3).cgColor)
                for k in 0..<14 {
                    let a = CGFloat(k) / 14 * .pi * 2
                    ctx.move(to: CGPoint(x: cx + cos(a - 0.25) * r * 0.8, y: cy + sin(a - 0.25) * r * 0.8))
                    ctx.addLine(to: CGPoint(x: cx + cos(a) * r * 1.38, y: cy + sin(a) * r * 1.38))
                    ctx.addLine(to: CGPoint(x: cx + cos(a + 0.25) * r * 0.8, y: cy + sin(a + 0.25) * r * 0.8))
                    ctx.fillPath()
                }
            }
            s.position = CGPoint(x: -r * 0.35, y: 0)
            s.zPosition = -0.8
            head.addChild(s)
        case .crest:
            let s = sprite(CGSize(width: r * 1.8, height: r * 0.9), anchor: CGPoint(x: 0.5, y: 0)) { ctx, s in
                let w = s.width, h = s.height
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 0, y: h))
                for k in 0..<5 {
                    p.addLine(to: CGPoint(x: w * (CGFloat(k) + 0.5) / 5, y: h * 0.1 + CGFloat(k % 2) * h * 0.25))
                    p.addLine(to: CGPoint(x: w * CGFloat(k + 1) / 5, y: h))
                }
                p.close()
                ctx.setFillColor(gold.mixed(with: RGBA(r: 0.9, g: 0.2, b: 0.2), 0.5).cgColor)
                ctx.addPath(p.cgPath); ctx.fillPath()
            }
            s.position = CGPoint(x: -r * 0.4, y: r * 0.6)
            s.zRotation = 0.25
            s.zPosition = -0.5
            head.addChild(s)
        }
    }

    func addWings(at point: CGPoint, span: CGFloat) {
        let c = color
        for side in [-1.0, 1.0] as [CGFloat] {
            let wing = sprite(CGSize(width: span, height: span * 0.48), anchor: CGPoint(x: 0.08, y: 0.1)) { [self] ctx, s in
                let w = s.width, h = s.height
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 0, y: h * 0.9))
                p.addQuadCurve(to: CGPoint(x: w, y: 0), controlPoint: CGPoint(x: w * 0.3, y: 0))
                // Scalloped feather edge.
                for k in 0..<5 {
                    let x0 = w - CGFloat(k) * w * 0.18
                    p.addQuadCurve(to: CGPoint(x: x0 - w * 0.18, y: h * (0.3 + CGFloat(k) * 0.12)),
                                   controlPoint: CGPoint(x: x0 - w * 0.02, y: h * (0.45 + CGFloat(k) * 0.12)))
                }
                p.addLine(to: CGPoint(x: 0, y: h * 0.9))
                fillShaded(ctx, p.cgPath, base: c.darker(side > 0 ? 0 : 0.22), from: 0, to: h)
                motifBand(ctx, clip: p.cgPath, band: CGRect(x: 0, y: h * 0.18, width: w, height: h * 0.18), alpha: 0.6)
            }
            wing.position = point
            wing.zPosition = side > 0 ? 1.2 : -1.2
            wing.run(.repeatForever(.sequence([.scaleY(to: -0.6, duration: 0.25), .scaleY(to: 1, duration: 0.25)])))
            body.addChild(wing)
        }
    }

    private func addTail() {
        guard shape != .serpent || design.tail == .fish else {
            if design.tail == .spiked { spikeSegments() }
            return
        }
        let c = color
        let p = shape == .serpent ? CGPoint(x: -340, y: 30) : tailPoint
        let node: SKSpriteNode
        switch design.tail {
        case .none, .plain:
            guard shape == .beast else { return }
            node = sprite(CGSize(width: 70, height: 40), anchor: CGPoint(x: 1, y: 0.3)) { ctx, s in
                ctx.setStrokeColor(c.cgColor); ctx.setLineWidth(9); ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: 66, y: 28)); ctx.addQuadCurve(to: CGPoint(x: 6, y: 6), control: CGPoint(x: 20, y: 34)); ctx.strokePath()
            }
        case .serpent:
            node = sprite(CGSize(width: 90, height: 50), anchor: CGPoint(x: 1, y: 0.4)) { [self] ctx, s in
                ctx.setStrokeColor(c.darker(0.1).cgColor); ctx.setLineWidth(10); ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: 86, y: 30)); ctx.addCurve(to: CGPoint(x: 18, y: 18), control1: CGPoint(x: 60, y: 50), control2: CGPoint(x: 40, y: 0)); ctx.strokePath()
                let h = UIBezierPath(ovalIn: CGRect(x: 0, y: 8, width: 24, height: 18))
                fillShaded(ctx, h.cgPath, base: c.mixed(with: RGBA(r: 0.2, g: 0.5, b: 0.2), 0.4), from: 8, to: 26)
                drawEyes(ctx, at: [CGPoint(x: 7, y: 14)], r: 2.5)
            }
        case .fish:
            node = sprite(CGSize(width: 60, height: 70), anchor: CGPoint(x: 0.85, y: 0.5)) { [self] ctx, s in
                let f = UIBezierPath()
                f.move(to: CGPoint(x: 56, y: 35)); f.addLine(to: CGPoint(x: 4, y: 4)); f.addQuadCurve(to: CGPoint(x: 4, y: 66), controlPoint: CGPoint(x: 22, y: 35)); f.close()
                fillShaded(ctx, f.cgPath, base: c.lighter(0.1), from: 4, to: 66)
                ctx.setStrokeColor(c.lighter(0.45).cgColor); ctx.setLineWidth(1.2)
                for k in 0..<4 { ctx.move(to: CGPoint(x: 52, y: 35)); ctx.addLine(to: CGPoint(x: 10, y: 10 + CGFloat(k) * 16)); ctx.strokePath() }
            }
        case .flame:
            node = sprite(CGSize(width: 50, height: 60), anchor: CGPoint(x: 1, y: 0.5)) { ctx, s in
                TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 0.95, b: 0.5), RGBA(r: 1, g: 0.45, b: 0.1), RGBA(r: 1, g: 0.2, b: 0, a: 0)],
                                              center: CGPoint(x: 30, y: 30), radius: 26)
            }
        case .plume:
            // A bushy fan of long feathers/fur sweeping back and up from the root (right edge).
            node = sprite(CGSize(width: 80, height: 60), anchor: CGPoint(x: 1, y: 0.5)) { [self] ctx, s in
                for k in 0..<5 {
                    ctx.saveGState()
                    ctx.translateBy(x: 76, y: 30)
                    ctx.rotate(by: -0.5 + CGFloat(k) * 0.25)
                    let f = UIBezierPath(ovalIn: CGRect(x: -74, y: -7, width: 74, height: 14))
                    fillShaded(ctx, f.cgPath, base: k % 2 == 0 ? c.lighter(0.12) : eyeColor.mixed(with: c, 0.55), from: -7, to: 7)
                    ctx.restoreGState()
                }
            }
        case .spiked:
            node = sprite(CGSize(width: 80, height: 40), anchor: CGPoint(x: 1, y: 0.5)) { [self] ctx, s in
                let t = UIBezierPath()
                t.move(to: CGPoint(x: 80, y: 12)); t.addLine(to: CGPoint(x: 0, y: 20)); t.addLine(to: CGPoint(x: 80, y: 30)); t.close()
                fillShaded(ctx, t.cgPath, base: c, from: 12, to: 30)
                ctx.setFillColor(c.darker(0.4).cgColor)
                for k in 0..<4 {
                    let x = 14 + CGFloat(k) * 16
                    ctx.move(to: CGPoint(x: x, y: 18)); ctx.addLine(to: CGPoint(x: x + 6, y: 4)); ctx.addLine(to: CGPoint(x: x + 12, y: 18)); ctx.fillPath()
                }
            }
        }
        node.name = "tail"
        node.position = p
        node.zPosition = -2
        node.run(.repeatForever(.sequence([.rotate(toAngle: 0.18, duration: 0.4), .rotate(toAngle: -0.18, duration: 0.4)])))
        if shape == .serpent, let last = segments.last {
            // Serpent tails ride on the last segment.
            node.position = CGPoint(x: -14, y: 0)
            last.addChild(node)
        } else {
            body.addChild(node)
        }
    }

    /// Dorsal spikes along a serpent's back.
    private func spikeSegments() {
        let spikeTex = TextureFactory.image(size: CGSize(width: 16, height: 18)) { [self] ctx in
            ctx.setFillColor(color.darker(0.4).cgColor)
            ctx.move(to: CGPoint(x: 0, y: 18)); ctx.addLine(to: CGPoint(x: 8, y: 0)); ctx.addLine(to: CGPoint(x: 16, y: 18)); ctx.fillPath()
        }
        for seg in segments.dropFirst() where segments.firstIndex(of: seg)! % 2 == 1 {
            let s = SKSpriteNode(texture: spikeTex)
            s.position = CGPoint(x: 0, y: 24)
            s.zPosition = -0.1
            seg.addChild(s)
        }
    }

    private func addAura() {
        guard design.aura != .none else { return }
        let e = SKEmitterNode()
        e.particleTexture = dot
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .alpha
        e.particlePositionRange = CGVector(dx: 160, dy: 120)
        e.position = CGPoint(x: shape == .serpent ? -120 : 0, y: topY * 0.5)
        e.particleLifetime = 1.4
        e.particleBirthRate = 16
        e.particleAlpha = 0.85
        e.particleAlphaSpeed = -0.6
        e.particleScale = 0.12
        e.particleScaleRange = 0.06
        e.zPosition = -3
        switch design.aura {
        case .none: return
        case .flames:
            e.particleColor = UIColor(red: 1, green: 0.5, blue: 0.1, alpha: 1); e.particleBlendMode = .add
            e.emissionAngle = .pi / 2; e.particleSpeed = 60; e.particleScaleSpeed = -0.08; e.particleBirthRate = 30
        case .frost:
            e.particleColor = UIColor(red: 0.85, green: 0.95, blue: 1, alpha: 1)
            e.emissionAngle = -.pi / 2; e.emissionAngleRange = 1; e.particleSpeed = 30; e.particleScale = 0.08
        case .sparks:
            e.particleColor = eyeColor.lighter(0.4).skColor; e.particleBlendMode = .add
            e.emissionAngleRange = .pi * 2; e.particleSpeed = 80; e.particleScale = 0.06; e.particleLifetime = 0.6
        case .smoke:
            e.particleColor = color.darker(0.5).skColor; e.particleAlpha = 0.35
            e.emissionAngle = .pi / 2; e.particleSpeed = 25; e.particleScale = 0.6; e.particleScaleSpeed = 0.3; e.particleBirthRate = 8
        case .water:
            e.particleColor = UIColor(red: 0.6, green: 0.85, blue: 1, alpha: 1)
            e.emissionAngle = .pi / 2; e.emissionAngleRange = 0.8; e.particleSpeed = 90; e.yAcceleration = -200; e.particleScale = 0.07
        case .dust:
            e.particleColor = color.lighter(0.3).skColor; e.particleAlpha = 0.4
            e.emissionAngle = .pi; e.particleSpeed = 70; e.particleScale = 0.35; e.particleScaleSpeed = 0.2; e.particleBirthRate = 12
        case .petals:
            e.particleColor = UIColor(red: 1, green: 0.77, blue: 0.84, alpha: 1)
            e.emissionAngle = -.pi / 2; e.emissionAngleRange = 1.4; e.particleSpeed = 30; e.particleRotationSpeed = 3; e.particleScale = 0.1
        case .stars:
            e.particleColor = UIColor(red: 1, green: 0.95, blue: 0.75, alpha: 1); e.particleBlendMode = .add
            e.emissionAngleRange = .pi * 2; e.particleSpeed = 10; e.particleScale = 0.05; e.particleLifetime = 1.8
            e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0], times: [0, 0.5, 1])
        case .lightning:
            e.particleColor = eyeColor.lighter(0.6).skColor; e.particleBlendMode = .add
            e.particleBirthRate = 6; e.particleLifetime = 0.15; e.particleScale = 0.5; e.particleSpeed = 0
        case .leaves:
            e.particleColor = UIColor(red: 0.35, green: 0.65, blue: 0.3, alpha: 1)
            e.emissionAngle = -.pi / 2; e.emissionAngleRange = 1.4; e.particleSpeed = 40; e.particleRotationSpeed = 2.5; e.particleScale = 0.1
        }
        body.addChild(e)
    }

    // MARK: Per-frame

    /// Serpents slither: segments (and any extra necks) follow a sine wave behind the head.
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
        // Extra necks fan up from the front coils (spread over several segments), each swaying on its own phase.
        let count = CGFloat(max(extraNecks.count, 1))
        for (k, n) in extraNecks.enumerated() {
            let root = segments[min(1 + k % 4, segments.count - 1)].position
            let spread = (CGFloat(k) - (count - 1) / 2) / count * 1.9
            let sway = sin(t * 3 + n.phase) * 0.14
            let angle = CGFloat.pi / 2 - spread + sway
            let step: CGFloat = 16 + CGFloat(k % 2) * 4
            for (j, s) in n.neck.enumerated() {
                let d = CGFloat(j + 1) * step
                s.position = CGPoint(x: root.x + cos(angle) * d, y: root.y + sin(angle) * d)
            }
            let d = CGFloat(n.neck.count + 1) * step
            n.head.position = CGPoint(x: root.x + cos(angle) * d, y: root.y + sin(angle) * d)
            n.head.zRotation = spread * 0.25
        }
    }

    /// Extra lift a signature needs (e.g. a guardian hanging from a branch with dangling legs).
    var extraHover: CGFloat = 0

    /// Height offset so the guardian sits naturally on the ground or in the air.
    var hoverHeight: CGFloat {
        switch shape {
        case .bird: return 120 + extraHover
        case .spirit: return 10 + extraHover
        default: return extraHover
        }
    }

    func roar() {
        removeAction(forKey: "roar")
        run(.sequence([.scale(to: 1.15, duration: 0.12), .scale(to: 1, duration: 0.25)]), withKey: "roar")
    }
}
