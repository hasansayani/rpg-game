import SpriteKit
import UIKit

/// Procedural art for swimming realms: coral, things hanging from the surface, the surface itself,
/// and light shafts. Anchors are noted per texture.
extension TextureFactory {
    /// Branching coral. Anchor at bottom center.
    static func coral(color: RGBA, seed: Int) -> SKTexture {
        image(size: CGSize(width: 56, height: 60)) { ctx in
            var rng = SeededRandom(seed: UInt64(seed) &+ 7)
            ctx.setLineCap(.round)
            func branch(_ x: CGFloat, _ y: CGFloat, _ a: CGFloat, _ len: CGFloat, _ w: CGFloat, _ depth: Int) {
                let ex = x + sin(a) * len, ey = y - cos(a) * len
                ctx.setStrokeColor(color.mixed(with: RGBA(r: 1, g: 1, b: 1), Double(depth) * 0.08).cgColor)
                ctx.setLineWidth(w)
                ctx.move(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: ex, y: ey)); ctx.strokePath()
                if depth >= 3 {
                    ctx.setFillColor(color.lighter(0.4).cgColor)
                    ctx.fillEllipse(in: CGRect(x: ex - w * 0.7, y: ey - w * 0.7, width: w * 1.4, height: w * 1.4))
                    return
                }
                let spread = CGFloat(rng.range(0.35, 0.7))
                branch(ex, ey, a - spread, len * 0.72, w * 0.7, depth + 1)
                branch(ex, ey, a + spread, len * 0.72, w * 0.7, depth + 1)
            }
            branch(28, 60, 0, 20, 7, 0)
        }
    }

    /// An icicle cluster hanging from sea ice. Anchor at top center.
    static func icicle() -> SKTexture {
        image(size: CGSize(width: 40, height: 100)) { ctx in
            for (x, len, w) in [(8.0, 70.0, 10.0), (20.0, 100.0, 14.0), (32.0, 60.0, 9.0)] as [(CGFloat, CGFloat, CGFloat)] {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: x - w / 2, y: 0)); p.addLine(to: CGPoint(x: x, y: len)); p.addLine(to: CGPoint(x: x + w / 2, y: 0)); p.close()
                ctx.saveGState(); ctx.addPath(p.cgPath); ctx.clip()
                linearGradient(ctx, colors: [RGBA(r: 0.95, g: 0.99, b: 1), RGBA(r: 0.6, g: 0.85, b: 0.95, a: 0.85)],
                               from: CGPoint(x: x - w / 2, y: 0), to: CGPoint(x: x + w / 2, y: len))
                ctx.restoreGState()
            }
        }
    }

    /// A drifting jellyfish: dome and trailing tentacles. Anchor at top center (it hangs to `length`).
    static func jellyfish(color: RGBA) -> SKTexture {
        image(size: CGSize(width: 44, height: 100)) { ctx in
            radialGradient(ctx, colors: [color.lighter(0.5).withAlpha(0.9), color.withAlpha(0.55)],
                           center: CGPoint(x: 22, y: 16), radius: 22)
            ctx.setBlendMode(.clear)
            ctx.fill(CGRect(x: 0, y: 24, width: 44, height: 80))
            ctx.setBlendMode(.normal)
            ctx.setStrokeColor(color.lighter(0.3).withAlpha(0.75).cgColor)
            ctx.setLineWidth(1.6)
            for k in 0..<5 {
                let x = 8 + CGFloat(k) * 7
                ctx.move(to: CGPoint(x: x, y: 22))
                ctx.addCurve(to: CGPoint(x: x + 2, y: 98), control1: CGPoint(x: x + 8, y: 50), control2: CGPoint(x: x - 8, y: 72))
                ctx.strokePath()
            }
        }
    }

    /// One tile of the water surface seen from below. Ice: a thick white sheet with cracks.
    /// Open sea: a bright rippling line. Anchor at bottom (the underside of the surface).
    static func waterSurface(ice: Bool, tint: RGBA) -> SKTexture {
        image(size: CGSize(width: 256, height: 60)) { ctx in
            if ice {
                linearGradient(ctx, colors: [RGBA(r: 0.98, g: 1, b: 1), RGBA(r: 0.75, g: 0.9, b: 0.97)],
                               from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 60))
                ctx.setStrokeColor(RGBA(r: 0.55, g: 0.75, b: 0.88).cgColor)
                ctx.setLineWidth(1.2)
                ctx.move(to: CGPoint(x: 30, y: 60)); ctx.addLine(to: CGPoint(x: 52, y: 30)); ctx.addLine(to: CGPoint(x: 44, y: 8)); ctx.strokePath()
                ctx.move(to: CGPoint(x: 160, y: 60)); ctx.addLine(to: CGPoint(x: 150, y: 36)); ctx.addLine(to: CGPoint(x: 178, y: 18)); ctx.strokePath()
                // Uneven underside.
                ctx.setFillColor(RGBA(r: 0.75, g: 0.9, b: 0.97).cgColor)
                for k in 0..<8 { ctx.fillEllipse(in: CGRect(x: CGFloat(k) * 32, y: 52, width: 40, height: 14)) }
            } else {
                ctx.setFillColor(tint.lighter(0.5).withAlpha(0.35).cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: 256, height: 54))
                ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
                ctx.setLineWidth(3)
                ctx.move(to: CGPoint(x: 0, y: 54))
                for k in 0..<8 {
                    let x = CGFloat(k) * 32
                    ctx.addQuadCurve(to: CGPoint(x: x + 32, y: 54), control: CGPoint(x: x + 16, y: k % 2 == 0 ? 46 : 60))
                }
                ctx.strokePath()
            }
        }
    }

    /// A soft diagonal light shaft from the surface. Anchor at top center.
    static func lightShaft() -> SKTexture {
        image(size: CGSize(width: 60, height: 300)) { ctx in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 18, y: 0)); p.addLine(to: CGPoint(x: 42, y: 0)); p.addLine(to: CGPoint(x: 60, y: 300)); p.addLine(to: CGPoint(x: 0, y: 300)); p.close()
            ctx.addPath(p.cgPath); ctx.clip()
            linearGradient(ctx, colors: [RGBA(r: 1, g: 1, b: 1, a: 0.5), RGBA(r: 1, g: 1, b: 1, a: 0)],
                           from: .zero, to: CGPoint(x: 0, y: 300))
        }
    }
}
