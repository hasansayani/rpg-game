import SpriteKit
import UIKit

/// Textures for the interactive path elements: springboards, spirit gates and heart shrines.
/// Tinted from the realm palette so each realm's pieces feel like part of its world.
extension TextureFactory {
    /// A carved launch ramp with a glowing rune strip. Anchor at bottom center.
    static func springboard(wood: RGBA, glow: RGBA) -> SKTexture {
        image(size: CGSize(width: 64, height: 30)) { ctx in
            // Ramp body (rises to the right).
            let ramp = UIBezierPath()
            ramp.move(to: CGPoint(x: 2, y: 30))
            ramp.addLine(to: CGPoint(x: 58, y: 8))
            ramp.addQuadCurve(to: CGPoint(x: 62, y: 30), controlPoint: CGPoint(x: 64, y: 14))
            ramp.close()
            ctx.saveGState()
            ctx.addPath(ramp.cgPath); ctx.clip()
            linearGradient(ctx, colors: [wood.lighter(0.15), wood.darker(0.35)], from: CGPoint(x: 0, y: 8), to: CGPoint(x: 0, y: 30))
            // Plank seams.
            ctx.setStrokeColor(wood.darker(0.5).withAlpha(0.6).cgColor)
            ctx.setLineWidth(1)
            for x in stride(from: 14.0, to: 60, by: 12) {
                ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x - 4, y: 30))
            }
            ctx.strokePath()
            ctx.restoreGState()
            // Glowing rune strip along the top edge.
            ctx.setStrokeColor(glow.lighter(0.3).cgColor)
            ctx.setLineWidth(3)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 6, y: 27)); ctx.addLine(to: CGPoint(x: 57, y: 8)); ctx.strokePath()
            // Chevrons pointing up the ramp.
            ctx.setFillColor(glow.lighter(0.5).cgColor)
            for k in 0..<3 {
                let cx = 22 + CGFloat(k) * 12, cy = 25 - CGFloat(k) * 4.5
                ctx.move(to: CGPoint(x: cx - 3, y: cy + 3)); ctx.addLine(to: CGPoint(x: cx + 3, y: cy - 2))
                ctx.addLine(to: CGPoint(x: cx - 1, y: cy + 5)); ctx.closePath(); ctx.fillPath()
            }
        }
    }

    /// A floating ring with four glyph studs. Centered.
    static func spiritGate(color: RGBA) -> SKTexture {
        image(size: CGSize(width: 76, height: 104)) { ctx in
            let rect = CGRect(x: 10, y: 8, width: 56, height: 88)
            // Soft halo.
            radialGradient(ctx, colors: [color.withAlpha(0.35), color.withAlpha(0)], center: CGPoint(x: 38, y: 52), radius: 52)
            ctx.setStrokeColor(color.darker(0.2).cgColor)
            ctx.setLineWidth(9)
            ctx.strokeEllipse(in: rect)
            ctx.setStrokeColor(color.lighter(0.45).cgColor)
            ctx.setLineWidth(4)
            ctx.strokeEllipse(in: rect)
            // Glyph studs at the four compass points.
            ctx.setFillColor(RGBA(r: 1, g: 1, b: 1).cgColor)
            for p in [CGPoint(x: 38, y: 8), CGPoint(x: 38, y: 96), CGPoint(x: 10, y: 52), CGPoint(x: 66, y: 52)] {
                ctx.move(to: CGPoint(x: p.x, y: p.y - 5)); ctx.addLine(to: CGPoint(x: p.x + 4, y: p.y))
                ctx.addLine(to: CGPoint(x: p.x, y: p.y + 5)); ctx.addLine(to: CGPoint(x: p.x - 4, y: p.y))
                ctx.closePath(); ctx.fillPath()
            }
        }
    }

    /// A small stone shrine with a heart-shaped flame. Anchor at bottom center.
    static func shrine(stone: RGBA, flame: RGBA) -> SKTexture {
        image(size: CGSize(width: 48, height: 64)) { ctx in
            // Plinth and pillar.
            ctx.setFillColor(stone.darker(0.25).cgColor)
            ctx.fill(CGRect(x: 6, y: 56, width: 36, height: 8))
            ctx.setFillColor(stone.cgColor)
            ctx.fill(CGRect(x: 12, y: 30, width: 24, height: 26))
            ctx.setFillColor(stone.lighter(0.2).cgColor)
            ctx.fill(CGRect(x: 8, y: 26, width: 32, height: 6))
            // Niche glow.
            radialGradient(ctx, colors: [flame.lighter(0.4), flame.withAlpha(0)], center: CGPoint(x: 24, y: 42), radius: 12)
            // Heart flame above the bowl.
            let heart = UIBezierPath()
            heart.move(to: CGPoint(x: 24, y: 24))
            heart.addCurve(to: CGPoint(x: 24, y: 8), controlPoint1: CGPoint(x: 10, y: 16), controlPoint2: CGPoint(x: 14, y: 0))
            heart.addCurve(to: CGPoint(x: 24, y: 24), controlPoint1: CGPoint(x: 34, y: 0), controlPoint2: CGPoint(x: 38, y: 16))
            ctx.setFillColor(flame.cgColor)
            ctx.addPath(heart.cgPath); ctx.fillPath()
            ctx.setFillColor(flame.lighter(0.55).cgColor)
            ctx.fillEllipse(in: CGRect(x: 20, y: 11, width: 6, height: 6))
        }
    }
}
