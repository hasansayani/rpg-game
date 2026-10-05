import SpriteKit
import UIKit

/// Paints seamless, tileable parallax layers: a far ridge silhouette plus culture-specific landmarks.
/// All drawing is in image space (y down). `ground` is the y of the ridge at a given x.
enum SceneryPainter {
    enum Depth { case far, mid, near }

    static let tileWidth: CGFloat = 1200

    static func layer(scenery: Scenery, depth: Depth, color: RGBA, height: CGFloat, seed: UInt64) -> SKTexture {
        let w = tileWidth
        return TextureFactory.image(size: CGSize(width: w, height: height)) { ctx in
            var rng = SeededRandom(seed: seed)
            let style: FarStyle
            switch depth {
            case .far: style = scenery.far
            case .mid: style = scenery.far == .icebergs ? .icebergs : .rolling
            case .near: style = .rolling
            }
            let ridge = Ridge(style: style, width: w, height: height, depth: depth, rng: &rng)

            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: height))
            var x: CGFloat = 0
            while x <= w {
                path.addLine(to: CGPoint(x: x, y: ridge.y(at: x)))
                x += 4
            }
            path.addLine(to: CGPoint(x: w, y: height))
            path.closeSubpath()
            ctx.setFillColor(color.cgColor)
            ctx.addPath(path)
            ctx.fillPath()

            if depth == .far, scenery.far == .volcano {
                // Glowing crater / snow cap on the big cone.
                ctx.setFillColor(color.lighter(0.35).cgColor)
                let peak = ridge.volcanoPeak
                ctx.move(to: CGPoint(x: peak.x - 34, y: peak.y + 26))
                ctx.addLine(to: CGPoint(x: peak.x - 18, y: peak.y))
                ctx.addLine(to: CGPoint(x: peak.x + 18, y: peak.y))
                ctx.addLine(to: CGPoint(x: peak.x + 34, y: peak.y + 26))
                ctx.closePath(); ctx.fillPath()
            }

            // Landmarks sit on mid and near layers.
            guard depth != .far, !scenery.landmarks.isEmpty else { return }
            let count = depth == .mid ? 4 : 7
            let scale: CGFloat = depth == .mid ? 1.0 : 0.62
            var placed: [CGFloat] = []
            var attempts = 0
            while placed.count < count, attempts < 60 {
                attempts += 1
                let lx = CGFloat(rng.range(90, Double(w) - 90))
                if placed.contains(where: { abs($0 - lx) < 140 * scale }) { continue }
                placed.append(lx)
                let kind = scenery.landmarks[Int(rng.next() % UInt64(scenery.landmarks.count))]
                let s = scale * CGFloat(rng.range(0.8, 1.2))
                LandmarkPainter.draw(kind, ctx: ctx, at: CGPoint(x: lx, y: ridge.y(at: lx) + 3), scale: s, color: color)
            }
        }
    }

    /// Periodic silhouette profile so the texture tiles seamlessly.
    struct Ridge {
        let style: FarStyle
        let width: CGFloat
        let base: CGFloat
        let amp: CGFloat
        let terms: [(k: CGFloat, a: CGFloat, p: CGFloat)]
        let bumps: [(x: CGFloat, w: CGFloat, h: CGFloat)]
        var volcanoPeak: CGPoint = .zero

        init(style: FarStyle, width: CGFloat, height: CGFloat, depth: Depth, rng: inout SeededRandom) {
            self.style = style
            self.width = width
            switch depth {
            case .far: base = height * 0.55; amp = height * 0.38
            case .mid: base = height * 0.55; amp = height * 0.22
            case .near: base = height * 0.6; amp = height * 0.16
            }
            var t: [(k: CGFloat, a: CGFloat, p: CGFloat)] = []
            for k in [2, 3, 5, 8] {
                t.append((k: CGFloat(k), a: CGFloat(rng.range(0.4, 1.0)) / CGFloat(k).squareRoot(), p: CGFloat(rng.range(0, 6.28))))
            }
            terms = t
            var b: [(x: CGFloat, w: CGFloat, h: CGFloat)] = []
            if style == .karst || style == .icebergs || style == .mesas {
                let n = style == .karst ? 9 : 5
                for i in 0..<n {
                    let x = width * (CGFloat(i) + CGFloat(rng.range(0.2, 0.8))) / CGFloat(n)
                    b.append((x: x, w: CGFloat(rng.range(40, 90)), h: CGFloat(rng.range(0.5, 1.0))))
                }
            }
            bumps = b
            if style == .volcano {
                volcanoPeak = CGPoint(x: width * 0.5, y: base - amp * 1.15)
            }
        }

        func wave(_ x: CGFloat) -> CGFloat {
            var v: CGFloat = 0
            for t in terms { v += t.a * sin(t.k * 2 * .pi * x / width + t.p) }
            return v / 1.6
        }

        func y(at x: CGFloat) -> CGFloat {
            switch style {
            case .peaks:
                // Sharpen sines into peaks.
                var v: CGFloat = 0
                for t in terms { v += t.a * (1 - abs(sin(t.k * .pi * x / width + t.p))) }
                return base + amp * 0.6 - amp * v * 0.9
            case .dunes, .rolling:
                return base - amp * 0.6 * wave(x) - (style == .dunes ? amp * 0.1 : 0)
            case .volcano:
                let d = abs(x - volcanoPeak.x)
                let cone = max(0, 1 - d / (width * 0.28))
                let coneY = base - amp * 1.15 * pow(cone, 1.4)
                let crater: CGFloat = d < 18 ? 8 : 0
                return min(base - amp * 0.2 * wave(x), coneY + crater)
            case .karst, .icebergs, .mesas:
                var y = base - amp * 0.15 * wave(x)
                for b in bumps {
                    let d = abs(x - b.x) / b.w
                    guard d < 1 else { continue }
                    let shape: CGFloat
                    switch style {
                    case .karst: shape = sqrt(1 - d * d)                 // rounded towers
                    case .icebergs: shape = 1 - d                         // jagged triangles
                    default: shape = d < 0.7 ? 1 : (1 - d) / 0.3         // flat-topped mesas
                    }
                    y = min(y, base - amp * b.h * shape * 1.1)
                }
                return y
            case .cliffs:
                // A long escarpment with a step, periodic over the tile.
                let s = sin(2 * .pi * x / width)
                let step: CGFloat = s > 0.1 ? 1 : (s < -0.1 ? 0.35 : 0.35 + (s + 0.1) / 0.2 * 0.65)
                return base - amp * step * 0.9 - amp * 0.08 * wave(x)
            }
        }
    }
}

/// Simple, readable silhouettes for 28 landmark types. Nominal height ≈ 70pt at scale 1.
/// Origin is the ground point; up is negative y.
enum LandmarkPainter {
    static func draw(_ kind: Landmark, ctx: CGContext, at o: CGPoint, scale s: CGFloat, color: RGBA) {
        ctx.saveGState()
        ctx.translateBy(x: o.x, y: o.y)
        ctx.scaleBy(x: s, y: s)
        ctx.setFillColor(color.cgColor)
        ctx.setStrokeColor(color.cgColor)

        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            ctx.fill(CGRect(x: x, y: -y - h, width: w, height: h))
        }
        func poly(_ pts: [(CGFloat, CGFloat)]) {
            guard let f = pts.first else { return }
            ctx.move(to: CGPoint(x: f.0, y: -f.1))
            for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: p.0, y: -p.1)) }
            ctx.closePath(); ctx.fillPath()
        }
        func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
            ctx.fillEllipse(in: CGRect(x: cx - rx, y: -cy - ry, width: rx * 2, height: ry * 2))
        }

        switch kind {
        case .columns:
            rect(-40, 0, 80, 6)
            for i in 0..<4 { rect(-34 + CGFloat(i) * 20, 6, 8, 46) }
            rect(-40, 52, 80, 6)
            poly([(-42, 58), (0, 76), (42, 58)])
        case .pine:
            rect(-3, 0, 6, 12)
            poly([(-18, 10), (0, 40), (18, 10)])
            poly([(-14, 28), (0, 58), (14, 28)])
            poly([(-10, 44), (0, 72), (10, 44)])
        case .pyramid:
            poly([(-70, 0), (0, 70), (70, 0)])
        case .palm:
            ctx.setLineWidth(5)
            ctx.move(to: CGPoint(x: 0, y: 0))
            ctx.addQuadCurve(to: CGPoint(x: 10, y: -60), control: CGPoint(x: -8, y: -30))
            ctx.strokePath()
            for a in stride(from: -2.6, through: -0.5, by: 0.52) {
                let tip = CGPoint(x: 10 + cos(a) * 30, y: -60 + sin(a) * 18 + 10)
                ctx.move(to: CGPoint(x: 10, y: -60))
                ctx.addQuadCurve(to: tip, control: CGPoint(x: 10 + cos(a) * 18, y: -72))
                ctx.setLineWidth(4); ctx.strokePath()
            }
        case .obelisk:
            poly([(-7, 0), (-5, 64), (0, 74), (5, 64), (7, 0)])
        case .longhouse:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: -50, y: 0)); p.addLine(to: CGPoint(x: -50, y: -18))
            p.addQuadCurve(to: CGPoint(x: 50, y: -18), controlPoint: CGPoint(x: 0, y: -52))
            p.addLine(to: CGPoint(x: 50, y: 0)); p.close()
            ctx.addPath(p.cgPath); ctx.fillPath()
        case .standingStones:
            for (x, h) in [(-30, 36), (-6, 52), (18, 30), (36, 44)] as [(CGFloat, CGFloat)] {
                ctx.addPath(UIBezierPath(roundedRect: CGRect(x: x - 7, y: -h, width: 14, height: h), cornerRadius: 6).cgPath)
                ctx.fillPath()
            }
        case .torii:
            rect(-26, 0, 6, 54); rect(20, 0, 6, 54)
            rect(-30, 42, 60, 5)
            let p = UIBezierPath()
            p.move(to: CGPoint(x: -40, y: -56)); p.addQuadCurve(to: CGPoint(x: 40, y: -56), controlPoint: CGPoint(x: 0, y: -50))
            p.addLine(to: CGPoint(x: 36, y: -63)); p.addQuadCurve(to: CGPoint(x: -36, y: -63), controlPoint: CGPoint(x: 0, y: -58)); p.close()
            ctx.addPath(p.cgPath); ctx.fillPath()
        case .pagoda:
            var y: CGFloat = 0
            var w: CGFloat = 26
            for _ in 0..<4 {
                rect(-w * 0.6, y, w * 1.2, 10)
                poly([(-w - 8, y + 10), (-w * 0.6, y + 16), (w * 0.6, y + 16), (w + 8, y + 10), (w * 0.4, y + 20), (-w * 0.4, y + 20)])
                y += 18; w -= 5
            }
            rect(-1.5, y, 3, 12)
        case .stepPyramid:
            var w: CGFloat = 70
            for i in 0..<5 { rect(-w, CGFloat(i) * 12, w * 2, 12); w -= 12 }
            rect(-12, 60, 24, 14)
        case .cactus:
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: -6, y: -58, width: 12, height: 58), cornerRadius: 6).cgPath)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: -20, y: -40, width: 9, height: 24), cornerRadius: 4.5).cgPath)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 11, y: -48, width: 9, height: 22), cornerRadius: 4.5).cgPath)
            ctx.fillPath()
            rect(-14, 18, 10, 6); rect(4, 24, 10, 6)
        case .hut:
            rect(-20, 0, 40, 22)
            poly([(-28, 20), (0, 46), (28, 20)])
        case .shikhara:
            rect(-30, 0, 60, 14)
            let p = UIBezierPath()
            p.move(to: CGPoint(x: -22, y: -14))
            p.addCurve(to: CGPoint(x: 0, y: -76), controlPoint1: CGPoint(x: -24, y: -48), controlPoint2: CGPoint(x: -10, y: -70))
            p.addCurve(to: CGPoint(x: 22, y: -14), controlPoint1: CGPoint(x: 10, y: -70), controlPoint2: CGPoint(x: 24, y: -48))
            p.close()
            ctx.addPath(p.cgPath); ctx.fillPath()
            ellipse(0, 80, 5, 4)
        case .ziggurat:
            rect(-64, 0, 128, 18); rect(-46, 18, 92, 16); rect(-28, 34, 56, 14); rect(-12, 48, 24, 12)
        case .baobab:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: -14, y: 0))
            p.addQuadCurve(to: CGPoint(x: -9, y: -46), controlPoint: CGPoint(x: -20, y: -24))
            p.addLine(to: CGPoint(x: 9, y: -46))
            p.addQuadCurve(to: CGPoint(x: 14, y: 0), controlPoint: CGPoint(x: 20, y: -24))
            p.close()
            ctx.addPath(p.cgPath); ctx.fillPath()
            ctx.setLineWidth(3.5)
            for a in [-2.5, -2.0, -1.6, -1.1, -0.6] as [CGFloat] {
                ctx.move(to: CGPoint(x: 0, y: -44))
                ctx.addLine(to: CGPoint(x: cos(a) * 26, y: -44 + sin(a) * 20))
            }
            ctx.strokePath()
        case .fern:
            ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: 0, y: 0)); ctx.addLine(to: CGPoint(x: 2, y: -50)); ctx.strokePath()
            for a in stride(from: -3.0, through: -0.1, by: 0.48) {
                let tip = CGPoint(x: 2 + cos(a) * 32, y: -50 + sin(a) * 10 + 18)
                ctx.move(to: CGPoint(x: 2, y: -50))
                ctx.addQuadCurve(to: tip, control: CGPoint(x: 2 + cos(a) * 20, y: -64))
                ctx.setLineWidth(2.5); ctx.strokePath()
            }
        case .onionDome:
            rect(-12, 0, 24, 40)
            let p = UIBezierPath()
            p.move(to: CGPoint(x: -12, y: -40))
            p.addCurve(to: CGPoint(x: 0, y: -74), controlPoint1: CGPoint(x: -24, y: -54), controlPoint2: CGPoint(x: -4, y: -62))
            p.addCurve(to: CGPoint(x: 12, y: -40), controlPoint1: CGPoint(x: 4, y: -62), controlPoint2: CGPoint(x: 24, y: -54))
            p.close()
            ctx.addPath(p.cgPath); ctx.fillPath()
            rect(-1, 72, 2, 10)
        case .birch:
            rect(-2.5, 0, 5, 56)
            ellipse(0, 50, 14, 20)
        case .acacia:
            ctx.setLineWidth(4)
            ctx.move(to: CGPoint(x: 0, y: 0)); ctx.addLine(to: CGPoint(x: 0, y: -30))
            ctx.addLine(to: CGPoint(x: -12, y: -46)); ctx.move(to: CGPoint(x: 0, y: -30)); ctx.addLine(to: CGPoint(x: 14, y: -44))
            ctx.strokePath()
            ellipse(0, 50, 40, 8)
        case .inuksuk:
            rect(-14, 0, 9, 22); rect(5, 0, 9, 22)
            rect(-18, 22, 36, 8)
            rect(-10, 30, 20, 14)
            rect(-26, 44, 52, 7)
            rect(-7, 51, 14, 12)
        case .igloo:
            ctx.move(to: CGPoint(x: -34, y: 0))
            ctx.addArc(center: .zero, radius: 34, startAngle: .pi, endAngle: 0, clockwise: false)
            ctx.closePath(); ctx.fillPath()
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 20, y: -16, width: 22, height: 16), cornerRadius: 8).cgPath)
            ctx.fillPath()
        case .dome:
            rect(-36, 0, 72, 26)
            ellipse(0, 26, 26, 26)
            rect(-48, 0, 7, 58); rect(41, 0, 7, 58)
            ellipse(-44.5, 58, 4, 5); ellipse(44.5, 58, 4, 5)
        case .terraces:
            for i in 0..<5 {
                let w = CGFloat(90 - i * 15)
                rect(-w, CGFloat(i) * 10, w * 2, 10)
            }
            rect(-8, 50, 16, 10)
            poly([(-12, 60), (0, 70), (12, 60)])
        case .yurt:
            rect(-26, 0, 52, 20)
            poly([(-30, 20), (0, 36), (30, 20)])
            rect(-1.5, 36, 3, 6)
        case .cairn:
            ellipse(0, 6, 24, 8); ellipse(0, 18, 18, 7); ellipse(0, 28, 12, 6); ellipse(0, 36, 7, 5)
            rect(-1, 36, 2, 30)
            poly([(1, 66), (18, 60), (1, 54)])
        case .lionGate:
            rect(-56, 0, 26, 56); rect(30, 0, 26, 56)
            rect(-30, 44, 60, 12)
            ellipse(-43, 60, 10, 8); ellipse(43, 60, 10, 8)
        case .moai:
            rect(-60, 0, 120, 8)
            for x in [-38, 0, 38] as [CGFloat] {
                ctx.addPath(UIBezierPath(roundedRect: CGRect(x: x - 11, y: -62, width: 22, height: 54), cornerRadius: 4).cgPath)
                ctx.fillPath()
                rect(x - 13, 50, 26, 6)          // heavy brow
                poly([(x + 9, 46), (x + 15, 34), (x + 9, 30)]) // nose
            }
        case .granary:
            for x in [-18, 18] as [CGFloat] {
                rect(x - 11, 0, 22, 26)
                poly([(x - 16, 24), (x, 46), (x + 16, 24)])
            }
        }
        ctx.restoreGState()
    }
}
