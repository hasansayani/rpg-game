import SpriteKit
import UIKit

/// A jointed body pose for the Wayfarer. Angles are radians; limb angles are measured from
/// "straight down the body" and positive swings forward (toward the facing direction).
struct RunnerPose {
    /// Torso tilt: 0 = upright, positive leans forward, π/2 = horizontal (swimming).
    var lean: CGFloat = 0
    /// Hip offset in texture points (y down), e.g. lower for a crouch, bobbing in the run cycle.
    var hip = CGPoint.zero
    /// (thigh, knee) for the near leg [0] and far leg [1]. Knee is relative to the thigh; negative bends back.
    var legs: [(CGFloat, CGFloat)] = [(0, 0), (0, 0)]
    /// (upper arm, elbow) for the near arm [0] and far arm [1]. Elbow is relative; positive bends forward.
    var arms: [(CGFloat, CGFloat)] = [(0, 0.3), (0, 0.3)]

    static func run(_ phase: CGFloat) -> RunnerPose {
        var p = RunnerPose(lean: 0.2)
        p.hip = CGPoint(x: 0, y: -1.6 * abs(sin(phase)))
        for side in 0..<2 {
            let ψ = phase + CGFloat(side) * .pi
            let thigh = 0.8 * sin(ψ)
            // The knee folds most while the leg swings back through to the front.
            let knee = -0.25 - 1.25 * max(0, -cos(ψ))
            p.legs[side] = (thigh, knee)
            p.arms[side] = (-0.75 * sin(ψ), 1.5)
        }
        return p
    }

    static func crouch(_ depth: CGFloat) -> RunnerPose {
        RunnerPose(lean: 0.15 + 0.3 * depth, hip: CGPoint(x: 0, y: 7 * depth),
                   legs: [(1.0 * depth, -1.8 * depth), (0.8 * depth, -1.6 * depth)],
                   arms: [(-0.9 * depth, 0.6), (-0.7 * depth, 0.6)])
    }

    static let jump = RunnerPose(lean: 0.12, hip: .zero,
                                 legs: [(0.9, -1.3), (-0.35, -0.5)], arms: [(2.5, 0.3), (2.2, 0.4)])
    static let fall = RunnerPose(lean: 0.05, hip: .zero,
                                 legs: [(0.55, -0.5), (0.2, -0.35)], arms: [(1.7, 0.4), (-0.7, 0.4)])
    /// Knees to chest, arms hugging the shins: the compact flip shape (small moment of inertia).
    static let tuck = RunnerPose(lean: 0.45, hip: CGPoint(x: 0, y: -4),
                                 legs: [(2.0, -2.5), (1.85, -2.4)], arms: [(1.3, 1.5), (1.15, 1.6)])
    static let land = RunnerPose(lean: 0.4, hip: CGPoint(x: 0, y: 6),
                                 legs: [(0.95, -1.7), (0.6, -1.3)], arms: [(0.9, 0.5), (-0.6, 0.5)])
    static let stumble = RunnerPose(lean: 0.75, hip: CGPoint(x: 0, y: 3),
                                    legs: [(0.7, -0.9), (-0.45, -0.3)], arms: [(2.3, 0.2), (-1.3, 0.3)])

    static func swim(_ phase: CGFloat) -> RunnerPose {
        var p = RunnerPose(lean: .pi / 2)
        p.hip = CGPoint(x: -4, y: 0)
        for side in 0..<2 {
            let ψ = phase + CGFloat(side) * .pi
            p.legs[side] = (0.22 * sin(2 * ψ), -0.25)          // flutter kick
            p.arms[side] = (.pi + ψ, 0.25 + 0.4 * max(0, sin(ψ))) // overarm crawl stroke
        }
        return p
    }
}

/// Appearance for the Wayfarer in a realm: outfit colors and the culture's motif.
struct RunnerLook {
    var cloak: RGBA
    var trim: RGBA
    var motif: Motif
    var skin = RGBA(r: 0.93, g: 0.76, b: 0.6)
    var boots = RGBA(r: 0.26, g: 0.17, b: 0.12)
}

extension TextureFactory {
    static let runnerCanvas = CGSize(width: 56, height: 60)
    /// Hip position in the canvas (y down). The feet of a standing pose sit ~20 pt below it.
    static let runnerHip = CGPoint(x: 28, y: 36)

    /// Draws the Wayfarer in `pose`, facing right, hooded, in the realm's motif.
    static func runner(_ pose: RunnerPose, look: RunnerLook) -> SKTexture {
        image(size: runnerCanvas) { ctx in
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let hip = CGPoint(x: runnerHip.x + pose.hip.x, y: runnerHip.y + pose.hip.y)
            let up = CGPoint(x: sin(pose.lean), y: -cos(pose.lean))
            let down = CGPoint(x: -up.x, y: -up.y)
            func dir(_ a: CGFloat) -> CGPoint {
                // Rotate the body's "down" vector forward by `a`.
                CGPoint(x: down.x * cos(a) + down.y * sin(a), y: -down.x * sin(a) + down.y * cos(a))
            }
            func offset(_ p: CGPoint, _ d: CGPoint, _ len: CGFloat) -> CGPoint { CGPoint(x: p.x + d.x * len, y: p.y + d.y * len) }
            let neck = offset(hip, up, 15)
            let shoulder = offset(neck, down, 2.5)
            let head = offset(neck, up, 6.5)

            func limb(_ from: CGPoint, _ a1: CGFloat, _ l1: CGFloat, _ a2: CGFloat, _ l2: CGFloat,
                      width: CGFloat, color: RGBA, end: RGBA, endSize: CGFloat) {
                let mid = offset(from, dir(a1), l1)
                let tip = offset(mid, dir(a1 + a2), l2)
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(width)
                ctx.move(to: from); ctx.addLine(to: mid); ctx.addLine(to: tip); ctx.strokePath()
                ctx.setFillColor(end.cgColor)
                ctx.fillEllipse(in: CGRect(x: tip.x - endSize / 2, y: tip.y - endSize / 2, width: endSize, height: endSize))
            }
            let far = look.cloak.darker(0.45)
            // Far limbs (behind the body).
            limb(shoulder, pose.arms[1].0, 7.5, pose.arms[1].1, 7, width: 3.6, color: far, end: look.skin.darker(0.3), endSize: 3.6)
            limb(hip, pose.legs[1].0, 10, pose.legs[1].1, 10, width: 4.6, color: far, end: look.boots.darker(0.2), endSize: 5)

            // Tunic: a tapered shape along the torso axis, flaring at the hem, with the motif band.
            let side = CGPoint(x: -up.y, y: up.x)  // perpendicular to the torso
            let hem = offset(hip, down, 5)
            let tunic = UIBezierPath()
            tunic.move(to: offset(neck, side, 5.5))
            tunic.addLine(to: offset(hem, side, 8))
            tunic.addQuadCurve(to: offset(hem, side, -8), controlPoint: offset(offset(hem, down, 2.5), side, 0))
            tunic.addLine(to: offset(neck, side, -5.5))
            tunic.close()
            ctx.saveGState()
            ctx.addPath(tunic.cgPath); ctx.clip()
            linearGradient(ctx, colors: [look.cloak.lighter(0.18), look.cloak, look.cloak.darker(0.3)],
                           from: offset(neck, side, 6), to: offset(hem, side, -8))
            // Motif band across the hem (drawn in an axis-aligned frame rotated to the torso).
            ctx.translateBy(x: hem.x, y: hem.y)
            ctx.rotate(by: pose.lean)
            MotifPainter.band(look.motif, in: CGRect(x: -10, y: -5, width: 20, height: 5), ctx: ctx,
                              ink: look.trim, base: look.trim.darker(0.55))
            ctx.restoreGState()
            // Belt.
            ctx.setStrokeColor(RGBA(r: 0.42, g: 0.27, b: 0.16).cgColor)
            ctx.setLineWidth(1.6)
            let belt = offset(hip, up, 2)
            ctx.move(to: offset(belt, side, 6)); ctx.addLine(to: offset(belt, side, -6)); ctx.strokePath()

            // Near limbs.
            limb(hip, pose.legs[0].0, 10, pose.legs[0].1, 10, width: 5, color: look.cloak.darker(0.3), end: look.boots, endSize: 5.4)
            limb(shoulder, pose.arms[0].0, 7.5, pose.arms[0].1, 7, width: 4, color: look.cloak.darker(0.08), end: look.skin, endSize: 3.8)

            // Head and hood (the hood's peak trails behind the head).
            ctx.setFillColor(look.cloak.darker(0.15).cgColor)
            ctx.fillEllipse(in: CGRect(x: head.x - 7, y: head.y - 7, width: 14, height: 14))
            let back = CGPoint(x: -cos(pose.lean), y: -sin(pose.lean))
            let peakBase1 = offset(head, up, 5), peakBase2 = offset(head, back, 5)
            ctx.move(to: peakBase1); ctx.addLine(to: offset(offset(head, back, 9), up, 6)); ctx.addLine(to: peakBase2); ctx.fillPath()
            let face = offset(head, CGPoint(x: cos(pose.lean), y: sin(pose.lean)), 2.2)
            ctx.setFillColor(look.skin.cgColor)
            ctx.fillEllipse(in: CGRect(x: face.x - 4.2, y: face.y - 4.4, width: 8.4, height: 8.8))
            let eye = offset(face, CGPoint(x: cos(pose.lean), y: sin(pose.lean)), 2)
            ctx.setFillColor(RGBA(r: 0.1, g: 0.08, b: 0.1).cgColor)
            ctx.fillEllipse(in: CGRect(x: eye.x - 0.9, y: eye.y - 1.4, width: 1.8, height: 2.2))
            // A band of trim where the hood meets the tunic.
            ctx.setStrokeColor(look.trim.cgColor)
            ctx.setLineWidth(2.2)
            ctx.move(to: offset(neck, side, 4)); ctx.addLine(to: offset(neck, side, -4)); ctx.strokePath()
        }
    }
}

/// Every frame the Wayfarer needs, drawn once per realm.
struct RunnerFrames {
    let run: [SKTexture]
    let swim: [SKTexture]
    let crouch: SKTexture
    let jump: SKTexture
    let fall: SKTexture
    let tuck: SKTexture
    let land: SKTexture
    let stumble: SKTexture

    init(look: RunnerLook) {
        let cycle = 8
        run = (0..<cycle).map { TextureFactory.runner(.run(CGFloat($0) / CGFloat(cycle) * .pi * 2), look: look) }
        swim = (0..<cycle).map { TextureFactory.runner(.swim(CGFloat($0) / CGFloat(cycle) * .pi * 2), look: look) }
        crouch = TextureFactory.runner(.crouch(1), look: look)
        jump = TextureFactory.runner(.jump, look: look)
        fall = TextureFactory.runner(.fall, look: look)
        tuck = TextureFactory.runner(.tuck, look: look)
        land = TextureFactory.runner(.land, look: look)
        stumble = TextureFactory.runner(.stumble, look: look)
    }
}
