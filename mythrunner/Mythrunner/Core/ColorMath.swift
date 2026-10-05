import Foundation

/// Engine-agnostic color (0...1 components). Converted to SKColor/Color in the render layer.
struct RGBA: Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double = 1

    /// Parses "#RRGGBB" or "#RRGGBBAA". Returns magenta on bad input so mistakes are visible.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let value = UInt64(s, radix: 16) else {
            self.init(r: 1, g: 0, b: 1)
            return
        }
        if s.count == 6 {
            self.init(r: Double((value >> 16) & 0xFF) / 255,
                      g: Double((value >> 8) & 0xFF) / 255,
                      b: Double(value & 0xFF) / 255)
        } else {
            self.init(r: Double((value >> 24) & 0xFF) / 255,
                      g: Double((value >> 16) & 0xFF) / 255,
                      b: Double((value >> 8) & 0xFF) / 255,
                      a: Double(value & 0xFF) / 255)
        }
    }

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    static func isValidHex(_ hex: String) -> Bool {
        var s = hex
        guard s.hasPrefix("#") else { return false }
        s.removeFirst()
        return (s.count == 6 || s.count == 8) && UInt64(s, radix: 16) != nil
    }

    func mixed(with other: RGBA, _ t: Double) -> RGBA {
        let t = min(max(t, 0), 1)
        return RGBA(r: r + (other.r - r) * t, g: g + (other.g - g) * t,
                    b: b + (other.b - b) * t, a: a + (other.a - a) * t)
    }

    func withAlpha(_ alpha: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: alpha) }

    /// Scales saturation and brightness in HSB space (used for age-band visual tuning).
    func adjusted(saturation sScale: Double, brightness bScale: Double) -> RGBA {
        var (h, s, v) = toHSB()
        s = min(max(s * sScale, 0), 1)
        v = min(max(v * bScale, 0), 1)
        return RGBA.fromHSB(h: h, s: s, v: v, a: a)
    }

    /// Relative luminance (WCAG), used to pick readable text colors.
    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    func toHSB() -> (Double, Double, Double) {
        let maxC = max(r, g, b), minC = min(r, g, b)
        let delta = maxC - minC
        var h = 0.0
        if delta > 0 {
            if maxC == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == g { h = (b - r) / delta + 2 }
            else { h = (r - g) / delta + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        let s = maxC == 0 ? 0 : delta / maxC
        return (h, s, maxC)
    }

    static func fromHSB(h: Double, s: Double, v: Double, a: Double = 1) -> RGBA {
        let i = Int(h * 6) % 6
        let f = h * 6 - Double(Int(h * 6))
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        switch i {
        case 0: return RGBA(r: v, g: t, b: p, a: a)
        case 1: return RGBA(r: q, g: v, b: p, a: a)
        case 2: return RGBA(r: p, g: v, b: t, a: a)
        case 3: return RGBA(r: p, g: q, b: v, a: a)
        case 4: return RGBA(r: t, g: p, b: v, a: a)
        default: return RGBA(r: v, g: p, b: q, a: a)
        }
    }
}

/// A realm palette after age-band tuning, ready for rendering.
struct ResolvedPalette {
    var skyTop, skyBottom, far, mid, near, ground, groundEdge, accent, guardian: RGBA

    init(palette: Palette, guardianHex: String, tuning: AgeTuning) {
        func c(_ hex: String) -> RGBA {
            RGBA(hex: hex).adjusted(saturation: tuning.saturation, brightness: tuning.brightness)
        }
        skyTop = c(palette.skyTop)
        skyBottom = c(palette.skyBottom)
        far = c(palette.far)
        mid = c(palette.mid)
        near = c(palette.near)
        ground = c(palette.ground)
        groundEdge = c(palette.groundEdge)
        accent = c(palette.accent)
        guardian = c(guardianHex)
    }
}
