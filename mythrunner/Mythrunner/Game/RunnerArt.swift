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
    /// Drawn at 4× pixel density (the sprite is shown at half its texture size) with natural
    /// proportions, tapered limbs with rounded joints, shaped shoes and hands, and a profiled face.
    static func runner(_ pose: RunnerPose, look: RunnerLook) -> SKTexture {
        image(size: CGSize(width: runnerCanvas.width * 2, height: runnerCanvas.height * 2)) { ctx in
            ctx.scaleBy(x: 2, y: 2)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let hip = CGPoint(x: runnerHip.x + pose.hip.x, y: runnerHip.y + pose.hip.y)
            let up = CGPoint(x: sin(pose.lean), y: -cos(pose.lean))
            let down = CGPoint(x: -up.x, y: -up.y)
            let forward = CGPoint(x: cos(pose.lean), y: sin(pose.lean))
            func dir(_ a: CGFloat) -> CGPoint {
                CGPoint(x: down.x * cos(a) + down.y * sin(a), y: -down.x * sin(a) + down.y * cos(a))
            }
            func off(_ p: CGPoint, _ d: CGPoint, _ len: CGFloat) -> CGPoint { CGPoint(x: p.x + d.x * len, y: p.y + d.y * len) }
            let outline = RGBA(r: 0.08, g: 0.07, b: 0.1, a: 0.55)

            /// A tapered capsule from `a` (width wa) to `b` (width wb), with a soft outline and a lit edge.
            func segment(_ a: CGPoint, _ b: CGPoint, _ wa: CGFloat, _ wb: CGFloat, _ color: RGBA) {
                let dx = b.x - a.x, dy = b.y - a.y
                let len = max(sqrt(dx * dx + dy * dy), 0.001)
                let n = CGPoint(x: -dy / len, y: dx / len)
                func shape(_ grow: CGFloat) -> CGPath {
                    let p = CGMutablePath()
                    let ha = wa / 2 + grow, hb = wb / 2 + grow
                    p.move(to: off(a, n, ha)); p.addLine(to: off(b, n, hb))
                    p.addLine(to: off(b, n, -hb)); p.addLine(to: off(a, n, -ha)); p.closeSubpath()
                    p.addEllipse(in: CGRect(x: a.x - ha, y: a.y - ha, width: ha * 2, height: ha * 2))
                    p.addEllipse(in: CGRect(x: b.x - hb, y: b.y - hb, width: hb * 2, height: hb * 2))
                    return p
                }
                ctx.setFillColor(outline.cgColor); ctx.addPath(shape(0.55)); ctx.fillPath()
                ctx.setFillColor(color.cgColor); ctx.addPath(shape(0)); ctx.fillPath()
                // Light from the front-top: a thin highlight along one side.
                ctx.setStrokeColor(color.lighter(0.28).withAlpha(0.7).cgColor)
                ctx.setLineWidth(min(wa, wb) * 0.28)
                ctx.move(to: off(a, n, -wa * 0.22)); ctx.addLine(to: off(b, n, -wb * 0.22)); ctx.strokePath()
            }

            func leg(_ side: Int, near: Bool) {
                let (t, k) = pose.legs[side]
                let knee = off(hip, dir(t), 10.5)
                let ankle = off(knee, dir(t + k), 10)
                let pants = near ? look.cloak.darker(0.32) : look.cloak.darker(0.5)
                segment(hip, knee, 4.4, 3.4, pants)
                segment(knee, ankle, 3.3, 2.3, pants)
                // Shoe: heel behind the ankle, toe pointing along the foot (perpendicular to the shin).
                let shin = dir(t + k)
                let foot = CGPoint(x: shin.y, y: -shin.x)
                let boots = near ? look.boots : look.boots.darker(0.2)
                segment(off(ankle, foot, -1.2), off(ankle, foot, 4.6), 2.9, 2.2, boots)
                // Ankle wrap in the trim color.
                ctx.setFillColor(look.trim.withAlpha(near ? 0.9 : 0.6).cgColor)
                ctx.fillEllipse(in: CGRect(x: ankle.x - 1.6, y: ankle.y - 1.6, width: 3.2, height: 3.2))
            }

            let neck = off(hip, up, 14)
            let shoulder = off(neck, down, 2.2)
            func arm(_ side: Int, near: Bool) {
                let (u, e) = pose.arms[side]
                let elbow = off(shoulder, dir(u), 7.2)
                let wrist = off(elbow, dir(u + e), 6.6)
                let sleeve = near ? look.cloak.darker(0.05) : look.cloak.darker(0.4)
                segment(shoulder, elbow, 3.2, 2.6, sleeve)
                segment(elbow, wrist, 2.5, 1.9, near ? look.cloak.darker(0.12) : sleeve.darker(0.1))
                let hand = off(wrist, dir(u + e), 1.4)
                ctx.setFillColor(outline.cgColor)
                ctx.fillEllipse(in: CGRect(x: hand.x - 1.95, y: hand.y - 1.95, width: 3.9, height: 3.9))
                ctx.setFillColor((near ? look.skin : look.skin.darker(0.25)).cgColor)
                ctx.fillEllipse(in: CGRect(x: hand.x - 1.5, y: hand.y - 1.5, width: 3, height: 3))
            }

            // Far limbs, behind the body.
            arm(1, near: false)
            leg(1, near: false)

            // Tunic: broad at the shoulders, narrow at the waist, flaring to a hem.
            let side = CGPoint(x: -up.y, y: up.x)
            let waist = off(hip, up, 4)
            let hem = off(hip, down, 5.5)
            let tunic = CGMutablePath()
            tunic.move(to: off(shoulder, side, 4.2))
            tunic.addQuadCurve(to: off(waist, side, 3.4), control: off(off(shoulder, down, 4), side, 4.6))
            tunic.addQuadCurve(to: off(hem, side, 6.2), control: off(hip, side, 3.8))
            tunic.addQuadCurve(to: off(hem, side, -6.2), control: off(off(hem, down, 1.6), side, 0))
            tunic.addQuadCurve(to: off(waist, side, -3.4), control: off(hip, side, -3.8))
            tunic.addQuadCurve(to: off(shoulder, side, -4.2), control: off(off(shoulder, down, 4), side, -4.8))
            tunic.addQuadCurve(to: off(shoulder, side, 4.2), control: off(neck, up, 1))
            ctx.setFillColor(outline.cgColor)
            ctx.addPath(tunic); ctx.setLineWidth(1.1); ctx.setStrokeColor(outline.cgColor); ctx.strokePath()
            ctx.saveGState()
            ctx.addPath(tunic); ctx.clip()
            linearGradient(ctx, colors: [look.cloak.lighter(0.22), look.cloak, look.cloak.darker(0.35)],
                           from: off(neck, forward, 4), to: off(hem, forward, -5))
            // Folds.
            ctx.setStrokeColor(look.cloak.darker(0.4).withAlpha(0.5).cgColor)
            ctx.setLineWidth(0.7)
            for k in [-2.0, 1.5] as [CGFloat] {
                ctx.move(to: off(off(hip, up, 1), side, k)); ctx.addLine(to: off(off(hem, down, 1), side, k * 1.4)); ctx.strokePath()
            }
            // Motif band along the hem, in the torso's frame.
            ctx.translateBy(x: hem.x, y: hem.y)
            ctx.rotate(by: pose.lean)
            MotifPainter.band(look.motif, in: CGRect(x: -8, y: -4.2, width: 16, height: 4.2), ctx: ctx,
                              ink: look.trim, base: look.trim.darker(0.55))
            ctx.restoreGState()
            // Sash across the chest and a leather belt with a buckle.
            ctx.setStrokeColor(look.trim.withAlpha(0.9).cgColor)
            ctx.setLineWidth(1.4)
            ctx.move(to: off(shoulder, side, -3.4)); ctx.addLine(to: off(waist, side, 3)); ctx.strokePath()
            ctx.setStrokeColor(RGBA(r: 0.36, g: 0.22, b: 0.13).cgColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: off(waist, side, 3.6)); ctx.addLine(to: off(waist, side, -3.6)); ctx.strokePath()
            ctx.setFillColor(RGBA(r: 0.9, g: 0.75, b: 0.35).cgColor)
            let buckle = off(waist, forward, 0.4)
            ctx.fill(CGRect(x: buckle.x - 0.8, y: buckle.y - 0.8, width: 1.6, height: 1.6))

            // Near limbs.
            leg(0, near: true)
            arm(0, near: true)

            // Neck, then the head in profile under a draped hood.
            segment(off(neck, down, 1), off(neck, up, 2.4), 2.4, 2.2, look.skin.darker(0.12))
            let head = off(neck, up, 5.6)
            let back = CGPoint(x: -forward.x, y: -forward.y)
            // Hood: a cowl behind and above the head that drapes down onto the shoulders.
            let hood = CGMutablePath()
            hood.move(to: off(off(head, forward, 2.6), up, 4.6))
            hood.addQuadCurve(to: off(off(head, back, 6), up, 1.5), control: off(off(head, back, 3), up, 6.6))
            hood.addQuadCurve(to: off(shoulder, back, 3.6), control: off(off(head, back, 7), down, 4))
            hood.addLine(to: off(shoulder, forward, 1.5))
            hood.addQuadCurve(to: off(off(head, forward, 2.6), up, 4.6), control: off(off(head, forward, -0.5), down, 1))
            ctx.setStrokeColor(outline.cgColor); ctx.setLineWidth(1.1)
            ctx.addPath(hood); ctx.strokePath()
            ctx.saveGState(); ctx.addPath(hood); ctx.clip()
            linearGradient(ctx, colors: [look.cloak.lighter(0.12), look.cloak.darker(0.3)], from: off(head, up, 5), to: shoulder)
            ctx.restoreGState()
            // Face: skull, jaw, nose and chin in profile.
            let face = off(head, forward, 1.2)
            ctx.setFillColor(look.skin.cgColor)
            ctx.fillEllipse(in: CGRect(x: face.x - 3.3, y: face.y - 3.7, width: 6.6, height: 7.4))
            let nose = off(off(face, forward, 3.1), down, 0.2)
            ctx.move(to: off(nose, up, 1.6)); ctx.addLine(to: off(nose, forward, 1.3)); ctx.addLine(to: off(nose, down, 0.9))
            ctx.closePath(); ctx.fillPath()
            ctx.setFillColor(look.skin.darker(0.18).cgColor)
            ctx.fillEllipse(in: CGRect(x: face.x - 3.3, y: face.y - 0.6, width: 3.2, height: 3.6))   // cheek shadow
            let eye = off(off(face, forward, 1.5), up, 0.6)
            ctx.setFillColor(RGBA(r: 0.12, g: 0.09, b: 0.1).cgColor)
            ctx.fillEllipse(in: CGRect(x: eye.x - 0.55, y: eye.y - 0.75, width: 1.1, height: 1.5))
            ctx.setStrokeColor(RGBA(r: 0.2, g: 0.13, b: 0.1).cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: off(off(eye, up, 1.3), back, 0.9)); ctx.addLine(to: off(off(eye, up, 1.5), forward, 1.1)); ctx.strokePath()
            // Hood rim framing the face, in the trim color.
            ctx.setStrokeColor(look.trim.cgColor)
            ctx.setLineWidth(1.1)
            ctx.move(to: off(off(head, forward, 2.4), up, 4.4))
            ctx.addQuadCurve(to: off(off(head, back, 1.2), down, 3.6), control: off(off(head, back, 2.6), up, 2.2))
            ctx.strokePath()
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
