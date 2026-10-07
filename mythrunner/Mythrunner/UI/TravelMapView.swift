import SwiftUI

/// Shown after the hero steps through a realm's portal: a world map with a glowing dot for every
/// realm (bright where the journey has been), and the portal's path from this realm to the next.
struct TravelMapView: View {
    let realms: [Realm]
    let completed: Set<String>
    let from: Realm
    let to: Realm?
    var onDone: () -> Void

    @State private var start = Date()
    private let travelTime = 2.6

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let t = min(max((elapsed - 0.4) / travelTime, 0), 1)
            ZStack {
                LinearGradient(colors: [Color(red: 0.12, green: 0.09, blue: 0.2), Color(red: 0.2, green: 0.13, blue: 0.24)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 8) {
                    Text(to == nil ? "The journey is complete" : "Through the portal…")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Canvas { ctx, size in
                        draw(ctx, size: size, t: t, time: elapsed)
                    }
                    .aspectRatio(360 / 131, contentMode: .fit)
                    .padding(.horizontal, 24)
                    Group {
                        if let to {
                            Text("Next: \(to.name) — \(to.culture) · \(to.place)")
                        } else {
                            Text("You have run through all \(realms.count) realms of world mythology.")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                    Text(t >= 1 ? "Tap to continue" : " ")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 14)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDone)
        .onAppear { start = Date() }
    }

    // MARK: Projection

    /// Equirectangular, cropped to latitudes 75°N…56°S (where all the realms are).
    private func project(lat: Double, lon: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: (lon + 180) / 360 * size.width, y: (75 - lat) / 131 * size.height)
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize, t: Double, time: Double) {
        let parchment = Color(red: 0.93, green: 0.86, blue: 0.7)
        let ink = Color(red: 0.45, green: 0.32, blue: 0.2)
        let sea = Color(red: 0.16, green: 0.28, blue: 0.38)
        let frame = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14)
        ctx.fill(frame, with: .linearGradient(Gradient(colors: [sea.opacity(0.95), sea.opacity(0.75)]),
                                              startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        // Graticule.
        var grid = Path()
        for lon in stride(from: -150.0, through: 150, by: 30) {
            let a = project(lat: 75, lon: lon, in: size), b = project(lat: -56, lon: lon, in: size)
            grid.move(to: a); grid.addLine(to: b)
        }
        for lat in stride(from: -45.0, through: 60, by: 15) {
            let a = project(lat: lat, lon: -180, in: size), b = project(lat: lat, lon: 180, in: size)
            grid.move(to: a); grid.addLine(to: b)
        }
        ctx.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 0.6)

        // Continents: all outlines first, then all fills, so only coastlines show where shapes overlap.
        let land = WorldOutline.shapes.map { shape -> Path in
            var p = Path()
            for (i, c) in shape.enumerated() {
                let pt = project(lat: c.1, lon: c.0, in: size)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
            return p
        }
        for p in land { ctx.stroke(p, with: .color(ink.opacity(0.75)), lineWidth: 2.2) }
        for p in land { ctx.fill(p, with: .color(parchment)) }

        // The portal's path from this realm to the next: an arc drawn as it travels, with Lumi at its head.
        let a = project(lat: from.latitude, lon: from.longitude, in: size)
        if let to {
            let b = project(lat: to.latitude, lon: to.longitude, in: size)
            let dist = hypot(b.x - a.x, b.y - a.y)
            let ctrl = CGPoint(x: (a.x + b.x) / 2, y: min(a.y, b.y) - max(dist * 0.35, 24))
            func point(_ u: Double) -> CGPoint {
                let v = 1 - u
                return CGPoint(x: v * v * a.x + 2 * v * u * ctrl.x + u * u * b.x,
                               y: v * v * a.y + 2 * v * u * ctrl.y + u * u * b.y)
            }
            var arc = Path()
            arc.move(to: a)
            for s in stride(from: 0.0, through: t, by: 0.01) { arc.addLine(to: point(s)) }
            ctx.stroke(arc, with: .color(Color(red: 1, green: 0.85, blue: 0.4).opacity(0.35)), lineWidth: 6)
            ctx.stroke(arc, with: .color(Color(red: 1, green: 0.9, blue: 0.55)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5], dashPhase: -time * 20))
            if t < 1 {
                let head = point(t)
                glow(ctx, at: head, radius: 14, color: Color(red: 0.6, green: 1, blue: 0.9))
                ctx.fill(Path(ellipseIn: CGRect(x: head.x - 3, y: head.y - 3, width: 6, height: 6)), with: .color(.white))
            }
        }

        // Every realm as a dot: visited ones glow gold, the next destination pulses, the rest are dim.
        for realm in realms {
            let p = project(lat: realm.latitude, lon: realm.longitude, in: size)
            let visited = completed.contains(realm.id) || realm.id == from.id
            let isNext = realm.id == to?.id
            if isNext {
                let pulse = 0.5 + 0.5 * sin(time * 5)
                glow(ctx, at: p, radius: 12 + 6 * pulse, color: Color(red: 0.6, green: 1, blue: 0.9))
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)),
                           with: .color(.white.opacity(t >= 1 ? 1 : 0.6)), lineWidth: 1.5)
            } else if visited {
                glow(ctx, at: p, radius: realm.id == from.id ? 14 : 9, color: Color(red: 1, green: 0.8, blue: 0.35))
            }
            let r: CGFloat = visited || isNext ? 3.4 : 2.4
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                     with: .color(visited ? Color(red: 1, green: 0.9, blue: 0.55) : isNext ? .white : ink.opacity(0.75)))
        }
        ctx.stroke(frame, with: .color(ink), lineWidth: 2)
    }

    private func glow(_ ctx: GraphicsContext, at p: CGPoint, radius: CGFloat, color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                 with: .radialGradient(Gradient(colors: [color.opacity(0.9), color.opacity(0)]),
                                       center: p, startRadius: 0, endRadius: radius))
    }
}

/// Very simplified coastlines as (longitude, latitude) polygons: enough to read as a world map
/// in a hand-drawn, old-chart style without any image assets.
enum WorldOutline {
    static let shapes: [[(Double, Double)]] = [
        // North America
        [(-168, 66), (-162, 70), (-140, 70), (-125, 72), (-95, 73), (-80, 73), (-62, 67), (-56, 52), (-66, 45), (-76, 38),
         (-81, 31), (-80, 25), (-84, 30), (-90, 29), (-97, 26), (-97, 21), (-90, 21), (-87, 15), (-83, 9), (-78, 8),
         (-82, 9), (-86, 13), (-92, 15), (-105, 20), (-110, 23), (-115, 30), (-118, 34), (-124, 40), (-124, 48),
         (-131, 55), (-140, 59), (-152, 58), (-165, 60)],
        // Greenland
        [(-73, 75), (-60, 75), (-30, 75), (-20, 74), (-22, 70), (-42, 60), (-50, 63), (-55, 68), (-60, 74)],
        // Caribbean (Cuba and Hispaniola)
        [(-85, 22), (-74, 20.5), (-68.5, 19), (-72, 18), (-80, 21.5)],
        // South America
        [(-80, 8), (-74, 11), (-63, 10), (-52, 5), (-35, -6), (-39, -14), (-41, -22), (-48, -27), (-58, -35), (-62, -40),
         (-66, -46), (-69, -52), (-74, -52), (-73, -45), (-72, -36), (-71, -28), (-70, -18), (-76, -13), (-81, -5), (-80, 1)],
        // Europe
        [(-10, 36), (-9, 43), (-2, 44), (-5, 48), (1, 51), (4, 52), (8, 54), (9, 57), (5, 59), (5, 62), (14, 68), (20, 70),
         (28, 71), (40, 67), (44, 68), (60, 69), (60, 55), (50, 47), (40, 47), (30, 46), (28, 41), (26, 40), (23, 36),
         (20, 40), (15, 38), (12, 44), (8, 44), (3, 43), (-5, 36)],
        // Britain and Ireland, Iceland
        [(-6, 50), (1, 51), (2, 53), (-1, 55), (-3, 58), (-6, 58), (-5, 54), (-3, 52)],
        [(-10, 52), (-6, 52), (-6, 55), (-10, 54)],
        [(-24, 64), (-14, 64), (-14, 66.5), (-22, 66.5)],
        // Africa and Madagascar
        [(-17, 21), (-16, 28), (-10, 35), (-2, 36), (10, 37), (20, 32), (32, 31), (35, 28), (43, 12), (51, 12), (51, 2),
         (40, -10), (40, -16), (35, -24), (32, -29), (27, -34), (20, -35), (17, -30), (12, -17), (13, -6), (9, -1), (9, 4),
         (4, 6), (-8, 4), (-15, 11), (-17, 15)],
        [(44, -25), (47, -25), (50, -15), (49, -12), (44, -17)],
        // Asia (with Arabia, India and Southeast Asia)
        [(26, 40), (36, 36), (35, 32), (43, 13), (53, 17), (57, 24), (52, 27), (56, 27), (60, 25), (67, 24), (73, 20),
         (78, 8), (80, 15), (88, 22), (92, 22), (98, 16), (100, 13), (103, 1), (104, 10), (107, 17), (106, 21), (112, 22),
         (118, 25), (121, 31), (119, 38), (122, 40), (127, 38), (129, 35), (131, 43), (140, 48), (141, 53), (137, 55),
         (150, 59), (163, 60), (163, 68), (180, 69), (180, 72), (140, 73), (110, 75), (100, 75), (80, 73), (70, 73),
         (60, 69), (60, 55), (50, 47), (40, 47), (30, 46), (28, 41)],
        // Japan, the Philippines, Indonesia, Borneo
        [(130, 31), (132, 34), (136, 35), (140, 36), (142, 40), (141, 44), (145, 44), (142, 46), (140, 42), (139, 38), (136, 36), (133, 34)],
        [(120, 18), (122, 18), (126, 7), (122, 7), (120, 12)],
        [(95, 5), (105, -6), (115, -8), (125, -9), (119, -3), (109, -2), (104, 1), (98, 5)],
        [(109, 1), (113, 4), (119, 6), (118, 0), (116, -4), (110, -3)],
        // Australia, New Zealand
        [(114, -22), (122, -18), (130, -12), (137, -12), (142, -11), (146, -19), (153, -26), (151, -34), (146, -39),
         (140, -38), (135, -35), (129, -32), (116, -35), (114, -27)],
        [(172, -34), (178, -38), (175, -41), (172, -44), (167, -46), (170, -42), (173, -40)],
    ]
}
