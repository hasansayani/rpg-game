import SpriteKit
import UIKit

/// The one detail each guardian has that no other does, taken from its myth.
/// Coordinates are in the guardian's `body` space (y up, facing right) or a head's local space.
extension GuardianNode {
    func addSignature() {
        switch design.signature {
        case .ichorVein: ichorVein()
        case .sunSwallower: sunSwallower()
        case .gleipnir: gleipnir()
        case .mossBacks: mossBacks()
        case .jointMouths: jointMouths()
        case .evilEye: evilEye()
        case .hoardedWaters: hoardedWaters()
        case .coiledFace: coiledFace()
        case .cowrieCrest: cowrieCrest()
        case .pauaEyes: pauaEyes()
        case .firecrackers: firecrackers()
        case .jewelTeeth: jewelTeeth()
        case .needleEgg: needleEgg()
        case .horseMane: horseMane()
        case .amautik: amautik()
        case .stoneClub: stoneClub()
        case .peleHair: peleHair()
        case .featheredSerpent: featheredSerpent()
        case .scytheTalons: scytheTalons()
        case .ironHooks: ironHooks()
        case .manyHeads: lamellarArmor()
        case .stolenHeart: stolenHeart()
        case .firstEgg: firstEgg()
        case .zemiArms: zemiArms()
        case .goatAndSerpent: goatAndSerpent()
        case .dustStar: dustStar()
        case .iceFangs: iceFangs()
        case .sevenDogs: treasureHoard()
        case .moonInMouth: moonInMouth()
        case .starMaw: starMaw()
        }
    }

    private var mainHead: HeadNode? { heads.first }

    private func glow(_ color: RGBA, size: CGFloat, at p: CGPoint, pulse: Bool = true, parent: SKNode? = nil) -> SKSpriteNode {
        let g = SKSpriteNode(texture: dot)
        g.color = color.skColor
        g.colorBlendFactor = 1
        g.blendMode = .add
        g.size = CGSize(width: size, height: size)
        g.position = p
        if pulse { g.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)]))) }
        (parent ?? body).addChild(g)
        return g
    }

    // MARK: Greek: Talos, bronze giant with a single vein of ichor sealed by a nail at the ankle.
    private func ichorVein() {
        let ichor = RGBA(r: 1, g: 0.65, b: 0.15)
        let vein = sprite(CGSize(width: 30, height: 190), anchor: CGPoint(x: 0.5, y: 0)) { ctx, s in
            ctx.setStrokeColor(ichor.cgColor); ctx.setLineWidth(3.5); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 14, y: 4))
            ctx.addCurve(to: CGPoint(x: 18, y: 180), control1: CGPoint(x: 26, y: 70), control2: CGPoint(x: 4, y: 120))
            ctx.strokePath()
            // The bronze nail that seals it.
            ctx.setFillColor(RGBA(r: 0.45, g: 0.32, b: 0.2).cgColor)
            ctx.fill(CGRect(x: 10, y: 176, width: 16, height: 6))
            ctx.fill(CGRect(x: 15, y: 170, width: 6, height: 16))
        }
        vein.position = CGPoint(x: 16, y: 6)
        vein.zPosition = 0.6
        vein.run(.repeatForever(.sequence([.fadeAlpha(to: 0.6, duration: 0.35), .fadeAlpha(to: 1, duration: 0.35)])))
        body.addChild(vein)
        // Rivets on the bronze plates.
        let rivet = TextureFactory.image(size: CGSize(width: 6, height: 6)) { ctx in
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 0.9, b: 0.6), RGBA(r: 0.5, g: 0.3, b: 0.1)], center: CGPoint(x: 2, y: 2), radius: 4)
        }
        for p in [CGPoint(x: -40, y: 140), CGPoint(x: -40, y: 110), CGPoint(x: 40, y: 140), CGPoint(x: 40, y: 110), CGPoint(x: -20, y: 150), CGPoint(x: 20, y: 150)] {
            let r = SKSpriteNode(texture: rivet); r.position = p; r.zPosition = 0.5; body.addChild(r)
        }
        _ = glow(ichor, size: 26, at: CGPoint(x: 34, y: 14))
    }

    // MARK: Egyptian: Apep tries to swallow the sun disk of Ra's evening boat.
    private func sunSwallower() {
        guard let head = mainHead else { return }
        let sun = sprite(CGSize(width: 50, height: 50)) { ctx, s in
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 0.95, b: 0.6), RGBA(r: 0.95, g: 0.35, b: 0.15)], center: CGPoint(x: 25, y: 25), radius: 22)
            // The uraeus-like rim and a bite taken out.
            ctx.setStrokeColor(RGBA(r: 1, g: 0.85, b: 0.3).cgColor); ctx.setLineWidth(3)
            ctx.strokeEllipse(in: CGRect(x: 4, y: 4, width: 42, height: 42))
            ctx.setBlendMode(.clear)
            ctx.fillEllipse(in: CGRect(x: -14, y: 6, width: 26, height: 38))
        }
        sun.position = CGPoint(x: head.r * 1.9, y: head.r * 0.05)
        sun.zPosition = -0.2
        sun.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 8)))
        head.addChild(sun)
        _ = glow(RGBA(r: 1, g: 0.6, b: 0.2), size: 90, at: sun.position, parent: head).zPosition = -0.3
        // Knife marks along the coils (Ra's defenders cut Apep each night).
        let cut = TextureFactory.image(size: CGSize(width: 18, height: 6)) { ctx in
            ctx.setFillColor(RGBA(r: 0.85, g: 0.85, b: 0.95).cgColor)
            ctx.move(to: CGPoint(x: 0, y: 3)); ctx.addLine(to: CGPoint(x: 18, y: 0)); ctx.addLine(to: CGPoint(x: 18, y: 6)); ctx.fillPath()
        }
        for (i, seg) in segments.enumerated() where i % 4 == 2 {
            let k = SKSpriteNode(texture: cut); k.zRotation = 0.6; k.position = CGPoint(x: 0, y: 6); seg.addChild(k)
        }
    }

    // MARK: Norse: Fenrir bound by Gleipnir, a ribbon "soft as silk" made from impossible things.
    private func gleipnir() {
        guard let head = mainHead else { return }
        let ribbon = sprite(CGSize(width: 180, height: 50), anchor: CGPoint(x: 0.95, y: 0.5)) { ctx, s in
            ctx.setStrokeColor(RGBA(r: 0.85, g: 0.95, b: 1, a: 0.9).cgColor); ctx.setLineWidth(5); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 172, y: 25))
            ctx.addCurve(to: CGPoint(x: 4, y: 30), control1: CGPoint(x: 120, y: 0), control2: CGPoint(x: 60, y: 50))
            ctx.strokePath()
            ctx.setStrokeColor(RGBA(r: 0.6, g: 0.9, b: 1).cgColor); ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 172, y: 25))
            ctx.addCurve(to: CGPoint(x: 4, y: 30), control1: CGPoint(x: 120, y: 0), control2: CGPoint(x: 60, y: 50))
            ctx.strokePath()
        }
        ribbon.position = CGPoint(x: head.position.x - 26, y: head.position.y - 18)
        ribbon.zPosition = 2.5
        ribbon.run(.repeatForever(.sequence([.scaleY(to: -1, duration: 0.6), .scaleY(to: 1, duration: 0.6)])))
        body.addChild(ribbon)
        // A collar where the ribbon is tied.
        let collar = sprite(CGSize(width: 18, height: 50)) { ctx, s in
            ctx.setFillColor(RGBA(r: 0.85, g: 0.95, b: 1).cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 4, y: 0, width: 10, height: 50), cornerRadius: 5).cgPath); ctx.fillPath()
        }
        collar.position = CGPoint(x: head.position.x - 26, y: head.position.y - 14)
        collar.zRotation = -0.4
        collar.zPosition = 2.4
        body.addChild(collar)
        _ = glow(RGBA(r: 0.6, g: 0.9, b: 1), size: 40, at: collar.position)
    }

    // MARK: Japanese: Yamata no Orochi, eight heads, moss and cypress growing on its back.
    private func mossBacks() {
        let moss = TextureFactory.image(size: CGSize(width: 30, height: 26)) { ctx in
            ctx.setFillColor(RGBA(r: 0.25, g: 0.45, b: 0.2).cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 16, width: 30, height: 10))
            // A tiny cypress.
            ctx.setFillColor(RGBA(r: 0.15, g: 0.35, b: 0.2).cgColor)
            ctx.move(to: CGPoint(x: 15, y: 0)); ctx.addLine(to: CGPoint(x: 24, y: 18)); ctx.addLine(to: CGPoint(x: 6, y: 18)); ctx.fillPath()
            ctx.setFillColor(RGBA(r: 0.4, g: 0.25, b: 0.15).cgColor)
            ctx.fill(CGRect(x: 14, y: 18, width: 3, height: 5))
        }
        for (i, seg) in segments.enumerated() where i > 1 && i % 3 == 0 {
            let m = SKSpriteNode(texture: moss); m.position = CGPoint(x: 0, y: 20); m.zPosition = 0.2; seg.addChild(m)
        }
        // A red belly glow, as the Kojiki describes its belly "bloody and inflamed".
        for (i, seg) in segments.enumerated() where i > 0 && i % 2 == 1 {
            _ = glow(RGBA(r: 0.9, g: 0.15, b: 0.1), size: 30, at: CGPoint(x: 0, y: -12), pulse: false, parent: seg).alpha = 0.5
        }
    }

    // MARK: Aztec: Cipactli, the crocodile-fish-toad with a mouth at every joint.
    private func jointMouths() {
        let mouth = TextureFactory.image(size: CGSize(width: 22, height: 16)) { ctx in
            ctx.setFillColor(RGBA(r: 0.45, g: 0.05, b: 0.08).cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 2, width: 22, height: 12))
            ctx.setFillColor(UIColor.white.cgColor)
            for k in 0..<4 {
                let x = 3 + CGFloat(k) * 4.5
                ctx.move(to: CGPoint(x: x, y: 3)); ctx.addLine(to: CGPoint(x: x + 2.2, y: 8)); ctx.addLine(to: CGPoint(x: x + 4.4, y: 3)); ctx.fillPath()
                ctx.move(to: CGPoint(x: x, y: 13)); ctx.addLine(to: CGPoint(x: x + 2.2, y: 8)); ctx.addLine(to: CGPoint(x: x + 4.4, y: 13)); ctx.fillPath()
            }
        }
        for child in body.children where child.name?.hasPrefix("leg") == true {
            let m = SKSpriteNode(texture: mouth)
            m.position = CGPoint(x: 0, y: -16)
            m.zPosition = 0.3
            m.run(.repeatForever(.sequence([.scaleY(to: 0.4, duration: 0.2), .scaleY(to: 1, duration: 0.2)])))
            child.addChild(m)
        }
        // Crocodile back ridges.
        let ridge = sprite(CGSize(width: 120, height: 14), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
            ctx.setFillColor(color.darker(0.35).cgColor)
            for k in 0..<8 {
                let x = CGFloat(k) * 15
                ctx.move(to: CGPoint(x: x, y: 14)); ctx.addLine(to: CGPoint(x: x + 7.5, y: 0)); ctx.addLine(to: CGPoint(x: x + 15, y: 14)); ctx.fillPath()
            }
        }
        ridge.position = CGPoint(x: -8, y: 104)
        ridge.zPosition = -0.2
        body.addChild(ridge)
    }

    // MARK: Celtic: Balor's single eye, so heavy it took four men to lift the lid.
    private func evilEye() {
        guard let head = mainHead else { return }
        let lid = sprite(CGSize(width: head.r * 1.4, height: head.r * 0.6), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
            let p = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: s.width, height: s.height * 2))
            fillShaded(ctx, p.cgPath, base: color.darker(0.2), from: 0, to: s.height)
        }
        lid.position = CGPoint(x: head.r * 0.22, y: -head.r * 0.05)
        lid.zPosition = 0.5
        lid.run(.repeatForever(.sequence([
            .scaleY(to: 1.6, duration: 0.6), .wait(forDuration: 1.2), .scaleY(to: 0.25, duration: 0.15), .wait(forDuration: 1.0),
        ])))
        head.addChild(lid)
        // The killing gaze: a beam that flares while the lid is up.
        let beam = SKSpriteNode(texture: dot)
        beam.color = eyeColor.skColor; beam.colorBlendFactor = 1; beam.blendMode = .add
        beam.size = CGSize(width: 260, height: 26)
        beam.anchorPoint = CGPoint(x: 0, y: 0.5)
        beam.position = CGPoint(x: head.r * 0.3, y: -head.r * 0.05)
        beam.alpha = 0
        beam.run(.repeatForever(.sequence([.wait(forDuration: 1.85), .fadeAlpha(to: 0.7, duration: 0.1), .fadeOut(withDuration: 0.6), .wait(forDuration: 0.4)])))
        head.addChild(beam)
    }

    // MARK: Hindu: Vritra, the drought-serpent who hoarded the world's waters in his coils.
    private func hoardedWaters() {
        let water = TextureFactory.image(size: CGSize(width: 40, height: 40)) { ctx in
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 0.7, g: 0.9, b: 1, a: 0.9), RGBA(r: 0.2, g: 0.5, b: 0.9, a: 0.6), RGBA(r: 0.1, g: 0.3, b: 0.7, a: 0)],
                                          center: CGPoint(x: 20, y: 20), radius: 20)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor); ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 8, y: 22)); ctx.addQuadCurve(to: CGPoint(x: 32, y: 22), control: CGPoint(x: 20, y: 14)); ctx.strokePath()
        }
        // The middle coils are swollen with captured rivers.
        for (i, seg) in segments.enumerated() where (4...9).contains(i) {
            seg.setScale(seg.xScale * 1.18)
            let w = SKSpriteNode(texture: water); w.zPosition = 0.3
            w.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.5), .scale(to: 0.9, duration: 0.5)])))
            seg.addChild(w)
        }
        // Thunder-cloud puffs where Indra's storm will break him open.
        for k in 0..<3 {
            let c = glow(RGBA(r: 0.35, g: 0.35, b: 0.45), size: 80, at: CGPoint(x: -60 - CGFloat(k) * 70, y: 120), pulse: false)
            c.blendMode = .alpha
            c.alpha = 0.6
            c.run(.repeatForever(.sequence([.moveBy(x: 10, y: 0, duration: 1), .moveBy(x: -10, y: 0, duration: 1)])))
        }
    }

    // MARK: Sumerian: Humbaba's face of coiled lines; cedar boughs from the forest he guards.
    private func coiledFace() {
        guard let head = mainHead else { return }
        let coils = sprite(CGSize(width: head.r * 2, height: head.r * 2)) { [self] ctx, s in
            ctx.setStrokeColor(color.darker(0.55).cgColor); ctx.setLineWidth(1.6); ctx.setLineCap(.round)
            // One continuous meandering line, as on the clay Humbaba masks.
            let w = s.width
            ctx.move(to: CGPoint(x: w * 0.2, y: w * 0.7))
            ctx.addCurve(to: CGPoint(x: w * 0.8, y: w * 0.7), control1: CGPoint(x: w * 0.3, y: w * 1.0), control2: CGPoint(x: w * 0.7, y: w * 1.0))
            ctx.addCurve(to: CGPoint(x: w * 0.5, y: w * 0.55), control1: CGPoint(x: w * 0.9, y: w * 0.5), control2: CGPoint(x: w * 0.6, y: w * 0.45))
            ctx.addCurve(to: CGPoint(x: w * 0.2, y: w * 0.7), control1: CGPoint(x: w * 0.4, y: w * 0.65), control2: CGPoint(x: w * 0.15, y: w * 0.85))
            ctx.strokePath()
            ctx.addArc(center: CGPoint(x: w * 0.25, y: w * 0.35), radius: w * 0.1, startAngle: 0, endAngle: .pi * 1.6, clockwise: false); ctx.strokePath()
            ctx.addArc(center: CGPoint(x: w * 0.75, y: w * 0.35), radius: w * 0.1, startAngle: .pi, endAngle: .pi * 2.6, clockwise: false); ctx.strokePath()
        }
        coils.zPosition = 0.4
        head.addChild(coils)
        let bough = TextureFactory.image(size: CGSize(width: 60, height: 40)) { ctx in
            ctx.setStrokeColor(RGBA(r: 0.4, g: 0.25, b: 0.15).cgColor); ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: 0, y: 38)); ctx.addLine(to: CGPoint(x: 56, y: 6)); ctx.strokePath()
            ctx.setFillColor(RGBA(r: 0.18, g: 0.42, b: 0.25).cgColor)
            for k in 0..<5 {
                let x = 10 + CGFloat(k) * 10, y = 32 - CGFloat(k) * 6
                ctx.fillEllipse(in: CGRect(x: x - 8, y: y - 10, width: 18, height: 10))
            }
        }
        for side in [-1.0, 1.0] as [CGFloat] {
            let b = SKSpriteNode(texture: bough)
            b.position = CGPoint(x: side * 50, y: 168)
            b.xScale = side
            b.zPosition = -0.5
            body.addChild(b)
        }
    }

    // MARK: Yoruba: Olókun's flood, crested with cowrie shells and bead strands of the deep.
    private func cowrieCrest() {
        let cowrie = TextureFactory.image(size: CGSize(width: 14, height: 18)) { ctx in
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 0.98, b: 0.92), RGBA(r: 0.88, g: 0.82, b: 0.7)], center: CGPoint(x: 6, y: 6), radius: 12)
            ctx.setStrokeColor(RGBA(r: 0.5, g: 0.4, b: 0.3).cgColor); ctx.setLineWidth(1.2)
            ctx.move(to: CGPoint(x: 7, y: 3)); ctx.addLine(to: CGPoint(x: 7, y: 15)); ctx.strokePath()
        }
        // Along the curling lip of the wave.
        let lip: [CGPoint] = [CGPoint(x: -20, y: 214), CGPoint(x: 0, y: 206), CGPoint(x: 16, y: 190), CGPoint(x: 26, y: 168), CGPoint(x: -38, y: 208), CGPoint(x: -56, y: 196)]
        for (i, p) in lip.enumerated() {
            let c = SKSpriteNode(texture: cowrie)
            c.position = p; c.zRotation = CGFloat(i) * 0.4; c.zPosition = 1
            body.addChild(c)
        }
        // Strands of blue and white beads trailing down.
        let beads = TextureFactory.image(size: CGSize(width: 8, height: 70)) { ctx in
            for k in 0..<9 {
                ctx.setFillColor((k % 2 == 0 ? RGBA(r: 0.15, g: 0.3, b: 0.75) : RGBA(r: 0.95, g: 0.95, b: 1)).cgColor)
                ctx.fillEllipse(in: CGRect(x: 0, y: CGFloat(k) * 7.8, width: 8, height: 7))
            }
        }
        for x in [-60.0, -30.0, 0.0] as [CGFloat] {
            let b = SKSpriteNode(texture: beads)
            b.anchorPoint = CGPoint(x: 0.5, y: 1)
            b.position = CGPoint(x: x, y: 190 - abs(x) * 0.3)
            b.zPosition = 1
            b.run(.repeatForever(.sequence([.rotate(toAngle: 0.15, duration: 0.6), .rotate(toAngle: -0.15, duration: 0.6)])))
            body.addChild(b)
        }
    }

    // MARK: Māori: a taniwha with shimmering pāua-shell eyes, as inlaid in carvings.
    private func pauaEyes() {
        guard let head = mainHead else { return }
        let paua = sprite(CGSize(width: head.r * 0.6, height: head.r * 0.6)) { ctx, s in
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 0.5, g: 1, b: 0.85), RGBA(r: 0.2, g: 0.5, b: 0.95), RGBA(r: 0.5, g: 0.2, b: 0.7)],
                                          center: CGPoint(x: s.width * 0.35, y: s.height * 0.35), radius: s.width * 0.55)
            ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: CGRect(x: 1, y: 1, width: s.width - 2, height: s.height - 2))
        }
        paua.position = CGPoint(x: head.r * 0.4, y: head.r * 0.38)
        paua.zPosition = 0.6
        paua.run(.repeatForever(.sequence([.colorize(with: .cyan, colorBlendFactor: 0.4, duration: 0.6),
                                           .colorize(with: .purple, colorBlendFactor: 0.4, duration: 0.6),
                                           .colorize(withColorBlendFactor: 0, duration: 0.6)])))
        head.addChild(paua)
        // Carved koru on the jaw.
        let koru = sprite(CGSize(width: head.r, height: head.r * 0.7)) { [self] ctx, s in
            MotifPainter.band(.koru, in: CGRect(x: 0, y: 0, width: s.width, height: s.height), ctx: ctx, ink: color.lighter(0.6))
        }
        koru.position = CGPoint(x: -head.r * 0.1, y: -head.r * 0.35)
        koru.zPosition = 0.5
        head.addChild(koru)
    }

    // MARK: Chinese: Nian, chased off each New Year by red lanterns and firecrackers.
    private func firecrackers() {
        let string = TextureFactory.image(size: CGSize(width: 16, height: 80)) { ctx in
            ctx.setStrokeColor(RGBA(r: 0.5, g: 0.35, b: 0.2).cgColor); ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: 8, y: 0)); ctx.addLine(to: CGPoint(x: 8, y: 80)); ctx.strokePath()
            for k in 0..<7 {
                let y = 6 + CGFloat(k) * 10.5
                ctx.setFillColor(RGBA(r: 0.85, g: 0.1, b: 0.1).cgColor)
                ctx.addPath(UIBezierPath(roundedRect: CGRect(x: k % 2 == 0 ? 0 : 8, y: y, width: 8, height: 9), cornerRadius: 1.5).cgPath); ctx.fillPath()
                ctx.setFillColor(RGBA(r: 1, g: 0.8, b: 0.2).cgColor)
                ctx.fill(CGRect(x: k % 2 == 0 ? 0 : 8, y: y + 3.5, width: 8, height: 1.5))
            }
        }
        for (i, x) in ([-70.0, 70.0] as [CGFloat]).enumerated() {
            let s = SKSpriteNode(texture: string)
            s.anchorPoint = CGPoint(x: 0.5, y: 1)
            s.position = CGPoint(x: x, y: 170)
            s.zPosition = 3
            s.run(.repeatForever(.sequence([.rotate(toAngle: 0.12, duration: 0.3), .rotate(toAngle: -0.12, duration: 0.3)])))
            body.addChild(s)
            // Pops at the bottom.
            let pop = glow(RGBA(r: 1, g: 0.8, b: 0.3), size: 40, at: CGPoint(x: x, y: 86), pulse: false)
            pop.alpha = 0
            pop.run(.repeatForever(.sequence([.wait(forDuration: 0.3 + Double(i) * 0.25), .fadeAlpha(to: 1, duration: 0.04),
                                              .fadeOut(withDuration: 0.2), .wait(forDuration: 0.4)])))
        }
        // A red lantern nearby: the color Nian fears.
        let lantern = sprite(CGSize(width: 30, height: 40)) { ctx, s in
            ctx.setFillColor(RGBA(r: 0.9, g: 0.1, b: 0.1).cgColor); ctx.fillEllipse(in: CGRect(x: 0, y: 6, width: 30, height: 28))
            ctx.setFillColor(RGBA(r: 1, g: 0.8, b: 0.2).cgColor)
            ctx.fill(CGRect(x: 8, y: 2, width: 14, height: 5)); ctx.fill(CGRect(x: 8, y: 33, width: 14, height: 5))
        }
        lantern.position = CGPoint(x: 120, y: 180)
        lantern.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.8), .moveBy(x: 0, y: -6, duration: 0.8)])))
        body.addChild(lantern)
        _ = glow(RGBA(r: 1, g: 0.4, b: 0.2), size: 70, at: lantern.position)
    }

    // MARK: Maya: Seven Macaw, the false sun, proud of his jewelled teeth and shining eyes.
    private func jewelTeeth() {
        guard let head = mainHead else { return }
        for k in 0..<3 {
            let gem = glow(RGBA(r: 0.4, g: 1, b: 0.8), size: 12, at: CGPoint(x: head.r * (0.8 + CGFloat(k) * 0.18), y: -head.r * 0.05), pulse: false, parent: head)
            gem.zPosition = 1
            gem.run(.repeatForever(.sequence([.wait(forDuration: 0.2 * Double(k)), .scale(to: 1.6, duration: 0.15), .scale(to: 1, duration: 0.3), .wait(forDuration: 0.8)])))
        }
        // A halo of golden rays: his claim to be the sun and moon.
        let rays = sprite(CGSize(width: 150, height: 150)) { ctx, s in
            ctx.setStrokeColor(RGBA(r: 1, g: 0.85, b: 0.3, a: 0.75).cgColor); ctx.setLineWidth(4); ctx.setLineCap(.round)
            for k in 0..<16 {
                let a = CGFloat(k) / 16 * .pi * 2
                ctx.move(to: CGPoint(x: 75 + cos(a) * 40, y: 75 + sin(a) * 40))
                ctx.addLine(to: CGPoint(x: 75 + cos(a) * 70, y: 75 + sin(a) * 70))
            }
            ctx.strokePath()
        }
        rays.position = CGPoint(x: 0, y: 20)
        rays.zPosition = -4
        rays.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 14)))
        body.addChild(rays)
    }

    // MARK: Slavic: Koschei, whose death is a needle in an egg (in a duck, in a hare, in a chest).
    private func needleEgg() {
        let egg = sprite(CGSize(width: 26, height: 34)) { ctx, s in
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 0.98, b: 0.9), RGBA(r: 0.8, g: 0.75, b: 0.65)], center: CGPoint(x: 10, y: 12), radius: 20)
            ctx.setStrokeColor(RGBA(r: 1, g: 0.85, b: 0.3).cgColor); ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: 6, y: 26)); ctx.addLine(to: CGPoint(x: 20, y: 8)); ctx.strokePath()
            ctx.setFillColor(RGBA(r: 1, g: 0.85, b: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: 18, y: 6, width: 4, height: 4))
        }
        if let arm = body.childNode(withName: "armFront") {
            egg.position = CGPoint(x: 72, y: 0)
            egg.zRotation = .pi / 2
            arm.addChild(egg)
        } else {
            egg.position = CGPoint(x: 70, y: 150)
            body.addChild(egg)
        }
        _ = glow(RGBA(r: 1, g: 0.9, b: 0.5), size: 48, at: egg.position, parent: egg.parent)
        // Bones showing through the robe: a ribcage.
        let ribs = sprite(CGSize(width: 50, height: 46)) { ctx, s in
            ctx.setStrokeColor(RGBA(r: 0.92, g: 0.9, b: 0.82, a: 0.85).cgColor); ctx.setLineWidth(2.5); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 25, y: 2)); ctx.addLine(to: CGPoint(x: 25, y: 44)); ctx.strokePath()
            for k in 0..<4 {
                let y = 8 + CGFloat(k) * 10
                ctx.move(to: CGPoint(x: 25, y: y)); ctx.addQuadCurve(to: CGPoint(x: 4, y: y + 8), control: CGPoint(x: 8, y: y)); ctx.strokePath()
                ctx.move(to: CGPoint(x: 25, y: y)); ctx.addQuadCurve(to: CGPoint(x: 46, y: y + 8), control: CGPoint(x: 42, y: y)); ctx.strokePath()
            }
        }
        ribs.position = CGPoint(x: 2, y: 150)
        ribs.zPosition = 0.5
        body.addChild(ribs)
    }

    // MARK: Zulu: Inkanyamba, a great serpent with a horse-like head, riding the summer storms.
    private func horseMane() {
        let serpent = sprite(CGSize(width: 150, height: 150)) { [self] ctx, s in
            ctx.setStrokeColor(color.darker(0.25).cgColor); ctx.setLineWidth(12); ctx.setLineCap(.round)
            ctx.addArc(center: CGPoint(x: 75, y: 75), radius: 55, startAngle: 0, endAngle: .pi * 1.6, clockwise: false)
            ctx.strokePath()
            // Horse-like head with a flowing mane at the end of the coil.
            let hx: CGFloat = 130, hy: CGFloat = 75
            let headPath = UIBezierPath(ovalIn: CGRect(x: hx - 12, y: hy - 30, width: 22, height: 34))
            fillShaded(ctx, headPath.cgPath, base: color.darker(0.1), from: hy - 30, to: hy + 4)
            ctx.setStrokeColor(eyeColor.cgColor); ctx.setLineWidth(3)
            for k in 0..<5 {
                ctx.move(to: CGPoint(x: hx - 10, y: hy - 22 + CGFloat(k) * 6))
                ctx.addQuadCurve(to: CGPoint(x: hx - 34, y: hy - 6 + CGFloat(k) * 8), control: CGPoint(x: hx - 26, y: hy - 26 + CGFloat(k) * 6))
                ctx.strokePath()
            }
            drawEyes(ctx, at: [CGPoint(x: hx + 2, y: hy - 20)], r: 3)
        }
        serpent.position = CGPoint(x: 0, y: 110)
        serpent.zPosition = 1
        serpent.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 2.4)))
        body.addChild(serpent)
    }

    // MARK: Inuit: the Qalupalik, in an amauti parka, long hair, scaled skin, rising through sea ice.
    private func amautik() {
        let hair = sprite(CGSize(width: 70, height: 150), anchor: CGPoint(x: 0.5, y: 1)) { ctx, s in
            ctx.setStrokeColor(RGBA(r: 0.08, g: 0.1, b: 0.12).cgColor); ctx.setLineWidth(3); ctx.setLineCap(.round)
            for k in 0..<7 {
                let x = 10 + CGFloat(k) * 8
                ctx.move(to: CGPoint(x: x, y: 0)); ctx.addCurve(to: CGPoint(x: x - 6, y: 148), control1: CGPoint(x: x + 12, y: 50), control2: CGPoint(x: x - 14, y: 100))
                ctx.strokePath()
            }
        }
        hair.position = CGPoint(x: -16, y: 212)
        hair.zPosition = -0.6
        hair.run(.repeatForever(.sequence([.rotate(toAngle: 0.05, duration: 0.8), .rotate(toAngle: -0.05, duration: 0.8)])))
        body.addChild(hair)
        // The amauti's big back pouch.
        let pouch = sprite(CGSize(width: 60, height: 80)) { [self] ctx, s in
            let p = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 60, height: 80))
            fillShaded(ctx, p.cgPath, base: color.darker(0.05), from: 0, to: 80)
            MotifPainter.band(.furTrim, in: CGRect(x: 0, y: 0, width: 60, height: 12), ctx: ctx, ink: RGBA(r: 0.95, g: 0.93, b: 0.88))
        }
        pouch.position = CGPoint(x: -48, y: 150)
        pouch.zPosition = -0.5
        body.addChild(pouch)
        // Scales on the lower body and cracked sea ice at the base.
        let scales = sprite(CGSize(width: 90, height: 40)) { ctx, s in
            ctx.setStrokeColor(RGBA(r: 0.5, g: 0.8, b: 0.65, a: 0.8).cgColor); ctx.setLineWidth(1.5)
            for row in 0..<3 {
                for k in 0..<6 {
                    let x = 8 + CGFloat(k) * 14 + CGFloat(row % 2) * 7, y = 8 + CGFloat(row) * 11
                    ctx.addArc(center: CGPoint(x: x, y: y), radius: 6, startAngle: 0, endAngle: .pi, clockwise: false); ctx.strokePath()
                }
            }
        }
        scales.position = CGPoint(x: 0, y: 50)
        scales.zPosition = 0.4
        body.addChild(scales)
        let ice = sprite(CGSize(width: 180, height: 30), anchor: CGPoint(x: 0.5, y: 0)) { ctx, s in
            ctx.setFillColor(RGBA(r: 0.85, g: 0.95, b: 1).cgColor)
            ctx.move(to: CGPoint(x: 0, y: 30)); ctx.addLine(to: CGPoint(x: 30, y: 8)); ctx.addLine(to: CGPoint(x: 60, y: 30)); ctx.fillPath()
            ctx.move(to: CGPoint(x: 120, y: 30)); ctx.addLine(to: CGPoint(x: 150, y: 4)); ctx.addLine(to: CGPoint(x: 180, y: 30)); ctx.fillPath()
        }
        ice.zPosition = 2
        body.addChild(ice)
    }

    // MARK: Persian: the White Div, a pale horned giant with a millstone-heavy club.
    private func stoneClub() {
        let club = sprite(CGSize(width: 40, height: 120), anchor: CGPoint(x: 0.5, y: 1)) { ctx, s in
            ctx.setFillColor(RGBA(r: 0.42, g: 0.3, b: 0.2).cgColor)
            ctx.fill(CGRect(x: 16, y: 0, width: 8, height: 70))
            let stone = UIBezierPath(ovalIn: CGRect(x: 0, y: 62, width: 40, height: 56))
            ctx.saveGState(); ctx.addPath(stone.cgPath); ctx.clip()
            TextureFactory.linearGradient(ctx, colors: [RGBA(r: 0.75, g: 0.75, b: 0.72), RGBA(r: 0.4, g: 0.4, b: 0.42)], from: CGPoint(x: 0, y: 62), to: CGPoint(x: 0, y: 118))
            ctx.restoreGState()
            ctx.setFillColor(RGBA(r: 0.3, g: 0.3, b: 0.32).cgColor)
            for p in [CGPoint(x: 12, y: 80), CGPoint(x: 26, y: 96), CGPoint(x: 14, y: 106)] { ctx.fillEllipse(in: CGRect(x: p.x, y: p.y, width: 6, height: 5)) }
        }
        if let arm = body.childNode(withName: "armFront") {
            club.position = CGPoint(x: 0, y: -80)
            club.zPosition = 0.5
            arm.addChild(club)
        }
        // Dark spots on the white hide.
        let spots = sprite(CGSize(width: 100, height: 80)) { [self] ctx, s in
            ctx.setFillColor(color.darker(0.6).withAlpha(0.55).cgColor)
            for p in [CGPoint(x: 10, y: 10), CGPoint(x: 60, y: 6), CGPoint(x: 34, y: 34), CGPoint(x: 78, y: 40), CGPoint(x: 18, y: 58)] {
                ctx.fillEllipse(in: CGRect(x: p.x, y: p.y, width: 14, height: 10))
            }
        }
        spots.position = CGPoint(x: 0, y: 115)
        spots.zPosition = 0.3
        body.addChild(spots)
    }

    // MARK: Hawaiian: a lava surge trailing Pele's hair (glass threads) under a cooling crust.
    private func peleHair() {
        let crust = sprite(CGSize(width: 200, height: 200), anchor: CGPoint(x: 0.75, y: 0)) { ctx, s in
            ctx.setFillColor(RGBA(r: 0.15, g: 0.1, b: 0.1, a: 0.85).cgColor)
            let plates: [CGRect] = [CGRect(x: 40, y: 150, width: 50, height: 22), CGRect(x: 100, y: 120, width: 40, height: 18),
                                    CGRect(x: 70, y: 100, width: 34, height: 16), CGRect(x: 130, y: 170, width: 46, height: 20)]
            for r in plates { ctx.addPath(UIBezierPath(roundedRect: r, cornerRadius: 6).cgPath) }
            ctx.fillPath()
        }
        crust.position = CGPoint(x: 0, y: 20)
        crust.zPosition = 0.5
        body.addChild(crust)
        let threads = SKEmitterNode()
        threads.particleTexture = TextureFactory.image(size: CGSize(width: 2, height: 22)) { ctx in
            ctx.setFillColor(RGBA(r: 1, g: 0.85, b: 0.45).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 22))
        }
        threads.particleBirthRate = 10
        threads.particleLifetime = 2.5
        threads.particlePositionRange = CGVector(dx: 80, dy: 20)
        threads.position = CGPoint(x: 0, y: 220)
        threads.emissionAngle = .pi * 0.7
        threads.particleSpeed = 50
        threads.particleRotationRange = 1.2
        threads.particleRotationSpeed = 1
        threads.particleAlphaSpeed = -0.35
        threads.zPosition = 2
        body.addChild(threads)
    }

    // MARK: Inca: Amaru, the two-headed winged serpent with a feathered crest and fish tail.
    private func featheredSerpent() {
        let feather = TextureFactory.image(size: CGSize(width: 12, height: 28)) { ctx in
            ctx.setFillColor(RGBA(r: 0.1, g: 0.65, b: 0.45).cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 12, height: 28))
            ctx.setFillColor(RGBA(r: 1, g: 0.8, b: 0.15).cgColor)
            ctx.fillEllipse(in: CGRect(x: 3, y: 2, width: 6, height: 8))
        }
        for (i, seg) in segments.enumerated() where i > 0 && i % 2 == 0 {
            let f = SKSpriteNode(texture: feather)
            f.anchorPoint = CGPoint(x: 0.5, y: 0)
            f.position = CGPoint(x: 0, y: 14)
            f.zRotation = 0.5
            f.zPosition = -0.1
            seg.addChild(f)
        }
        // Gold solar disk on the brow, as on Inca metalwork.
        guard let head = mainHead else { return }
        _ = glow(RGBA(r: 1, g: 0.85, b: 0.2), size: head.r * 0.7, at: CGPoint(x: 0, y: head.r * 0.4), parent: head)
    }

    // MARK: Finnish: Louhi as a giant eagle with scythes for talons.
    private func scytheTalons() {
        for x in [-4.0, 14.0] as [CGFloat] {
            let scythe = sprite(CGSize(width: 46, height: 50), anchor: CGPoint(x: 0.2, y: 1)) { ctx, s in
                ctx.setStrokeColor(RGBA(r: 0.45, g: 0.3, b: 0.2).cgColor); ctx.setLineWidth(3)
                ctx.move(to: CGPoint(x: 9, y: 0)); ctx.addLine(to: CGPoint(x: 9, y: 34)); ctx.strokePath()
                let blade = UIBezierPath()
                blade.move(to: CGPoint(x: 8, y: 32))
                blade.addQuadCurve(to: CGPoint(x: 44, y: 48), controlPoint: CGPoint(x: 36, y: 26))
                blade.addQuadCurve(to: CGPoint(x: 8, y: 38), controlPoint: CGPoint(x: 30, y: 36))
                blade.close()
                ctx.setFillColor(RGBA(r: 0.8, g: 0.85, b: 0.9).cgColor)
                ctx.addPath(blade.cgPath); ctx.fillPath()
            }
            scythe.position = CGPoint(x: x, y: -26)
            scythe.zPosition = 0.8
            scythe.run(.repeatForever(.sequence([.rotate(toAngle: 0.3, duration: 0.3), .rotate(toAngle: -0.1, duration: 0.3)])))
            body.addChild(scythe)
        }
        // Iron-grey flight feathers on the back.
        let iron = sprite(CGSize(width: 60, height: 24)) { ctx, s in
            for k in 0..<5 {
                ctx.setFillColor(RGBA(r: 0.45 + 0.05 * Double(k % 2), g: 0.48, b: 0.52).cgColor)
                ctx.fillEllipse(in: CGRect(x: CGFloat(k) * 10, y: 4, width: 16, height: 16))
            }
        }
        iron.position = CGPoint(x: -14, y: 18)
        iron.zPosition = 0.4
        body.addChild(iron)
    }

    // MARK: Akan: Sasabonsam hangs from treetops, dangling long legs with iron hooks for feet.
    private func ironHooks() {
        // Hang high enough that the hooked feet just skim the path.
        extraHover = 115
        let branch = sprite(CGSize(width: 220, height: 30)) { ctx, s in
            ctx.setStrokeColor(RGBA(r: 0.35, g: 0.22, b: 0.12).cgColor); ctx.setLineWidth(12); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 4, y: 20)); ctx.addQuadCurve(to: CGPoint(x: 216, y: 12), control: CGPoint(x: 110, y: 0)); ctx.strokePath()
            ctx.setFillColor(RGBA(r: 0.2, g: 0.45, b: 0.2).cgColor)
            for k in 0..<6 { ctx.fillEllipse(in: CGRect(x: 10 + CGFloat(k) * 36, y: 0, width: 26, height: 14)) }
        }
        branch.position = CGPoint(x: 0, y: 262)
        branch.zPosition = -1
        body.addChild(branch)
        for side in [-1.0, 1.0] as [CGFloat] {
            let leg = sprite(CGSize(width: 34, height: 160), anchor: CGPoint(x: 0.5, y: 1)) { [self] ctx, s in
                ctx.setStrokeColor(color.darker(0.3).cgColor); ctx.setLineWidth(6); ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: 17, y: 0)); ctx.addLine(to: CGPoint(x: 17, y: 138)); ctx.strokePath()
                // Iron hook.
                ctx.setStrokeColor(RGBA(r: 0.55, g: 0.57, b: 0.6).cgColor); ctx.setLineWidth(4)
                ctx.addArc(center: CGPoint(x: 24, y: 144), radius: 8, startAngle: .pi, endAngle: .pi * 0.1, clockwise: true)
                ctx.strokePath()
            }
            leg.position = CGPoint(x: side * 18, y: 40)
            leg.zPosition = side > 0 ? 0.3 : -0.3
            leg.run(.repeatForever(.sequence([.rotate(toAngle: 0.18 * side, duration: 0.5), .rotate(toAngle: -0.12 * side, duration: 0.5)])))
            body.addChild(leg)
        }
    }

    // MARK: Mongolian: the many-headed Mangus, armored in lamellar plates like the steppe riders it fought.
    private func lamellarArmor() {
        let armor = sprite(CGSize(width: 100, height: 54)) { ctx, s in
            for row in 0..<4 {
                for k in 0..<9 {
                    let x = CGFloat(k) * 11 + CGFloat(row % 2) * 5.5, y = CGFloat(row) * 13
                    let r = CGRect(x: x, y: y, width: 10, height: 14)
                    ctx.setFillColor(RGBA(r: 0.55, g: 0.42, b: 0.25).cgColor)
                    ctx.addPath(UIBezierPath(roundedRect: r, cornerRadius: 3).cgPath); ctx.fillPath()
                    ctx.setFillColor(RGBA(r: 0.85, g: 0.7, b: 0.4).cgColor)
                    ctx.fillEllipse(in: CGRect(x: x + 3.5, y: y + 3, width: 3, height: 3))
                }
            }
        }
        armor.position = CGPoint(x: 0, y: 128)
        armor.zPosition = 0.4
        body.addChild(armor)
    }

    // MARK: Hittite: Illuyanka, who stole the Storm God's heart and eyes. They glow in its coils.
    private func stolenHeart() {
        guard segments.count > 6 else { return }
        let heart = sprite(CGSize(width: 26, height: 24)) { ctx, s in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 13, y: 22))
            p.addCurve(to: CGPoint(x: 13, y: 6), controlPoint1: CGPoint(x: -4, y: 12), controlPoint2: CGPoint(x: 4, y: -4))
            p.addCurve(to: CGPoint(x: 13, y: 22), controlPoint1: CGPoint(x: 22, y: -4), controlPoint2: CGPoint(x: 30, y: 12))
            ctx.setFillColor(RGBA(r: 1, g: 0.25, b: 0.3).cgColor); ctx.addPath(p.cgPath); ctx.fillPath()
        }
        heart.zPosition = 0.5
        heart.run(.repeatForever(.sequence([.scale(to: 1.3, duration: 0.15), .scale(to: 1, duration: 0.15), .wait(forDuration: 0.4)])))
        segments[5].addChild(heart)
        _ = glow(RGBA(r: 1, g: 0.3, b: 0.3), size: 50, at: .zero, parent: segments[5])
        // The two stolen eyes, held in a lower coil.
        for dx in [-8.0, 8.0] as [CGFloat] {
            _ = glow(RGBA(r: 0.6, g: 0.85, b: 1), size: 16, at: CGPoint(x: dx, y: 0), parent: segments[8]).zPosition = 0.5
        }
    }

    // MARK: Rapa Nui: the Birdman race, in which a manutara (sooty tern) egg had to be brought back first.
    private func firstEgg() {
        guard let head = mainHead else { return }
        let egg = sprite(CGSize(width: 18, height: 22)) { ctx, s in
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 0.98, g: 0.95, b: 0.88), RGBA(r: 0.82, g: 0.76, b: 0.66)], center: CGPoint(x: 7, y: 8), radius: 14)
            ctx.setFillColor(RGBA(r: 0.45, g: 0.32, b: 0.25).cgColor)
            for p in [CGPoint(x: 5, y: 8), CGPoint(x: 11, y: 12), CGPoint(x: 7, y: 16), CGPoint(x: 12, y: 6)] { ctx.fillEllipse(in: CGRect(x: p.x, y: p.y, width: 2.5, height: 2)) }
        }
        egg.position = CGPoint(x: head.r * 1.5, y: -head.r * 0.2)
        egg.zPosition = 1
        head.addChild(egg)
        // A tangata manu (birdman) petroglyph carved on the wing root.
        let glyph = sprite(CGSize(width: 30, height: 30)) { ctx, s in
            ctx.setStrokeColor(RGBA(r: 1, g: 0.95, b: 0.85, a: 0.85).cgColor); ctx.setLineWidth(2); ctx.setLineCap(.round)
            ctx.strokeEllipse(in: CGRect(x: 10, y: 2, width: 10, height: 10))
            ctx.move(to: CGPoint(x: 20, y: 7)); ctx.addLine(to: CGPoint(x: 28, y: 12)); ctx.strokePath()
            ctx.move(to: CGPoint(x: 15, y: 12)); ctx.addLine(to: CGPoint(x: 15, y: 22)); ctx.strokePath()
            ctx.move(to: CGPoint(x: 6, y: 18)); ctx.addLine(to: CGPoint(x: 15, y: 15)); ctx.addLine(to: CGPoint(x: 24, y: 18)); ctx.strokePath()
            ctx.move(to: CGPoint(x: 15, y: 22)); ctx.addLine(to: CGPoint(x: 8, y: 29)); ctx.strokePath()
            ctx.move(to: CGPoint(x: 15, y: 22)); ctx.addLine(to: CGPoint(x: 22, y: 29)); ctx.strokePath()
        }
        glyph.position = CGPoint(x: -12, y: 4)
        glyph.zPosition = 0.6
        body.addChild(glyph)
    }

    // MARK: Taíno: Juracán drawn as the zemí of Guabancex: a face with two arms spiraling opposite ways.
    private func zemiArms() {
        let zemi = SKNode()
        zemi.position = CGPoint(x: 0, y: 120)
        zemi.zPosition = 2
        let face = sprite(CGSize(width: 46, height: 46)) { [self] ctx, s in
            let p = UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 40, height: 40))
            fillShaded(ctx, p.cgPath, base: color.lighter(0.15), from: 3, to: 43)
            drawEyes(ctx, at: [CGPoint(x: 16, y: 20), CGPoint(x: 30, y: 20)], r: 3.5)
            ctx.setStrokeColor(color.darker(0.5).cgColor); ctx.setLineWidth(2)
            ctx.strokeEllipse(in: CGRect(x: 17, y: 28, width: 12, height: 7))
        }
        zemi.addChild(face)
        for side in [-1.0, 1.0] as [CGFloat] {
            let arm = sprite(CGSize(width: 90, height: 90)) { [self] ctx, s in
                ctx.setStrokeColor(color.lighter(0.2).cgColor); ctx.setLineWidth(8); ctx.setLineCap(.round)
                let steps = 40
                for k in 0...steps {
                    let t = CGFloat(k) / CGFloat(steps)
                    let a = t * .pi * 2.4
                    let r = 42 * (1 - t * 0.85)
                    let p = CGPoint(x: 45 + cos(a) * r, y: 45 + sin(a) * r)
                    k == 0 ? ctx.move(to: p) : ctx.addLine(to: p)
                }
                ctx.strokePath()
            }
            arm.position = CGPoint(x: side * 50, y: side * 6)
            arm.xScale = side
            zemi.addChild(arm)
        }
        zemi.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3)))
        body.addChild(zemi)
    }

    // MARK: Etruscan: the bronze Chimera of Arezzo: a goat's head rising from the lion's back.
    private func goatAndSerpent() {
        let goat = sprite(CGSize(width: 60, height: 70), anchor: CGPoint(x: 0.3, y: 0)) { [self] ctx, s in
            ctx.setFillColor(color.darker(0.1).cgColor)
            ctx.fill(CGRect(x: 10, y: 34, width: 14, height: 36))
            let headPath = UIBezierPath(ovalIn: CGRect(x: 6, y: 14, width: 34, height: 26))
            fillShaded(ctx, headPath.cgPath, base: color.lighter(0.05), from: 14, to: 40)
            // Swept-back horns and a beard.
            ctx.setStrokeColor(RGBA(r: 0.85, g: 0.78, b: 0.6).cgColor); ctx.setLineWidth(4); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 16, y: 16)); ctx.addQuadCurve(to: CGPoint(x: 0, y: 2), control: CGPoint(x: 14, y: 0)); ctx.strokePath()
            ctx.setFillColor(color.darker(0.4).cgColor)
            ctx.move(to: CGPoint(x: 30, y: 38)); ctx.addLine(to: CGPoint(x: 36, y: 52)); ctx.addLine(to: CGPoint(x: 38, y: 36)); ctx.fillPath()
            drawEyes(ctx, at: [CGPoint(x: 28, y: 24)], r: 3)
        }
        goat.position = CGPoint(x: -10, y: 96)
        goat.zPosition = -0.3
        goat.run(.repeatForever(.sequence([.rotate(toAngle: 0.15, duration: 0.4), .rotate(toAngle: -0.05, duration: 0.4)])))
        body.addChild(goat)
        // The wound on the goat's neck from Bellerophon, as cast on the bronze.
        _ = glow(RGBA(r: 0.9, g: 0.2, b: 0.15), size: 14, at: CGPoint(x: -4, y: 114))
        // Bronze sheen sweeping over the body.
        let sheen = SKSpriteNode(texture: dot)
        sheen.color = RGBA(r: 1, g: 0.85, b: 0.6).skColor; sheen.colorBlendFactor = 1; sheen.blendMode = .add
        sheen.size = CGSize(width: 40, height: 90); sheen.alpha = 0.35; sheen.position = CGPoint(x: -70, y: 70); sheen.zPosition = 1
        sheen.run(.repeatForever(.sequence([.moveTo(x: 80, duration: 1.4), .moveTo(x: -70, duration: 0)])))
        body.addChild(sheen)
    }

    // MARK: Dogon: the Harmattan, a towering dust wall; above it, the bright star the Dogon call sigi tolo.
    private func dustStar() {
        let wall = sprite(CGSize(width: 220, height: 240), anchor: CGPoint(x: 0.5, y: 0)) { [self] ctx, s in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 0, y: 240))
            for k in 0...8 {
                let x = CGFloat(k) * 27.5
                p.addQuadCurve(to: CGPoint(x: x, y: 20 + CGFloat(k % 3) * 18), controlPoint: CGPoint(x: x - 14, y: CGFloat(k % 2) * 30))
            }
            p.addLine(to: CGPoint(x: 220, y: 240)); p.close()
            ctx.saveGState(); ctx.addPath(p.cgPath); ctx.clip()
            TextureFactory.linearGradient(ctx, colors: [color.lighter(0.3).withAlpha(0.7), color.withAlpha(0.95)], from: .zero, to: CGPoint(x: 0, y: 240))
            ctx.restoreGState()
            motifBand(ctx, clip: p.cgPath, band: CGRect(x: 0, y: 130, width: 220, height: 20), alpha: 0.5)
        }
        wall.zPosition = -1
        wall.run(.repeatForever(.sequence([.moveBy(x: 8, y: 0, duration: 0.6), .moveBy(x: -8, y: 0, duration: 0.6)])))
        body.addChild(wall)
        let star = sprite(CGSize(width: 40, height: 40)) { ctx, s in
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.move(to: CGPoint(x: 20, y: 0)); ctx.addLine(to: CGPoint(x: 23, y: 17)); ctx.addLine(to: CGPoint(x: 40, y: 20))
            ctx.addLine(to: CGPoint(x: 23, y: 23)); ctx.addLine(to: CGPoint(x: 20, y: 40)); ctx.addLine(to: CGPoint(x: 17, y: 23))
            ctx.addLine(to: CGPoint(x: 0, y: 20)); ctx.addLine(to: CGPoint(x: 17, y: 17)); ctx.closePath(); ctx.fillPath()
        }
        star.position = CGPoint(x: 30, y: 270)
        star.run(.repeatForever(.sequence([.scale(to: 1.4, duration: 0.5), .scale(to: 0.8, duration: 0.5)])))
        body.addChild(star)
        _ = glow(RGBA(r: 0.8, g: 0.9, b: 1), size: 60, at: star.position)
    }

    // MARK: Ainu: a northern blizzard with a frozen face, icicle fangs and frost in ayus curls.
    private func iceFangs() {
        let face = sprite(CGSize(width: 110, height: 70)) { [self] ctx, s in
            let p = UIBezierPath(ovalIn: CGRect(x: 5, y: 0, width: 100, height: 56))
            ctx.setFillColor(RGBA(r: 0.85, g: 0.93, b: 1, a: 0.85).cgColor); ctx.addPath(p.cgPath); ctx.fillPath()
            MotifPainter.band(.ayus, in: CGRect(x: 5, y: 4, width: 100, height: 14), ctx: ctx, ink: RGBA(r: 0.4, g: 0.6, b: 0.85))
            drawEyes(ctx, at: [CGPoint(x: 38, y: 28), CGPoint(x: 72, y: 28)], r: 5)
            ctx.setFillColor(RGBA(r: 0.95, g: 1, b: 1).cgColor)
            for k in 0..<6 {
                let x = 26 + CGFloat(k) * 11
                ctx.move(to: CGPoint(x: x, y: 44)); ctx.addLine(to: CGPoint(x: x + 5, y: 68 - CGFloat(k % 2) * 8)); ctx.addLine(to: CGPoint(x: x + 10, y: 44)); ctx.fillPath()
            }
        }
        face.position = CGPoint(x: 0, y: 130)
        face.zPosition = 2
        face.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 0.7), .moveBy(x: 0, y: -8, duration: 0.7)])))
        body.addChild(face)
    }

    // MARK: Guaraní: Teju Jagua, seven dog heads with fiery eyes, guarding hidden treasure.
    private func treasureHoard() {
        let hoard = sprite(CGSize(width: 120, height: 34), anchor: CGPoint(x: 0.5, y: 0)) { ctx, s in
            let gems: [(CGFloat, CGFloat, RGBA)] = [(12, 20, RGBA(r: 1, g: 0.8, b: 0.2)), (30, 14, RGBA(r: 0.2, g: 0.8, b: 0.5)),
                                                    (50, 22, RGBA(r: 1, g: 0.85, b: 0.3)), (70, 12, RGBA(r: 0.9, g: 0.2, b: 0.3)),
                                                    (92, 20, RGBA(r: 1, g: 0.8, b: 0.2)), (108, 16, RGBA(r: 0.3, g: 0.5, b: 1))]
            for (x, y, c) in gems {
                TextureFactory.radialGradient(ctx, colors: [c.lighter(0.5), c, c.darker(0.3)], center: CGPoint(x: x, y: y), radius: 9)
            }
        }
        hoard.zPosition = 1
        body.addChild(hoard)
        // Fire flickers in each head's eyes.
        for head in heads {
            let fire = glow(RGBA(r: 1, g: 0.4, b: 0.1), size: head.r * 0.8, at: CGPoint(x: head.r * 0.15, y: head.r * 0.3), pulse: false, parent: head)
            fire.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.12), .fadeAlpha(to: 1, duration: 0.18)])))
        }
    }

    // MARK: Filipino: Bakunawa, the sea serpent that swallows the moon during eclipses.
    private func moonInMouth() {
        guard let head = mainHead else { return }
        let moon = sprite(CGSize(width: 44, height: 44)) { ctx, s in
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 1, b: 0.95), RGBA(r: 0.85, g: 0.85, b: 0.8)], center: CGPoint(x: 18, y: 18), radius: 22)
            ctx.setFillColor(RGBA(r: 0.7, g: 0.7, b: 0.68).cgColor)
            for c in [CGRect(x: 10, y: 12, width: 8, height: 6), CGRect(x: 24, y: 24, width: 10, height: 8), CGRect(x: 26, y: 8, width: 5, height: 5)] { ctx.fillEllipse(in: c) }
        }
        moon.position = CGPoint(x: head.r * 1.6, y: head.r * 0.05)
        moon.zPosition = -0.2
        head.addChild(moon)
        _ = glow(RGBA(r: 0.85, g: 0.9, b: 1), size: 80, at: moon.position, parent: head).zPosition = -0.3
        // Fins and gills along the body.
        let fin = TextureFactory.image(size: CGSize(width: 22, height: 20)) { [self] ctx in
            ctx.setFillColor(eyeColor.mixed(with: color, 0.4).withAlpha(0.9).cgColor)
            ctx.move(to: CGPoint(x: 0, y: 20)); ctx.addQuadCurve(to: CGPoint(x: 22, y: 0), control: CGPoint(x: 4, y: 0)); ctx.addLine(to: CGPoint(x: 18, y: 20)); ctx.fillPath()
        }
        for (i, seg) in segments.enumerated() where i > 0 && i % 3 == 1 {
            let f = SKSpriteNode(texture: fin)
            f.anchorPoint = CGPoint(x: 0.5, y: 0)
            f.position = CGPoint(x: 0, y: 16)
            f.zPosition = -0.1
            f.run(.repeatForever(.sequence([.scaleY(to: 0.7, duration: 0.3), .scaleY(to: 1, duration: 0.3)])))
            seg.addChild(f)
        }
    }

    // MARK: San: the All-Devourer, a mouth that swallows everything, starry darkness inside.
    private func starMaw() {
        let maw = sprite(CGSize(width: 110, height: 90)) { [self] ctx, s in
            let p = UIBezierPath(ovalIn: CGRect(x: 4, y: 4, width: 102, height: 82))
            ctx.setFillColor(RGBA(r: 0.03, g: 0.02, b: 0.08).cgColor); ctx.addPath(p.cgPath); ctx.fillPath()
            ctx.setFillColor(UIColor.white.cgColor)
            for k in 0..<18 {
                let x = 18 + CGFloat((k * 37) % 76), y = 16 + CGFloat((k * 53) % 58)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: k % 4 == 0 ? 3 : 1.6, height: k % 4 == 0 ? 3 : 1.6))
            }
            // Teeth around the rim.
            ctx.setFillColor(RGBA(r: 0.95, g: 0.92, b: 0.85).cgColor)
            for k in 0..<10 {
                let a = CGFloat(k) / 10 * .pi * 2
                let cx = 55 + cos(a) * 46, cy = 45 + sin(a) * 37
                let ix = 55 + cos(a) * 34, iy = 45 + sin(a) * 27
                ctx.move(to: CGPoint(x: cx + sin(a) * 5, y: cy - cos(a) * 5)); ctx.addLine(to: CGPoint(x: ix, y: iy))
                ctx.addLine(to: CGPoint(x: cx - sin(a) * 5, y: cy + cos(a) * 5)); ctx.fillPath()
            }
            ctx.setStrokeColor(color.lighter(0.3).cgColor); ctx.setLineWidth(3)
            ctx.addPath(p.cgPath); ctx.strokePath()
        }
        maw.position = CGPoint(x: 6, y: 120)
        maw.zPosition = 1
        maw.run(.repeatForever(.sequence([.scaleY(to: 1.25, duration: 0.5), .scaleY(to: 0.85, duration: 0.5)])))
        body.addChild(maw)
        // Little trees being pulled into the mouth.
        let tree = TextureFactory.image(size: CGSize(width: 18, height: 24)) { ctx in
            ctx.setFillColor(RGBA(r: 0.35, g: 0.25, b: 0.15).cgColor); ctx.fill(CGRect(x: 8, y: 14, width: 3, height: 10))
            ctx.setFillColor(RGBA(r: 0.3, g: 0.5, b: 0.25).cgColor); ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 18, height: 16))
        }
        for k in 0..<3 {
            let t = SKSpriteNode(texture: tree)
            t.position = CGPoint(x: 110, y: 90 + CGFloat(k) * 20)
            t.run(.repeatForever(.sequence([.wait(forDuration: 0.5 * Double(k)),
                                            .group([.move(to: maw.position, duration: 1.2), .scale(to: 0.1, duration: 1.2), .rotate(byAngle: 3, duration: 1.2)]),
                                            .run { t.position = CGPoint(x: 110, y: 90 + CGFloat(k) * 20); t.setScale(1) }])))
            body.addChild(t)
        }
    }
}
