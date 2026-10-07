import CoreGraphics
import UIKit

/// Draws each culture's decorative motif as a horizontal repeating band. One tile is `rect.height`
/// tall; the band is clipped to `rect`, so the same code decorates a 4 pt scarf stripe or a 30 pt
/// guardian belly. Shapes are simplified homages, not reproductions of specific sacred designs.
enum MotifPainter {
    static func band(_ motif: Motif, in rect: CGRect, ctx: CGContext, ink: RGBA, base: RGBA? = nil) {
        ctx.saveGState()
        ctx.clip(to: rect)
        if let base {
            ctx.setFillColor(base.cgColor)
            ctx.fill(rect)
        }
        ctx.setFillColor(ink.cgColor)
        ctx.setStrokeColor(ink.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let h = rect.height
        ctx.setLineWidth(max(0.8, h * 0.12))
        var x = rect.minX
        var i = 0
        while x < rect.maxX + h {
            tile(motif, at: CGRect(x: x, y: rect.minY, width: h, height: h), index: i, ctx: ctx, ink: ink)
            x += h * tileWidth(motif)
            i += 1
        }
        ctx.restoreGState()
    }

    /// Tile width as a multiple of the band height.
    private static func tileWidth(_ m: Motif) -> CGFloat {
        switch m {
        case .kente, .tocapu, .rockDots, .beadTriangles, .kapa, .dogonChevron: return 0.75
        case .rongorongo, .etruscanWave, .hittiteSpiral, .meander: return 1.0
        default: return 1.2
        }
    }

    private static func tile(_ m: Motif, at r: CGRect, index i: Int, ctx: CGContext, ink: RGBA) {
        let h = r.height, x = r.minX, y = r.minY
        func p(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: x + fx * h, y: y + fy * h) }
        func poly(_ pts: [(CGFloat, CGFloat)], fill: Bool = true) {
            ctx.move(to: p(pts[0].0, pts[0].1))
            for q in pts.dropFirst() { ctx.addLine(to: p(q.0, q.1)) }
            if fill { ctx.closePath(); ctx.fillPath() } else { ctx.strokePath() }
        }
        func dot(_ fx: CGFloat, _ fy: CGFloat, _ fr: CGFloat) {
            ctx.fillEllipse(in: CGRect(x: x + (fx - fr) * h, y: y + (fy - fr) * h, width: fr * 2 * h, height: fr * 2 * h))
        }
        func ring(_ fx: CGFloat, _ fy: CGFloat, _ fr: CGFloat) {
            ctx.strokeEllipse(in: CGRect(x: x + (fx - fr) * h, y: y + (fy - fr) * h, width: fr * 2 * h, height: fr * 2 * h))
        }
        func spiral(_ cx: CGFloat, _ cy: CGFloat, _ fr: CGFloat, turns: CGFloat, flip: Bool = false) {
            let steps = 24
            for s in 0...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let a = t * turns * .pi * 2 * (flip ? -1 : 1)
                let rr = fr * (1 - t * 0.85)
                let pt = p(cx + cos(a) * rr, cy + sin(a) * rr)
                s == 0 ? ctx.move(to: pt) : ctx.addLine(to: pt)
            }
            ctx.strokePath()
        }

        switch m {
        case .meander:
            poly([(0.1, 0.9), (0.1, 0.1), (0.9, 0.1), (0.9, 0.7), (0.35, 0.7), (0.35, 0.35), (0.65, 0.35)], fill: false)
            poly([(0.1, 0.9), (1.1, 0.9)], fill: false)
        case .lotus:
            poly([(0.5, 0.15), (0.68, 0.7), (0.5, 0.88), (0.32, 0.7)])
            poly([(0.2, 0.4), (0.38, 0.75), (0.2, 0.88)])
            poly([(0.8, 0.4), (0.62, 0.75), (0.8, 0.88)])
        case .knotwork:
            ctx.move(to: p(0, 0.25)); ctx.addCurve(to: p(1.2, 0.75), control1: p(0.6, 0.2), control2: p(0.6, 0.8)); ctx.strokePath()
            ctx.move(to: p(0, 0.75)); ctx.addCurve(to: p(1.2, 0.25), control1: p(0.6, 0.8), control2: p(0.6, 0.2)); ctx.strokePath()
        case .seigaiha:
            for (k, fr) in [0.48, 0.32, 0.16].enumerated() {
                _ = k
                ctx.addArc(center: p(0.6, 1.0), radius: fr * h, startAngle: .pi, endAngle: 0, clockwise: false)
                ctx.strokePath()
            }
        case .stepFret:
            poly([(0.05, 0.9), (0.05, 0.55), (0.35, 0.55), (0.35, 0.25), (0.75, 0.25), (0.75, 0.55), (0.55, 0.55)], fill: false)
            poly([(0.05, 0.9), (1.2, 0.9)], fill: false)
        case .triskele:
            spiral(0.35, 0.35, 0.22, turns: 1.2)
            spiral(0.85, 0.35, 0.22, turns: 1.2)
            spiral(0.6, 0.72, 0.22, turns: 1.2)
        case .paisley:
            ctx.move(to: p(0.3, 0.85))
            ctx.addCurve(to: p(0.75, 0.15), control1: p(0.0, 0.4), control2: p(0.6, 0.0))
            ctx.addCurve(to: p(0.3, 0.85), control1: p(0.95, 0.5), control2: p(0.8, 0.85))
            ctx.fillPath()
            ctx.setFillColor(ink.darker(0.4).cgColor); dot(0.5, 0.6, 0.1); ctx.setFillColor(ink.cgColor)
        case .rosette:
            for k in 0..<8 {
                let a = CGFloat(k) / 8 * .pi * 2
                dot(0.6 + cos(a) * 0.25, 0.5 + sin(a) * 0.25, 0.1)
            }
            dot(0.6, 0.5, 0.1)
        case .adire:
            ring(0.6, 0.5, 0.36); ring(0.6, 0.5, 0.18); dot(0.6, 0.5, 0.06)
        case .koru:
            ctx.move(to: p(0.0, 0.9)); ctx.addQuadCurve(to: p(0.6, 0.2), control: p(0.1, 0.1)); ctx.strokePath()
            spiral(0.68, 0.42, 0.22, turns: 1.1, flip: true)
        case .cloud:
            spiral(0.35, 0.55, 0.22, turns: 1.0)
            spiral(0.85, 0.55, 0.22, turns: 1.0, flip: true)
            ctx.move(to: p(0.1, 0.85)); ctx.addLine(to: p(1.1, 0.85)); ctx.strokePath()
        case .mayaStep:
            poly([(0.0, 0.9), (0.0, 0.6), (0.3, 0.6), (0.3, 0.3), (0.6, 0.3), (0.6, 0.6), (0.9, 0.6), (0.9, 0.9)])
            ctx.setFillColor(ink.darker(0.4).cgColor); dot(0.45, 0.5, 0.08); ctx.setFillColor(ink.cgColor)
        case .crossStitch:
            for (fx, fy) in [(0.6, 0.2), (0.35, 0.5), (0.85, 0.5), (0.6, 0.8), (0.6, 0.5)] {
                poly([(fx - 0.1, fy - 0.1), (fx + 0.1, fy + 0.1)], fill: false)
                poly([(fx + 0.1, fy - 0.1), (fx - 0.1, fy + 0.1)], fill: false)
            }
        case .beadTriangles:
            if i % 2 == 0 { poly([(0, 0.9), (0.375, 0.1), (0.75, 0.9)]) } else { poly([(0, 0.1), (0.375, 0.9), (0.75, 0.1)]) }
            ctx.setFillColor(UIColor.white.cgColor); dot(0.375, 0.5, 0.08); ctx.setFillColor(ink.cgColor)
        case .furTrim:
            for k in 0..<4 {
                let fx = 0.15 + CGFloat(k) * 0.3
                poly([(fx, 0.0), (fx + 0.08, 0.55 + CGFloat(k % 2) * 0.3)], fill: false)
            }
        case .girih:
            for k in 0..<8 {
                let a = CGFloat(k) / 8 * .pi * 2
                let rr: CGFloat = k % 2 == 0 ? 0.42 : 0.2
                let pt = p(0.6 + cos(a) * rr, 0.5 + sin(a) * rr)
                k == 0 ? ctx.move(to: pt) : ctx.addLine(to: pt)
            }
            ctx.closePath(); ctx.fillPath()
        case .kapa:
            poly([(0, 0.9), (0.375, 0.2), (0.75, 0.9)], fill: false)
            poly([(0.2, 0.9), (0.375, 0.55), (0.55, 0.9)])
        case .tocapu:
            ctx.fill(CGRect(x: x + 0.05 * h, y: y + 0.1 * h, width: 0.3 * h, height: 0.35 * h))
            ctx.fill(CGRect(x: x + 0.4 * h, y: y + 0.55 * h, width: 0.3 * h, height: 0.35 * h))
            ctx.stroke(CGRect(x: x + 0.05 * h, y: y + 0.55 * h, width: 0.3 * h, height: 0.35 * h))
        case .kantele:
            poly([(0.6, 0.1), (1.0, 0.5), (0.6, 0.9), (0.2, 0.5)], fill: false)
            dot(0.6, 0.5, 0.1)
        case .kente:
            let colors = [ink, ink.mixed(with: RGBA(r: 0.1, g: 0.5, b: 0.2), 0.7), ink.mixed(with: RGBA(r: 0.8, g: 0.1, b: 0.1), 0.7)]
            ctx.setFillColor(colors[i % 3].cgColor)
            ctx.fill(CGRect(x: x, y: y, width: 0.75 * h, height: h))
            ctx.setFillColor(RGBA(r: 0.05, g: 0.05, b: 0.05).cgColor)
            for k in 0..<3 { ctx.fill(CGRect(x: x, y: y + (0.15 + CGFloat(k) * 0.3) * h, width: 0.75 * h, height: 0.08 * h)) }
            ctx.setFillColor(ink.cgColor)
        case .ulzii:
            ctx.stroke(CGRect(x: x + 0.35 * h, y: y + 0.25 * h, width: 0.5 * h, height: 0.5 * h))
            poly([(0.35, 0.5), (0.15, 0.5)], fill: false); poly([(0.85, 0.5), (1.05, 0.5)], fill: false)
            poly([(0.6, 0.25), (0.6, 0.05)], fill: false); poly([(0.6, 0.75), (0.6, 0.95)], fill: false)
        case .hittiteSpiral, .etruscanWave:
            ctx.move(to: p(0, 0.8))
            ctx.addCurve(to: p(0.55, 0.25), control1: p(0.3, 0.8), control2: p(0.25, 0.25))
            ctx.addQuadCurve(to: p(0.6, 0.6), control: p(0.85, 0.35))
            ctx.strokePath()
            if m == .etruscanWave { ctx.move(to: p(0.6, 0.6)); ctx.addQuadCurve(to: p(1.0, 0.8), control: p(0.6, 0.85)); ctx.strokePath() }
        case .rongorongo:
            switch i % 4 {
            case 0: ring(0.5, 0.3, 0.15); poly([(0.5, 0.45), (0.5, 0.9)], fill: false); poly([(0.3, 0.6), (0.7, 0.6)], fill: false)
            case 1: ctx.move(to: p(0.2, 0.9)); ctx.addQuadCurve(to: p(0.8, 0.2), control: p(0.1, 0.2)); ctx.strokePath(); dot(0.75, 0.25, 0.08)
            case 2: poly([(0.3, 0.9), (0.5, 0.2), (0.7, 0.9)], fill: false); poly([(0.2, 0.45), (0.8, 0.45)], fill: false)
            default: ring(0.5, 0.5, 0.25); dot(0.5, 0.5, 0.07)
            }
        case .zemiSpiral:
            spiral(0.6, 0.5, 0.42, turns: 1.6)
        case .dogonChevron:
            poly([(0, 0.25), (0.375, 0.55), (0.75, 0.25)], fill: false)
            poly([(0, 0.6), (0.375, 0.9), (0.75, 0.6)], fill: false)
        case .ayus:
            ctx.move(to: p(0.1, 0.8)); ctx.addQuadCurve(to: p(0.6, 0.5), control: p(0.1, 0.3)); ctx.addQuadCurve(to: p(1.1, 0.2), control: p(1.1, 0.7)); ctx.strokePath()
            poly([(0.6, 0.5), (0.68, 0.32), (0.74, 0.48)])
        case .nanduti:
            for k in 0..<8 {
                let a = CGFloat(k) / 8 * .pi * 2
                poly([(0.6, 0.5), (0.6 + cos(a) * 0.45, 0.5 + sin(a) * 0.45)], fill: false)
            }
            ring(0.6, 0.5, 0.28)
        case .okir:
            ctx.move(to: p(0, 0.7)); ctx.addCurve(to: p(1.2, 0.7), control1: p(0.4, 0.1), control2: p(0.8, 1.1)); ctx.strokePath()
            spiral(0.45, 0.45, 0.16, turns: 1.0)
        case .rockDots:
            dot(0.2, 0.3, 0.09); dot(0.55, 0.3, 0.09); dot(0.375, 0.7, 0.09)
        }
    }
}
