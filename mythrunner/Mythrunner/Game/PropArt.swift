import SpriteKit
import UIKit

/// Culture-specific obstacles. Each is drawn to fill a 64×64 canvas (feet at the bottom edge) so it
/// stretches cleanly to the obstacle's collision box. `tint` is the realm's near color, `accent` its
/// accent, and `motif` paints a decorative band where the object would carry one.
extension TextureFactory {
    static func prop(_ kind: Prop, tint: RGBA, accent: RGBA, motif: Motif) -> SKTexture {
        image(size: CGSize(width: 64, height: 64)) { ctx in
            let wood = RGBA(r: 0.48, g: 0.31, b: 0.18)
            let stone = tint.mixed(with: RGBA(r: 0.62, g: 0.6, b: 0.58), 0.6)
            let clay = RGBA(r: 0.74, g: 0.42, b: 0.26)
            let straw = RGBA(r: 0.86, g: 0.72, b: 0.38)
            func shade(_ path: CGPath, _ c: RGBA) {
                ctx.saveGState(); ctx.addPath(path); ctx.clip()
                linearGradient(ctx, colors: [c.lighter(0.2), c, c.darker(0.3)], from: CGPoint(x: 10, y: 0), to: CGPoint(x: 54, y: 64))
                ctx.restoreGState()
                ctx.setStrokeColor(c.darker(0.45).cgColor); ctx.setLineWidth(1.5)
                ctx.addPath(path); ctx.strokePath()
            }
            func band(_ path: CGPath, y: CGFloat, h: CGFloat, ink: RGBA) {
                ctx.saveGState(); ctx.addPath(path); ctx.clip()
                MotifPainter.band(motif, in: CGRect(x: 0, y: y, width: 64, height: h), ctx: ctx, ink: ink)
                ctx.restoreGState()
            }
            switch kind {
            case .amphora, .jar, .pot, .calabash:
                let p = UIBezierPath()
                let neck: CGFloat = kind == .amphora ? 10 : kind == .calabash ? 4 : 14
                p.move(to: CGPoint(x: 32 - neck / 2, y: 2))
                p.addLine(to: CGPoint(x: 32 + neck / 2, y: 2))
                p.addCurve(to: CGPoint(x: 40, y: 64), controlPoint1: CGPoint(x: 70, y: 18), controlPoint2: CGPoint(x: 60, y: 54))
                p.addLine(to: CGPoint(x: 24, y: 64))
                p.addCurve(to: CGPoint(x: 32 - neck / 2, y: 2), controlPoint1: CGPoint(x: 4, y: 54), controlPoint2: CGPoint(x: -6, y: 18))
                p.close()
                let c = kind == .calabash ? RGBA(r: 0.8, g: 0.62, b: 0.3) : kind == .jar ? clay.lighter(0.1) : clay
                shade(p.cgPath, c)
                band(p.cgPath, y: 26, h: 10, ink: kind == .amphora ? RGBA(r: 0.1, g: 0.08, b: 0.08) : accent)
                if kind == .amphora {
                    ctx.setStrokeColor(c.darker(0.3).cgColor); ctx.setLineWidth(3)
                    ctx.addArc(center: CGPoint(x: 20, y: 12), radius: 7, startAngle: .pi * 0.5, endAngle: .pi * 1.5, clockwise: false); ctx.strokePath()
                    ctx.addArc(center: CGPoint(x: 44, y: 12), radius: 7, startAngle: -.pi * 0.5, endAngle: .pi * 0.5, clockwise: false); ctx.strokePath()
                }
            case .column:
                let p = UIBezierPath(rect: CGRect(x: 14, y: 8, width: 36, height: 56))
                shade(p.cgPath, RGBA(r: 0.92, g: 0.9, b: 0.84))
                ctx.setStrokeColor(RGBA(r: 0.7, g: 0.68, b: 0.62).cgColor); ctx.setLineWidth(1.5)
                for x in stride(from: 20.0, through: 44, by: 6) { ctx.move(to: CGPoint(x: x, y: 10)); ctx.addLine(to: CGPoint(x: x, y: 62)); ctx.strokePath() }
                // Broken top.
                ctx.setFillColor(RGBA(r: 0.85, g: 0.83, b: 0.77).cgColor)
                ctx.move(to: CGPoint(x: 10, y: 10)); ctx.addLine(to: CGPoint(x: 26, y: 0)); ctx.addLine(to: CGPoint(x: 34, y: 8))
                ctx.addLine(to: CGPoint(x: 46, y: 2)); ctx.addLine(to: CGPoint(x: 54, y: 10)); ctx.closePath(); ctx.fillPath()
            case .stoneBlock, .masonry, .carvedStone:
                let p = UIBezierPath(roundedRect: CGRect(x: 2, y: 6, width: 60, height: 58), cornerRadius: kind == .masonry ? 8 : 3)
                shade(p.cgPath, kind == .masonry ? RGBA(r: 0.62, g: 0.58, b: 0.52) : stone)
                ctx.setStrokeColor(stone.darker(0.4).cgColor); ctx.setLineWidth(1.4)
                if kind == .masonry {
                    // Inca-style fitted polygonal stones.
                    for pts in [[CGPoint(x: 2, y: 30), CGPoint(x: 26, y: 26), CGPoint(x: 34, y: 64)], [CGPoint(x: 26, y: 26), CGPoint(x: 30, y: 6)],
                                [CGPoint(x: 26, y: 26), CGPoint(x: 62, y: 36)], [CGPoint(x: 46, y: 32), CGPoint(x: 50, y: 64)]] {
                        ctx.addLines(between: pts); ctx.strokePath()
                    }
                } else {
                    band(p.cgPath, y: 22, h: 18, ink: kind == .carvedStone ? accent : stone.darker(0.5))
                }
            case .runeStone, .petroglyphStone, .boulder, .lavaRock:
                let p = UIBezierPath()
                let tall = kind == .runeStone
                p.move(to: CGPoint(x: 4, y: 64))
                p.addCurve(to: CGPoint(x: 30, y: tall ? 0 : 10), controlPoint1: CGPoint(x: 2, y: 30), controlPoint2: CGPoint(x: 14, y: tall ? 0 : 10))
                p.addCurve(to: CGPoint(x: 60, y: 64), controlPoint1: CGPoint(x: 52, y: tall ? 4 : 10), controlPoint2: CGPoint(x: 64, y: 36))
                p.close()
                let c = kind == .lavaRock ? RGBA(r: 0.2, g: 0.18, b: 0.2) : kind == .boulder ? tint.mixed(with: stone, 0.5) : stone
                shade(p.cgPath, c)
                if kind == .runeStone {
                    // A ribbon of runic interlace, as on Viking-age rune stones.
                    band(p.cgPath, y: 14, h: 40, ink: RGBA(r: 0.75, g: 0.2, b: 0.15))
                } else if kind == .petroglyphStone {
                    ctx.setStrokeColor(c.lighter(0.45).cgColor); ctx.setLineWidth(2)
                    ctx.strokeEllipse(in: CGRect(x: 22, y: 26, width: 14, height: 14))
                    ctx.move(to: CGPoint(x: 29, y: 40)); ctx.addLine(to: CGPoint(x: 29, y: 54)); ctx.strokePath()
                    ctx.move(to: CGPoint(x: 20, y: 46)); ctx.addLine(to: CGPoint(x: 38, y: 46)); ctx.strokePath()
                } else if kind == .lavaRock {
                    ctx.setStrokeColor(RGBA(r: 1, g: 0.45, b: 0.1).cgColor); ctx.setLineWidth(1.6)
                    ctx.move(to: CGPoint(x: 16, y: 60)); ctx.addLine(to: CGPoint(x: 26, y: 40)); ctx.addLine(to: CGPoint(x: 22, y: 26)); ctx.strokePath()
                    ctx.move(to: CGPoint(x: 44, y: 62)); ctx.addLine(to: CGPoint(x: 40, y: 44)); ctx.strokePath()
                }
            case .log:
                let p = UIBezierPath(roundedRect: CGRect(x: 0, y: 14, width: 64, height: 50), cornerRadius: 22)
                shade(p.cgPath, wood)
                ctx.setFillColor(wood.lighter(0.35).cgColor)
                ctx.fillEllipse(in: CGRect(x: 40, y: 16, width: 24, height: 46))
                ctx.setStrokeColor(wood.darker(0.2).cgColor); ctx.setLineWidth(1.2)
                for r in [6.0, 12.0, 18.0] as [CGFloat] { ctx.strokeEllipse(in: CGRect(x: 52 - r / 2, y: 39 - r, width: r, height: r * 2)) }
                ctx.setFillColor(RGBA(r: 0.3, g: 0.5, b: 0.25).cgColor)
                ctx.fillEllipse(in: CGRect(x: 6, y: 10, width: 20, height: 9))
            case .stoneLantern:
                // Tōrō: base, post, fire box with a window, roof and finial.
                ctx.setFillColor(stone.cgColor)
                ctx.fill(CGRect(x: 18, y: 56, width: 28, height: 8))
                ctx.fill(CGRect(x: 27, y: 36, width: 10, height: 20))
                let box = UIBezierPath(rect: CGRect(x: 18, y: 18, width: 28, height: 18)).cgPath
                shade(box, stone)
                TextureFactory.radialGradient(ctx, colors: [RGBA(r: 1, g: 0.85, b: 0.4), RGBA(r: 1, g: 0.6, b: 0.2, a: 0)], center: CGPoint(x: 32, y: 27), radius: 9)
                ctx.setFillColor(stone.darker(0.15).cgColor)
                ctx.move(to: CGPoint(x: 6, y: 18)); ctx.addLine(to: CGPoint(x: 32, y: 6)); ctx.addLine(to: CGPoint(x: 58, y: 18)); ctx.closePath(); ctx.fillPath()
                ctx.fillEllipse(in: CGRect(x: 28, y: 0, width: 8, height: 8))
            case .bambooFence, .fence:
                let c = kind == .bambooFence ? RGBA(r: 0.62, g: 0.68, b: 0.3) : wood
                for k in 0..<4 {
                    let x = 4 + CGFloat(k) * 15
                    let post = UIBezierPath(roundedRect: CGRect(x: x, y: CGFloat(k % 2) * 6, width: 10, height: 64 - CGFloat(k % 2) * 6), cornerRadius: kind == .bambooFence ? 5 : 1)
                    shade(post.cgPath, c)
                    if kind == .bambooFence {
                        ctx.setStrokeColor(c.darker(0.35).cgColor); ctx.setLineWidth(1.5)
                        for y in stride(from: 16.0, to: 60, by: 14) { ctx.move(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x + 10, y: y)); ctx.strokePath() }
                    }
                }
                ctx.setStrokeColor((kind == .bambooFence ? RGBA(r: 0.5, g: 0.35, b: 0.2) : wood.darker(0.15)).cgColor); ctx.setLineWidth(4)
                ctx.move(to: CGPoint(x: 0, y: 24)); ctx.addLine(to: CGPoint(x: 64, y: 24)); ctx.strokePath()
                ctx.move(to: CGPoint(x: 0, y: 44)); ctx.addLine(to: CGPoint(x: 64, y: 44)); ctx.strokePath()
            case .basket, .haystack:
                let p = UIBezierPath()
                if kind == .haystack {
                    p.move(to: CGPoint(x: 2, y: 64)); p.addCurve(to: CGPoint(x: 62, y: 64), controlPoint1: CGPoint(x: 0, y: -14), controlPoint2: CGPoint(x: 64, y: -14))
                } else {
                    p.move(to: CGPoint(x: 6, y: 14)); p.addLine(to: CGPoint(x: 58, y: 14)); p.addLine(to: CGPoint(x: 50, y: 64)); p.addLine(to: CGPoint(x: 14, y: 64))
                }
                p.close()
                shade(p.cgPath, straw)
                ctx.saveGState(); ctx.addPath(p.cgPath); ctx.clip()
                ctx.setStrokeColor(straw.darker(0.3).cgColor); ctx.setLineWidth(1.2)
                for y in stride(from: 6.0, to: 64, by: 7) { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: 64, y: y + (kind == .haystack ? 3 : 0))); ctx.strokePath() }
                if kind == .basket {
                    band(p.cgPath, y: 30, h: 10, ink: accent)
                }
                ctx.restoreGState()
                if kind == .basket {
                    // Produce heaped on top.
                    for k in 0..<4 {
                        TextureFactory.radialGradient(ctx, colors: [accent.lighter(0.4), accent.darker(0.1)], center: CGPoint(x: 16 + CGFloat(k) * 11, y: 11), radius: 7)
                    }
                }
            case .pou:
                // A carved post with stacked figures and spiral details.
                let p = UIBezierPath(roundedRect: CGRect(x: 18, y: 0, width: 28, height: 64), cornerRadius: 6)
                shade(p.cgPath, RGBA(r: 0.55, g: 0.24, b: 0.16))
                band(p.cgPath, y: 8, h: 14, ink: RGBA(r: 0.95, g: 0.9, b: 0.8))
                band(p.cgPath, y: 34, h: 14, ink: RGBA(r: 0.95, g: 0.9, b: 0.8))
                ctx.setFillColor(RGBA(r: 0.5, g: 0.95, b: 0.85).cgColor)
                ctx.fillEllipse(in: CGRect(x: 24, y: 26, width: 6, height: 6)); ctx.fillEllipse(in: CGRect(x: 34, y: 26, width: 6, height: 6))
            case .barrel, .drum:
                let p = UIBezierPath(roundedRect: CGRect(x: 8, y: kind == .drum ? 12 : 4, width: 48, height: kind == .drum ? 52 : 60), cornerRadius: 10)
                shade(p.cgPath, kind == .drum ? RGBA(r: 0.42, g: 0.24, b: 0.14) : wood)
                if kind == .drum {
                    ctx.setFillColor(RGBA(r: 0.92, g: 0.86, b: 0.72).cgColor)
                    ctx.fillEllipse(in: CGRect(x: 8, y: 6, width: 48, height: 14))
                    band(p.cgPath, y: 34, h: 14, ink: accent)
                    ctx.setStrokeColor(RGBA(r: 0.9, g: 0.85, b: 0.7).cgColor); ctx.setLineWidth(1)
                    for x in stride(from: 12.0, to: 56, by: 8) { ctx.move(to: CGPoint(x: x, y: 18)); ctx.addLine(to: CGPoint(x: x + 4, y: 34)); ctx.strokePath() }
                } else {
                    ctx.setStrokeColor(RGBA(r: 0.3, g: 0.3, b: 0.32).cgColor); ctx.setLineWidth(3)
                    for y in [14.0, 50.0] as [CGFloat] { ctx.move(to: CGPoint(x: 8, y: y)); ctx.addLine(to: CGPoint(x: 56, y: y)); ctx.strokePath() }
                    band(p.cgPath, y: 26, h: 12, ink: RGBA(r: 0.85, g: 0.15, b: 0.15))
                }
            case .stela:
                let p = UIBezierPath(roundedRect: CGRect(x: 12, y: 0, width: 40, height: 64), cornerRadius: 10)
                shade(p.cgPath, stone)
                band(p.cgPath, y: 6, h: 16, ink: stone.darker(0.5))
                band(p.cgPath, y: 26, h: 16, ink: stone.darker(0.5))
                band(p.cgPath, y: 46, h: 16, ink: stone.darker(0.5))
            case .carpetRoll:
                let p = UIBezierPath(roundedRect: CGRect(x: 0, y: 22, width: 64, height: 42), cornerRadius: 18)
                shade(p.cgPath, RGBA(r: 0.6, g: 0.12, b: 0.15))
                band(p.cgPath, y: 32, h: 20, ink: RGBA(r: 0.95, g: 0.8, b: 0.35))
                ctx.setFillColor(RGBA(r: 0.45, g: 0.08, b: 0.1).cgColor)
                ctx.fillEllipse(in: CGRect(x: 46, y: 22, width: 18, height: 42))
            case .cartWheel:
                ctx.setStrokeColor(wood.cgColor); ctx.setLineWidth(6)
                ctx.strokeEllipse(in: CGRect(x: 4, y: 4, width: 56, height: 56))
                ctx.setLineWidth(3)
                for k in 0..<8 {
                    let a = CGFloat(k) / 8 * .pi * 2
                    ctx.move(to: CGPoint(x: 32, y: 32)); ctx.addLine(to: CGPoint(x: 32 + cos(a) * 26, y: 32 + sin(a) * 26)); ctx.strokePath()
                }
                ctx.setFillColor(wood.darker(0.3).cgColor)
                ctx.fillEllipse(in: CGRect(x: 26, y: 26, width: 12, height: 12))
            case .thornBush:
                ctx.setFillColor(RGBA(r: 0.35, g: 0.42, b: 0.2).cgColor)
                for (x, y, r) in [(16.0, 40.0, 16.0), (34.0, 30.0, 20.0), (50.0, 42.0, 14.0)] as [(CGFloat, CGFloat, CGFloat)] {
                    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                }
                ctx.fill(CGRect(x: 4, y: 44, width: 56, height: 20))
                ctx.setStrokeColor(RGBA(r: 0.85, g: 0.8, b: 0.6).cgColor); ctx.setLineWidth(1.2)
                for k in 0..<14 {
                    let a = CGFloat(k) / 14 * .pi * 2
                    let c = CGPoint(x: 32 + cos(a) * 18, y: 36 + sin(a) * 18)
                    ctx.move(to: c); ctx.addLine(to: CGPoint(x: c.x + cos(a) * 6, y: c.y + sin(a) * 6)); ctx.strokePath()
                }
            case .produceCrate:
                let p = UIBezierPath(rect: CGRect(x: 2, y: 22, width: 60, height: 42))
                shade(p.cgPath, wood.lighter(0.15))
                ctx.setStrokeColor(wood.darker(0.35).cgColor); ctx.setLineWidth(1.5)
                for y in [36.0, 50.0] as [CGFloat] { ctx.move(to: CGPoint(x: 2, y: y)); ctx.addLine(to: CGPoint(x: 62, y: y)); ctx.strokePath() }
                let fruit = [accent, RGBA(r: 0.9, g: 0.3, b: 0.2), RGBA(r: 0.5, g: 0.75, b: 0.25), RGBA(r: 0.95, g: 0.6, b: 0.15)]
                for k in 0..<6 {
                    let x = 8 + CGFloat(k) * 9.5, y = 18 - CGFloat(k % 2) * 6
                    TextureFactory.radialGradient(ctx, colors: [fruit[k % 4].lighter(0.4), fruit[k % 4]], center: CGPoint(x: x, y: y), radius: 7)
                }
            }
        }
    }

    /// Small surface details for a biome, drawn along the top of each terrain chunk.
    static func groundDetail(_ biome: Biome, ctx: CGContext, surface: [CGPoint], ground: RGBA, edge: RGBA, accent: RGBA, seed: Int) {
        var rng = SeededRandom(seed: UInt64(abs(seed)) &+ 99)
        ctx.setLineCap(.round)
        for (i, p) in surface.enumerated() where i % 2 == 0 {
            let r = rng.unit()
            switch biome {
            case .forest, .jungle, .farmland, .steppe, .savanna:
                // Grass blades (lush for forests and jungle, dry and sparse on steppe and savanna).
                let lush = biome == .forest || biome == .jungle || biome == .farmland
                guard lush || r < 0.55 else { continue }
                let green = lush ? RGBA(r: 0.28, g: 0.55, b: 0.25) : RGBA(r: 0.72, g: 0.62, b: 0.32)
                ctx.setStrokeColor(green.mixed(with: ground, 0.25).cgColor)
                ctx.setLineWidth(1.6)
                for k in 0..<3 {
                    let lean = CGFloat(k - 1) * 2.5
                    ctx.move(to: CGPoint(x: p.x + CGFloat(k) * 2, y: p.y + 1))
                    ctx.addLine(to: CGPoint(x: p.x + CGFloat(k) * 2 + lean, y: p.y - CGFloat(4 + rng.range(0, lush ? 6 : 4))))
                    ctx.strokePath()
                }
                if biome == .jungle, r < 0.12 {
                    ctx.setFillColor(accent.cgColor)
                    ctx.fillEllipse(in: CGRect(x: p.x - 2, y: p.y - 9, width: 4, height: 4))
                }
            case .mountain, .coast:
                guard r < 0.35 else { continue }
                ctx.setFillColor((biome == .coast ? RGBA(r: 0.95, g: 0.9, b: 0.82) : edge.darker(0.25)).cgColor)
                let s = CGFloat(rng.range(2, 5))
                ctx.fillEllipse(in: CGRect(x: p.x, y: p.y + 4 + CGFloat(rng.range(0, 10)), width: s * 1.4, height: s))
            case .desert:
                guard i % 6 == 0 else { continue }
                ctx.setStrokeColor(edge.darker(0.15).withAlpha(0.6).cgColor)
                ctx.setLineWidth(1.2)
                ctx.move(to: CGPoint(x: p.x, y: p.y + 10)); ctx.addQuadCurve(to: CGPoint(x: p.x + 16, y: p.y + 10), control: CGPoint(x: p.x + 8, y: p.y + 6))
                ctx.strokePath()
            case .tundra:
                guard r < 0.4 else { continue }
                ctx.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x, y: p.y + CGFloat(rng.range(2, 14)), width: 2.5, height: 2.5))
            case .market:
                // Cobbles under the surface line.
                guard r < 0.6 else { continue }
                let w = CGFloat(rng.range(6, 11)), depth = CGFloat(rng.range(5, 16))
                ctx.setFillColor(ground.mixed(with: edge, 0.5).darker(CGFloat(0.12 + r * 0.15)).withAlpha(0.7).cgColor)
                ctx.addPath(UIBezierPath(roundedRect: CGRect(x: p.x, y: p.y + depth, width: w, height: w * 0.6), cornerRadius: 2).cgPath)
                ctx.fillPath()
            case .volcanic:
                guard r < 0.12 else { continue }
                ctx.setStrokeColor(RGBA(r: 1, g: 0.45, b: 0.1).withAlpha(0.8).cgColor)
                ctx.setLineWidth(1.4)
                ctx.move(to: CGPoint(x: p.x, y: p.y + 3)); ctx.addLine(to: CGPoint(x: p.x + 4, y: p.y + 14)); ctx.addLine(to: CGPoint(x: p.x - 2, y: p.y + 24))
                ctx.strokePath()
            }
        }
    }
}
