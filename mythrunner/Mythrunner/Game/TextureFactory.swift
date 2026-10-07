import SpriteKit
import UIKit

/// Procedural art: every texture is drawn once with Core Graphics and reused,
/// so the prototype needs zero image assets and draw calls stay low.
/// Images use UIKit coordinates (y down); `flipY` helpers convert from world space.
enum TextureFactory {
    /// Cap texture scale at 2x: indistinguishable on flat-color art, saves ~55% memory on 3x phones.
    static var scale: CGFloat { min(UIScreen.main.scale, 2) }

    static func image(size: CGSize, opaque: Bool = false, _ draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = opaque
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in draw(ctx.cgContext) }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return tex
    }

    // MARK: Sky

    static func skyGradient(top: RGBA, bottom: RGBA) -> SKTexture {
        image(size: CGSize(width: 4, height: 256), opaque: true) { ctx in
            linearGradient(ctx, colors: [top, bottom], from: .zero, to: CGPoint(x: 0, y: 256))
        }
    }

    static func softDot(diameter: CGFloat = 64, color: RGBA = RGBA(r: 1, g: 1, b: 1)) -> SKTexture {
        image(size: CGSize(width: diameter, height: diameter)) { ctx in
            let c = CGPoint(x: diameter / 2, y: diameter / 2)
            radialGradient(ctx, colors: [color, color.withAlpha(0)], center: c, radius: diameter / 2)
        }
    }

    static func disc(diameter: CGFloat, color: RGBA) -> SKTexture {
        image(size: CGSize(width: diameter, height: diameter)) { ctx in
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        }
    }

    static func verticalFade(color: RGBA, height: CGFloat = 128, topAlpha: Double, bottomAlpha: Double) -> SKTexture {
        image(size: CGSize(width: 4, height: height)) { ctx in
            linearGradient(ctx, colors: [color.withAlpha(topAlpha), color.withAlpha(bottomAlpha)],
                           from: .zero, to: CGPoint(x: 0, y: height))
        }
    }

    static func vignette(size: CGSize) -> SKTexture {
        image(size: size) { ctx in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let black = RGBA(r: 0, g: 0, b: 0)
            let colors = [black.withAlpha(0), black.withAlpha(0), black.withAlpha(1)].map(\.cgColor) as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
            ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c,
                                   endRadius: hypot(size.width, size.height) / 2, options: .drawsAfterEndLocation)
        }
    }

    // MARK: Terrain

    /// One chunk of ground. World x in [x0, x0+width), world y from 0 to `height`.
    static func terrainChunk(course: Course, x0: Double, width: CGFloat, height: CGFloat,
                             ground: RGBA, edge: RGBA) -> SKTexture {
        image(size: CGSize(width: width, height: height)) { ctx in
            let step: CGFloat = 6
            // Build ground polygons, splitting at gaps.
            var segments: [[CGPoint]] = []
            var current: [CGPoint] = []
            var x: CGFloat = 0
            while x <= width + 0.01 {
                let wx = x0 + Double(x)
                if let g = course.ground(at: wx) {
                    current.append(CGPoint(x: x, y: height - CGFloat(g)))
                } else if !current.isEmpty {
                    segments.append(current)
                    current = []
                }
                x += step
            }
            if !current.isEmpty { segments.append(current) }

            for seg in segments {
                guard let first = seg.first, let last = seg.last else { continue }
                let path = CGMutablePath()
                path.move(to: CGPoint(x: first.x, y: height))
                for p in seg { path.addLine(to: p) }
                path.addLine(to: CGPoint(x: last.x, y: height))
                path.closeSubpath()

                // Body: soft vertical gradient for depth.
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                let minY = seg.map(\.y).min() ?? 0
                linearGradient(ctx, colors: [ground, ground.mixed(with: edge, 0.55).darker(0.08)],
                               from: CGPoint(x: 0, y: minY), to: CGPoint(x: 0, y: height))
                ctx.restoreGState()

                // Rim highlight along the surface (the Alto "snow line").
                let rim = CGMutablePath()
                rim.addLines(between: seg)
                ctx.addPath(rim)
                ctx.setStrokeColor(edge.cgColor)
                ctx.setLineWidth(5)
                ctx.setLineJoin(.round)
                ctx.setLineCap(.round)
                ctx.strokePath()
                ctx.addPath(rim)
                ctx.setStrokeColor(ground.lighter(0.5).cgColor)
                ctx.setLineWidth(1.5)
                ctx.strokePath()
            }
        }
    }

    static func rock(color: RGBA) -> SKTexture {
        image(size: CGSize(width: 64, height: 56)) { ctx in
            let body = UIBezierPath()
            body.move(to: CGPoint(x: 2, y: 56))
            body.addCurve(to: CGPoint(x: 22, y: 6), controlPoint1: CGPoint(x: 0, y: 30), controlPoint2: CGPoint(x: 8, y: 10))
            body.addCurve(to: CGPoint(x: 52, y: 14), controlPoint1: CGPoint(x: 34, y: 0), controlPoint2: CGPoint(x: 46, y: 4))
            body.addCurve(to: CGPoint(x: 62, y: 56), controlPoint1: CGPoint(x: 62, y: 26), controlPoint2: CGPoint(x: 64, y: 44))
            body.close()
            ctx.setFillColor(color.cgColor)
            ctx.addPath(body.cgPath)
            ctx.fillPath()
            // Facet highlight.
            ctx.setFillColor(color.lighter(0.25).cgColor)
            ctx.move(to: CGPoint(x: 22, y: 8)); ctx.addLine(to: CGPoint(x: 34, y: 30)); ctx.addLine(to: CGPoint(x: 14, y: 40))
            ctx.closePath(); ctx.fillPath()
        }
    }

    // MARK: Characters

    static func heart(color: RGBA) -> SKTexture {
        image(size: CGSize(width: 32, height: 28)) { ctx in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 16, y: 27))
            p.addCurve(to: CGPoint(x: 1, y: 9), controlPoint1: CGPoint(x: 8, y: 21), controlPoint2: CGPoint(x: 1, y: 16))
            p.addArc(withCenter: CGPoint(x: 8.5, y: 8.5), radius: 7.5, startAngle: .pi, endAngle: 0, clockwise: true)
            p.addArc(withCenter: CGPoint(x: 23.5, y: 8.5), radius: 7.5, startAngle: .pi, endAngle: 0, clockwise: true)
            p.addCurve(to: CGPoint(x: 16, y: 27), controlPoint1: CGPoint(x: 31, y: 16), controlPoint2: CGPoint(x: 24, y: 21))
            ctx.setFillColor(color.cgColor)
            ctx.addPath(p.cgPath)
            ctx.fillPath()
        }
    }

    static func relic(color: RGBA) -> SKTexture {
        image(size: CGSize(width: 44, height: 44)) { ctx in
            let c = CGPoint(x: 22, y: 22)
            radialGradient(ctx, colors: [color.withAlpha(0.9), color.withAlpha(0)], center: c, radius: 22)
            // Diamond gem
            ctx.setFillColor(RGBA(r: 1, g: 1, b: 1).cgColor)
            ctx.move(to: CGPoint(x: 22, y: 9)); ctx.addLine(to: CGPoint(x: 32, y: 22))
            ctx.addLine(to: CGPoint(x: 22, y: 35)); ctx.addLine(to: CGPoint(x: 12, y: 22))
            ctx.closePath(); ctx.fillPath()
            ctx.setFillColor(color.lighter(0.3).cgColor)
            ctx.move(to: CGPoint(x: 22, y: 13)); ctx.addLine(to: CGPoint(x: 28, y: 22))
            ctx.addLine(to: CGPoint(x: 22, y: 22)); ctx.closePath(); ctx.fillPath()
        }
    }

    static func projectile(color: RGBA, high: Bool) -> SKTexture {
        image(size: CGSize(width: 48, height: 48)) { ctx in
            let c = CGPoint(x: 24, y: 24)
            radialGradient(ctx, colors: [color.lighter(0.6), color, color.withAlpha(0)], center: c, radius: 24)
            if !high {
                ctx.setFillColor(color.darker(0.35).cgColor)
                ctx.fillEllipse(in: CGRect(x: 10, y: 10, width: 28, height: 28))
                ctx.setFillColor(color.darker(0.1).cgColor)
                ctx.fillEllipse(in: CGRect(x: 15, y: 13, width: 10, height: 8))
            }
        }
    }

    static func warningMarker(color: RGBA) -> SKTexture {
        image(size: CGSize(width: 36, height: 36)) { ctx in
            ctx.setFillColor(color.cgColor)
            ctx.move(to: CGPoint(x: 18, y: 2)); ctx.addLine(to: CGPoint(x: 34, y: 32)); ctx.addLine(to: CGPoint(x: 2, y: 32))
            ctx.closePath(); ctx.fillPath()
            ctx.setFillColor(RGBA(r: 1, g: 1, b: 1).cgColor)
            ctx.fill(CGRect(x: 16, y: 11, width: 4, height: 12))
            ctx.fill(CGRect(x: 16, y: 25, width: 4, height: 4))
        }
    }

    // MARK: Helpers

    static func linearGradient(_ ctx: CGContext, colors: [RGBA], from: CGPoint, to: CGPoint) {
        let cg = colors.map(\.cgColor) as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cg, locations: nil) else { return }
        ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func radialGradient(_ ctx: CGContext, colors: [RGBA], center: CGPoint, radius: CGFloat) {
        let cg = colors.map(\.cgColor) as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cg, locations: nil) else { return }
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
}
