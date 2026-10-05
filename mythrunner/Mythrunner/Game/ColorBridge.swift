import SpriteKit
import SwiftUI

extension RGBA {
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }
    var skColor: SKColor { uiColor }
    var color: Color { Color(red: r, green: g, blue: b, opacity: a) }
    var cgColor: CGColor { uiColor.cgColor }

    func darker(_ amount: Double) -> RGBA { mixed(with: RGBA(r: 0, g: 0, b: 0, a: a), amount) }
    func lighter(_ amount: Double) -> RGBA { mixed(with: RGBA(r: 1, g: 1, b: 1, a: a), amount) }

    /// Black or white, whichever reads better on this color.
    var readableText: RGBA { luminance > 0.45 ? RGBA(r: 0.08, g: 0.08, b: 0.12) : RGBA(r: 1, g: 1, b: 1) }
}

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
}
