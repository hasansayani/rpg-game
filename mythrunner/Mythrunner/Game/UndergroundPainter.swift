import CoreGraphics
import UIKit

/// What lies under the path: soil layers, roots, buried pottery, mythical fossils, caves with
/// hibernating animals, lava tubes… drawn into each terrain chunk (y down, already clipped to the ground).
/// Deterministic for a given chunk and run, so a chunk looks the same each time it is redrawn.
enum UndergroundPainter {
    enum Feature { case ammonite, fish, giantRibs, griffinSkull, dragonBones, serpentSpine, pottery, coins,
                   cave, lavaTube, frozenMammoth, shells, amphora, starfish }

    /// The realm's own fossil, tied to its myths where there's a real link.
    static func signatureFossil(_ realmID: String) -> Feature? {
        switch realmID {
        // Protoceratops skulls in the Gobi are thought to have inspired griffin legends.
        case "greek", "mongolian", "persian": return .griffinSkull
        // Fossil bones were long sold as "dragon bones" in China.
        case "chinese", "japanese", "filipino": return .dragonBones
        case "norse", "maori", "zulu": return .serpentSpine
        default: return nil
        }
    }

    static func features(biome: Biome, water: Bool) -> [Feature] {
        if water { return [.shells, .starfish, .amphora, .shells, .ammonite] }
        switch biome {
        case .volcanic: return [.lavaTube, .lavaTube, .ammonite]
        case .tundra: return [.frozenMammoth, .cave, .ammonite]
        case .market, .farmland: return [.pottery, .coins, .pottery, .giantRibs, .cave]
        case .desert: return [.pottery, .fish, .cave, .giantRibs, .coins]
        case .forest, .jungle: return [.cave, .ammonite, .giantRibs, .pottery]
        case .mountain: return [.cave, .ammonite, .fish, .giantRibs]
        case .savanna, .steppe: return [.giantRibs, .cave, .pottery, .fish]
        case .coast: return [.shells, .fish, .ammonite, .cave]
        }
    }

    static func draw(ctx: CGContext, width: CGFloat, height: CGFloat, surface: (CGFloat) -> CGFloat?,
                     biome: Biome, realmID: String, water: Bool, ground: RGBA, edge: RGBA, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        let soil = ground.mixed(with: edge, 0.5)
        // Bone reads as pale on dark ground and as weathered brown on pale ground (sand, snow).
        let bone = ground.luminance > 0.55 ? ground.mixed(with: RGBA(r: 0.4, g: 0.3, b: 0.2), 0.55)
                                           : RGBA(r: 0.93, g: 0.89, b: 0.78).mixed(with: ground, 0.2)

        // Soil strata following the surface.
        for (depth, darken) in [(70.0, 0.12), (140.0, 0.2)] as [(CGFloat, Double)] {
            ctx.setStrokeColor(soil.darker(darken).withAlpha(0.45).cgColor)
            ctx.setLineWidth(3)
            var started = false
            for x in stride(from: CGFloat(0), through: width, by: 12) {
                guard let s = surface(x) else { started = false; continue }
                let p = CGPoint(x: x, y: s + depth + 6 * sin(x / 37 + depth))
                if started { ctx.addLine(to: p) } else { ctx.move(to: p); started = true }
            }
            ctx.strokePath()
        }

        // Roots under forests and jungles.
        if biome == .forest || biome == .jungle || biome == .farmland, !water {
            ctx.setStrokeColor(RGBA(r: 0.42, g: 0.3, b: 0.2).withAlpha(0.55).cgColor)
            ctx.setLineCap(.round)
            for _ in 0..<3 {
                let x = CGFloat(rng.range(20, Double(width) - 20))
                guard let s = surface(x) else { continue }
                ctx.setLineWidth(2)
                ctx.move(to: CGPoint(x: x, y: s + 4))
                ctx.addCurve(to: CGPoint(x: x + 14, y: s + 46), control1: CGPoint(x: x - 10, y: s + 18), control2: CGPoint(x: x + 20, y: s + 28))
                ctx.strokePath()
                ctx.setLineWidth(1)
                ctx.move(to: CGPoint(x: x + 2, y: s + 20)); ctx.addLine(to: CGPoint(x: x - 14, y: s + 34)); ctx.strokePath()
            }
        }

        // Pebbles scattered through the soil.
        ctx.setFillColor(soil.darker(0.25).withAlpha(0.5).cgColor)
        for _ in 0..<10 {
            let x = CGFloat(rng.range(0, Double(width)))
            guard let s = surface(x) else { continue }
            let y = s + CGFloat(rng.range(25, 190))
            let r = CGFloat(rng.range(1.5, 4))
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: r * 1.6, height: r))
        }

        // Two or three larger finds per chunk.
        var options = features(biome: biome, water: water)
        if let sig = signatureFossil(realmID) { options += [sig, sig] }
        let count = 3 + Int(rng.next() % 2)
        var used: [CGFloat] = []
        for _ in 0..<count {
            let x = CGFloat(rng.range(70, Double(width) - 70))
            guard !used.contains(where: { abs($0 - x) < 120 }), let s = surface(x) else { continue }
            let feature = options[Int(rng.next() % UInt64(options.count))]
            let depth: CGFloat = water ? CGFloat(rng.range(18, 40))
                : feature == .cave || feature == .lavaTube ? CGFloat(rng.range(85, 130)) : CGFloat(rng.range(45, 150))
            let c = CGPoint(x: x, y: min(s + depth, height - 30))
            guard c.y > s + 12 else { continue }
            used.append(x)
            draw(feature, at: c, ctx: ctx, rng: &rng, bone: bone, soil: soil, realmID: realmID, biome: biome)
        }
    }

    private static func draw(_ f: Feature, at c: CGPoint, ctx: CGContext, rng: inout SeededRandom,
                             bone: RGBA, soil: RGBA, realmID: String, biome: Biome) {
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let flip: CGFloat = rng.unit() < 0.5 ? 1 : -1
        switch f {
        case .ammonite:
            ctx.setStrokeColor(bone.cgColor)
            ctx.setLineWidth(2.2)
            var first = true
            for s in 0...60 {
                let t = CGFloat(s) / 60
                let a = t * .pi * 5
                let r = 16 * (1 - t * 0.9)
                let p = CGPoint(x: c.x + cos(a) * r * flip, y: c.y + sin(a) * r)
                if first { ctx.move(to: p); first = false } else { ctx.addLine(to: p) }
            }
            ctx.strokePath()
            ctx.setLineWidth(1)
            for k in 0..<10 {
                let a = CGFloat(k) / 10 * .pi * 2
                ctx.move(to: CGPoint(x: c.x + cos(a) * 9, y: c.y + sin(a) * 9))
                ctx.addLine(to: CGPoint(x: c.x + cos(a) * 15, y: c.y + sin(a) * 15))
                ctx.strokePath()
            }
        case .fish:
            ctx.setStrokeColor(bone.cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: c.x - 26 * flip, y: c.y)); ctx.addLine(to: CGPoint(x: c.x + 20 * flip, y: c.y)); ctx.strokePath()
            ctx.setLineWidth(1.2)
            for k in 0..<7 {
                let x = c.x + (CGFloat(k) * 6 - 18) * flip
                let h = 9 - abs(CGFloat(k) - 3) * 1.6
                ctx.move(to: CGPoint(x: x, y: c.y - h)); ctx.addLine(to: CGPoint(x: x + 3 * flip, y: c.y)); ctx.addLine(to: CGPoint(x: x, y: c.y + h)); ctx.strokePath()
            }
            ctx.setFillColor(bone.cgColor)
            ctx.fillEllipse(in: CGRect(x: c.x + 18 * flip - 5, y: c.y - 5, width: 10, height: 10))
            ctx.move(to: CGPoint(x: c.x - 26 * flip, y: c.y)); ctx.addLine(to: CGPoint(x: c.x - 34 * flip, y: c.y - 7))
            ctx.addLine(to: CGPoint(x: c.x - 34 * flip, y: c.y + 7)); ctx.closePath(); ctx.fillPath()
        case .giantRibs:
            // A giant's (or great beast's) ribcage and a long bone.
            ctx.setStrokeColor(bone.cgColor)
            ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: c.x - 34, y: c.y - 6)); ctx.addLine(to: CGPoint(x: c.x + 34, y: c.y - 10)); ctx.strokePath()
            for k in 0..<6 {
                let x = c.x - 28 + CGFloat(k) * 11
                ctx.move(to: CGPoint(x: x, y: c.y - 7))
                ctx.addQuadCurve(to: CGPoint(x: x + 6, y: c.y + 18), control: CGPoint(x: x - 10, y: c.y + 8))
                ctx.strokePath()
            }
            ctx.setLineWidth(4)
            ctx.move(to: CGPoint(x: c.x - 40, y: c.y + 26)); ctx.addLine(to: CGPoint(x: c.x + 6, y: c.y + 30)); ctx.strokePath()
            ctx.setFillColor(bone.cgColor)
            for e in [CGPoint(x: c.x - 40, y: c.y + 26), CGPoint(x: c.x + 6, y: c.y + 30)] {
                ctx.fillEllipse(in: CGRect(x: e.x - 4, y: e.y - 5, width: 8, height: 10))
            }
        case .griffinSkull:
            // A beaked skull with a bony frill: the fossils that may have inspired the griffin.
            ctx.setFillColor(bone.cgColor)
            let s = UIBezierPath()
            s.move(to: CGPoint(x: c.x - 22 * flip, y: c.y - 14))
            s.addQuadCurve(to: CGPoint(x: c.x + 8 * flip, y: c.y - 10), controlPoint: CGPoint(x: c.x - 6 * flip, y: c.y - 26))
            s.addQuadCurve(to: CGPoint(x: c.x + 26 * flip, y: c.y + 6), controlPoint: CGPoint(x: c.x + 24 * flip, y: c.y - 10))
            s.addLine(to: CGPoint(x: c.x + 8 * flip, y: c.y + 8))
            s.addQuadCurve(to: CGPoint(x: c.x - 22 * flip, y: c.y - 14), controlPoint: CGPoint(x: c.x - 14 * flip, y: c.y + 6))
            ctx.addPath(s.cgPath); ctx.fillPath()
            ctx.setFillColor(soil.darker(0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: c.x + 2 * flip - 4, y: c.y - 8, width: 8, height: 7))
            ctx.fillEllipse(in: CGRect(x: c.x - 12 * flip - 5, y: c.y - 14, width: 10, height: 6))
            // A few vertebrae trailing off.
            ctx.setFillColor(bone.withAlpha(0.85).cgColor)
            for k in 0..<5 { ctx.fillEllipse(in: CGRect(x: c.x - (30 + CGFloat(k) * 9) * flip - 3, y: c.y - 8 + CGFloat(k) * 2, width: 6, height: 5)) }
        case .dragonBones, .serpentSpine:
            // A long curving spine with ribs (and, for dragons, a horned skull).
            ctx.setFillColor(bone.cgColor)
            ctx.setStrokeColor(bone.cgColor)
            ctx.setLineWidth(1.6)
            var pts: [CGPoint] = []
            for k in 0..<14 {
                let t = CGFloat(k) / 13
                pts.append(CGPoint(x: c.x + (t * 110 - 55) * flip, y: c.y + sin(t * .pi * 2) * 14))
            }
            for (k, p) in pts.enumerated() {
                ctx.fillEllipse(in: CGRect(x: p.x - 3.5, y: p.y - 3, width: 7, height: 6))
                if f == .dragonBones || k % 2 == 0 {
                    ctx.move(to: p); ctx.addLine(to: CGPoint(x: p.x - 2 * flip, y: p.y + 10)); ctx.strokePath()
                }
            }
            if f == .dragonBones, let head = pts.last {
                let h = CGPoint(x: head.x + 10 * flip, y: head.y)
                ctx.fillEllipse(in: CGRect(x: h.x - 10, y: h.y - 7, width: 20, height: 14))
                ctx.move(to: CGPoint(x: h.x, y: h.y - 5)); ctx.addLine(to: CGPoint(x: h.x - 12 * flip, y: h.y - 18)); ctx.strokePath()
                ctx.setFillColor(soil.darker(0.4).cgColor)
                ctx.fillEllipse(in: CGRect(x: h.x + 2 * flip - 2.5, y: h.y - 4, width: 5, height: 4))
            }
        case .pottery:
            let clay = RGBA(r: 0.72, g: 0.42, b: 0.26)
            ctx.setFillColor(clay.cgColor)
            for k in 0..<4 {
                let o = CGPoint(x: c.x + CGFloat(k) * 10 - 15, y: c.y + CGFloat(k % 2) * 6)
                ctx.move(to: o); ctx.addLine(to: CGPoint(x: o.x + 9, y: o.y + 2)); ctx.addLine(to: CGPoint(x: o.x + 4, y: o.y + 8)); ctx.closePath(); ctx.fillPath()
            }
            ctx.setStrokeColor(clay.darker(0.3).cgColor); ctx.setLineWidth(1)
            ctx.strokeEllipse(in: CGRect(x: c.x - 12, y: c.y - 16, width: 24, height: 12))
        case .coins:
            for k in 0..<6 {
                let p = CGPoint(x: c.x + CGFloat(rng.range(-18, 18)), y: c.y + CGFloat(rng.range(-8, 8)))
                ctx.setFillColor(RGBA(r: 0.92, g: 0.74, b: 0.25).withAlpha(0.95).cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 2.2, width: 8, height: 4.4))
                if k == 0 {
                    ctx.setFillColor(RGBA(r: 1, g: 0.95, b: 0.7).cgColor)
                    ctx.fillEllipse(in: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 1.4))
                }
            }
        case .cave:
            // A hollow with stalactites, and an animal sleeping through the season.
            let w: CGFloat = 96, h: CGFloat = 52
            let hollow = UIBezierPath(ovalIn: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
            ctx.saveGState()
            ctx.addPath(hollow.cgPath); ctx.clip()
            TextureFactory.radialGradient(ctx, colors: [soil.darker(0.45), soil.darker(0.7)], center: CGPoint(x: c.x, y: c.y + 10), radius: w / 2)
            ctx.restoreGState()
            ctx.setFillColor(soil.darker(0.15).cgColor)
            for k in 0..<5 {
                let x = c.x - 34 + CGFloat(k) * 17
                let len = CGFloat(6 + (k * 7) % 11)
                ctx.move(to: CGPoint(x: x - 4, y: c.y - h / 2 + 4)); ctx.addLine(to: CGPoint(x: x, y: c.y - h / 2 + 4 + len))
                ctx.addLine(to: CGPoint(x: x + 4, y: c.y - h / 2 + 4)); ctx.fillPath()
            }
            sleeper(biome: biome, realmID: realmID, at: CGPoint(x: c.x, y: c.y + h / 2 - 6), ctx: ctx)
        case .lavaTube:
            // A lava tube: a crusted tunnel with a glowing flow inside, as under the slopes of Kīlauea.
            let tube = UIBezierPath(roundedRect: CGRect(x: c.x - 110, y: c.y - 20, width: 220, height: 40), cornerRadius: 20)
            ctx.setFillColor(RGBA(r: 0.16, g: 0.12, b: 0.12).cgColor)
            ctx.addPath(tube.cgPath); ctx.fillPath()
            ctx.saveGState()
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: c.x - 104, y: c.y + 2, width: 208, height: 14), cornerRadius: 7).cgPath)
            ctx.clip()
            TextureFactory.linearGradient(ctx, colors: [RGBA(r: 1, g: 0.85, b: 0.3), RGBA(r: 1, g: 0.4, b: 0.08), RGBA(r: 0.7, g: 0.1, b: 0.05)],
                                          from: CGPoint(x: c.x, y: c.y + 2), to: CGPoint(x: c.x, y: c.y + 16))
            ctx.restoreGState()
            TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 0.5, b: 0.1, a: 0.45), RGBA(r: 1, g: 0.4, b: 0.1, a: 0)],
                                          center: CGPoint(x: c.x, y: c.y + 6), radius: 60)
            ctx.setFillColor(RGBA(r: 1, g: 0.55, b: 0.15).cgColor)
            for k in 0..<4 {
                let x = c.x - 70 + CGFloat(k) * 45
                ctx.fillEllipse(in: CGRect(x: x, y: c.y - 16, width: 3, height: 6))
            }
        case .frozenMammoth:
            let block = UIBezierPath(roundedRect: CGRect(x: c.x - 44, y: c.y - 26, width: 88, height: 52), cornerRadius: 6)
            ctx.setFillColor(RGBA(r: 0.75, g: 0.9, b: 0.98, a: 0.75).cgColor)
            ctx.addPath(block.cgPath); ctx.fillPath()
            ctx.setFillColor(RGBA(r: 0.42, g: 0.3, b: 0.22, a: 0.85).cgColor)
            ctx.fillEllipse(in: CGRect(x: c.x - 26, y: c.y - 14, width: 40, height: 24))
            ctx.fillEllipse(in: CGRect(x: c.x + 8, y: c.y - 18, width: 18, height: 16))
            ctx.fill(CGRect(x: c.x - 20, y: c.y + 6, width: 7, height: 12))
            ctx.fill(CGRect(x: c.x + 2, y: c.y + 6, width: 7, height: 12))
            ctx.setStrokeColor(RGBA(r: 0.95, g: 0.92, b: 0.82).cgColor); ctx.setLineWidth(2.5)
            ctx.move(to: CGPoint(x: c.x + 24, y: c.y - 4)); ctx.addQuadCurve(to: CGPoint(x: c.x + 30, y: c.y - 18), control: CGPoint(x: c.x + 36, y: c.y + 2)); ctx.strokePath()
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor); ctx.setLineWidth(1.2)
            ctx.move(to: CGPoint(x: c.x - 40, y: c.y - 20)); ctx.addLine(to: CGPoint(x: c.x - 30, y: c.y - 24)); ctx.strokePath()
        case .shells:
            for k in 0..<3 {
                let p = CGPoint(x: c.x + CGFloat(k) * 16 - 16, y: c.y + CGFloat(k % 2) * 5)
                ctx.setFillColor(RGBA(r: 0.98, g: 0.85, b: 0.78).cgColor)
                ctx.addPath(UIBezierPath(arcCenter: p, radius: 6, startAngle: .pi, endAngle: 0, clockwise: true).cgPath)
                ctx.fillPath()
                ctx.setStrokeColor(RGBA(r: 0.8, g: 0.6, b: 0.55).cgColor); ctx.setLineWidth(0.8)
                for a in stride(from: CGFloat.pi * 1.15, through: .pi * 1.85, by: .pi * 0.17) {
                    ctx.move(to: p); ctx.addLine(to: CGPoint(x: p.x + cos(a) * 6, y: p.y + sin(a) * 6)); ctx.strokePath()
                }
            }
        case .starfish:
            ctx.setFillColor(RGBA(r: 0.95, g: 0.5, b: 0.35).cgColor)
            for k in 0..<5 {
                let a = CGFloat(k) / 5 * .pi * 2 - .pi / 2
                ctx.move(to: c)
                ctx.addLine(to: CGPoint(x: c.x + cos(a - 0.35) * 5, y: c.y + sin(a - 0.35) * 5))
                ctx.addLine(to: CGPoint(x: c.x + cos(a) * 13, y: c.y + sin(a) * 13))
                ctx.addLine(to: CGPoint(x: c.x + cos(a + 0.35) * 5, y: c.y + sin(a + 0.35) * 5))
                ctx.closePath(); ctx.fillPath()
            }
        case .amphora:
            // A sunken jar lying on its side, half buried.
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: 1.3 * flip)
            ctx.setFillColor(RGBA(r: 0.62, g: 0.4, b: 0.28, a: 0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: -10, y: -16, width: 20, height: 30))
            ctx.fill(CGRect(x: -3, y: -24, width: 6, height: 10))
        }
        ctx.restoreGState()
    }

    /// The animal hibernating in a cave, chosen to suit the land.
    private static func sleeper(biome: Biome, realmID: String, at p: CGPoint, ctx: CGContext) {
        let fur = RGBA(r: 0.32, g: 0.22, b: 0.16)
        switch biome {
        case .forest, .mountain, .tundra, .steppe:
            // A curled-up bear.
            ctx.setFillColor(fur.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 22, y: p.y - 16, width: 40, height: 20))
            ctx.fillEllipse(in: CGRect(x: p.x + 8, y: p.y - 14, width: 16, height: 13))
            ctx.fillEllipse(in: CGRect(x: p.x + 10, y: p.y - 16, width: 5, height: 5))
        case .jungle, .coast:
            // Bats hanging upside down from the ceiling.
            ctx.setFillColor(RGBA(r: 0.12, g: 0.1, b: 0.12).cgColor)
            for k in 0..<3 {
                let b = CGPoint(x: p.x - 20 + CGFloat(k) * 20, y: p.y - 38)
                ctx.fillEllipse(in: CGRect(x: b.x - 4, y: b.y, width: 8, height: 12))
                ctx.move(to: CGPoint(x: b.x - 4, y: b.y + 3)); ctx.addLine(to: CGPoint(x: b.x - 9, y: b.y + 10)); ctx.addLine(to: CGPoint(x: b.x - 3, y: b.y + 9)); ctx.fillPath()
                ctx.move(to: CGPoint(x: b.x + 4, y: b.y + 3)); ctx.addLine(to: CGPoint(x: b.x + 9, y: b.y + 10)); ctx.addLine(to: CGPoint(x: b.x + 3, y: b.y + 9)); ctx.fillPath()
            }
        case .desert, .volcanic:
            // A coiled snake.
            ctx.setStrokeColor(RGBA(r: 0.55, g: 0.45, b: 0.25).cgColor)
            ctx.setLineWidth(4.5)
            for r in [12.0, 7.0] as [CGFloat] { ctx.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - 10 - r / 2, width: r * 2, height: r)) }
            ctx.setFillColor(RGBA(r: 0.55, g: 0.45, b: 0.25).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 3, y: p.y - 16, width: 7, height: 5))
        case .savanna, .market, .farmland:
            // A tortoise tucked into its shell.
            ctx.setFillColor(RGBA(r: 0.45, g: 0.38, b: 0.22).cgColor)
            ctx.addPath(UIBezierPath(arcCenter: CGPoint(x: p.x, y: p.y - 2), radius: 14, startAngle: .pi, endAngle: 0, clockwise: false).cgPath)
            ctx.fillPath()
            ctx.setStrokeColor(RGBA(r: 0.3, g: 0.25, b: 0.15).cgColor); ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: p.x - 7, y: p.y - 2)); ctx.addLine(to: CGPoint(x: p.x - 4, y: p.y - 12)); ctx.strokePath()
            ctx.move(to: CGPoint(x: p.x + 7, y: p.y - 2)); ctx.addLine(to: CGPoint(x: p.x + 4, y: p.y - 12)); ctx.strokePath()
        }
        // Sleeping: a little "z".
        let z = SleepingZ.path(at: CGPoint(x: p.x + 18, y: p.y - 30))
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1.4)
        ctx.addPath(z); ctx.strokePath()
    }
}

private enum SleepingZ {
    static func path(at p: CGPoint) -> CGPath {
        let z = CGMutablePath()
        z.move(to: p); z.addLine(to: CGPoint(x: p.x + 6, y: p.y)); z.addLine(to: CGPoint(x: p.x, y: p.y + 6)); z.addLine(to: CGPoint(x: p.x + 6, y: p.y + 6))
        let q = CGPoint(x: p.x + 9, y: p.y - 8)
        z.move(to: q); z.addLine(to: CGPoint(x: q.x + 4, y: q.y)); z.addLine(to: CGPoint(x: q.x, y: q.y + 4)); z.addLine(to: CGPoint(x: q.x + 4, y: q.y + 4))
        return z
    }
}
