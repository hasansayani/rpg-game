import SpriteKit
import UIKit

extension TextureFactory {
    /// The Wayfarer: a hooded rider on a carved sky-board, dressed in the realm's motif.
    /// Drawn facing right; feet at the bottom center; the neck sits ~40 pt above the board.
    static func rider(body: RGBA, board: RGBA, motif: Motif, trim: RGBA) -> SKTexture {
        image(size: CGSize(width: 52, height: 60)) { ctx in
            let skin = RGBA(r: 0.93, g: 0.76, b: 0.6)
            let cloakDark = body.darker(0.35)
            let leather = RGBA(r: 0.42, g: 0.27, b: 0.16)

            // Board: tapered deck with an upturned nose, a motif-painted rail and a bright top edge.
            let deck = UIBezierPath()
            deck.move(to: CGPoint(x: 2, y: 52))
            deck.addQuadCurve(to: CGPoint(x: 8, y: 49), controlPoint: CGPoint(x: 2, y: 49))
            deck.addLine(to: CGPoint(x: 46, y: 49))
            deck.addQuadCurve(to: CGPoint(x: 51, y: 45), controlPoint: CGPoint(x: 50, y: 49))
            deck.addQuadCurve(to: CGPoint(x: 46, y: 55), controlPoint: CGPoint(x: 52, y: 54))
            deck.addLine(to: CGPoint(x: 8, y: 55))
            deck.close()
            ctx.saveGState()
            ctx.addPath(deck.cgPath); ctx.clip()
            linearGradient(ctx, colors: [board.lighter(0.25), board.darker(0.3)], from: CGPoint(x: 0, y: 49), to: CGPoint(x: 0, y: 55))
            MotifPainter.band(motif, in: CGRect(x: 6, y: 51, width: 42, height: 3.4), ctx: ctx, ink: board.lighter(0.6))
            ctx.restoreGState()
            ctx.setFillColor(board.lighter(0.7).withAlpha(0.85).cgColor)
            ctx.fill(CGRect(x: 10, y: 49, width: 34, height: 1))

            // Legs in a riding crouch, with boots.
            ctx.setFillColor(cloakDark.cgColor)
            let legs = UIBezierPath()
            legs.move(to: CGPoint(x: 15, y: 48)); legs.addLine(to: CGPoint(x: 19, y: 38)); legs.addLine(to: CGPoint(x: 24, y: 36))
            legs.addLine(to: CGPoint(x: 22, y: 41)); legs.addLine(to: CGPoint(x: 20, y: 48)); legs.close()
            legs.move(to: CGPoint(x: 28, y: 48)); legs.addLine(to: CGPoint(x: 33, y: 39)); legs.addLine(to: CGPoint(x: 30, y: 35))
            legs.addLine(to: CGPoint(x: 36, y: 37)); legs.addLine(to: CGPoint(x: 34, y: 48)); legs.close()
            ctx.addPath(legs.cgPath); ctx.fillPath()
            ctx.setFillColor(RGBA(r: 0.24, g: 0.16, b: 0.12).cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 13, y: 45.5, width: 9, height: 4), cornerRadius: 1.5).cgPath)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 27, y: 45.5, width: 9, height: 4), cornerRadius: 1.5).cgPath)
            ctx.fillPath()

            // Satchel on the back hip.
            ctx.setFillColor(RGBA(r: 0.55, g: 0.36, b: 0.22).cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 8, y: 28, width: 9, height: 10), cornerRadius: 2.5).cgPath)
            ctx.fillPath()
            ctx.setFillColor(trim.cgColor)
            ctx.fill(CGRect(x: 8, y: 31, width: 9, height: 1.4))

            // Cloak: a flared bell with a fold and a motif-trimmed hem.
            let cloak = UIBezierPath()
            cloak.move(to: CGPoint(x: 12, y: 40))
            cloak.addQuadCurve(to: CGPoint(x: 21, y: 17), controlPoint: CGPoint(x: 11, y: 22))
            cloak.addLine(to: CGPoint(x: 31, y: 17))
            cloak.addQuadCurve(to: CGPoint(x: 38, y: 39), controlPoint: CGPoint(x: 39, y: 24))
            cloak.addQuadCurve(to: CGPoint(x: 12, y: 40), controlPoint: CGPoint(x: 25, y: 43))
            cloak.close()
            ctx.saveGState()
            ctx.addPath(cloak.cgPath); ctx.clip()
            linearGradient(ctx, colors: [body.lighter(0.18), body, cloakDark], from: CGPoint(x: 34, y: 18), to: CGPoint(x: 14, y: 40))
            ctx.setStrokeColor(cloakDark.withAlpha(0.7).cgColor); ctx.setLineWidth(1.4)
            ctx.move(to: CGPoint(x: 24, y: 22)); ctx.addQuadCurve(to: CGPoint(x: 22, y: 40), control: CGPoint(x: 20, y: 30)); ctx.strokePath()
            MotifPainter.band(motif, in: CGRect(x: 8, y: 35, width: 34, height: 6), ctx: ctx, ink: trim, base: trim.darker(0.55))
            ctx.restoreGState()

            // Strap across the chest with a clasp.
            ctx.setStrokeColor(leather.cgColor); ctx.setLineWidth(1.6)
            ctx.move(to: CGPoint(x: 15, y: 30)); ctx.addLine(to: CGPoint(x: 33, y: 19)); ctx.strokePath()
            ctx.setFillColor(trim.cgColor)
            ctx.fillEllipse(in: CGRect(x: 23, y: 23, width: 3, height: 3))

            // Forward arm, balancing.
            ctx.setStrokeColor(body.cgColor); ctx.setLineWidth(4); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 31, y: 21)); ctx.addQuadCurve(to: CGPoint(x: 44, y: 26), control: CGPoint(x: 38, y: 19)); ctx.strokePath()
            ctx.setFillColor(skin.cgColor)
            ctx.fillEllipse(in: CGRect(x: 42.5, y: 24, width: 4, height: 4))

            // Hood with a swept-back peak, face, eye and a wrap of trim at the neck.
            let hood = UIBezierPath()
            hood.move(to: CGPoint(x: 18, y: 18))
            hood.addQuadCurve(to: CGPoint(x: 22, y: 3), controlPoint: CGPoint(x: 15, y: 7))
            hood.addLine(to: CGPoint(x: 15, y: 0.5))
            hood.addQuadCurve(to: CGPoint(x: 33, y: 6), controlPoint: CGPoint(x: 29, y: -1))
            hood.addQuadCurve(to: CGPoint(x: 33, y: 18), controlPoint: CGPoint(x: 37, y: 13))
            hood.close()
            ctx.saveGState()
            ctx.addPath(hood.cgPath); ctx.clip()
            linearGradient(ctx, colors: [body.lighter(0.1), cloakDark], from: CGPoint(x: 30, y: 2), to: CGPoint(x: 18, y: 18))
            ctx.restoreGState()
            ctx.setFillColor(skin.cgColor)
            ctx.fillEllipse(in: CGRect(x: 25, y: 6.5, width: 9, height: 9.5))
            ctx.setFillColor(cloakDark.withAlpha(0.6).cgColor)
            ctx.fillEllipse(in: CGRect(x: 24.5, y: 6, width: 4.5, height: 10))
            ctx.setFillColor(RGBA(r: 0.1, g: 0.08, b: 0.1).cgColor)
            ctx.fillEllipse(in: CGRect(x: 30.5, y: 9.5, width: 1.8, height: 2.2))
            ctx.setFillColor(trim.cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 19, y: 15.5, width: 15, height: 3.5), cornerRadius: 1.7).cgPath)
            ctx.fillPath()
        }
    }
}
