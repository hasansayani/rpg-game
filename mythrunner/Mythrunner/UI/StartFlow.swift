import SpriteKit
import SwiftUI

// MARK: - Backdrop

/// The animated dusk landscape behind the splash, loading and title screens:
/// a drifting star field, a glowing moon and three parallax ridges scrolling by.
struct MythBackdrop: View {
    var speed: Double = 1

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed
            Canvas { ctx, size in
                let w = size.width, h = size.height
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.06, green: 0.05, blue: 0.2), Color(red: 0.32, green: 0.15, blue: 0.42),
                                      Color(red: 0.98, green: 0.55, blue: 0.4)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                // Stars twinkle on deterministic positions.
                for k in 0..<70 {
                    let x = CGFloat((k * 7919) % 1000) / 1000 * w
                    let y = CGFloat((k * 104_729) % 1000) / 1000 * h * 0.55
                    let a = 0.35 + 0.35 * sin(t * 1.5 + Double(k))
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(a)))
                }
                let moon = CGPoint(x: w * 0.78, y: h * 0.26)
                ctx.fill(Path(ellipseIn: CGRect(x: moon.x - 60, y: moon.y - 60, width: 120, height: 120)),
                         with: .radialGradient(Gradient(colors: [.white.opacity(0.5), .clear]), center: moon, startRadius: 0, endRadius: 60))
                ctx.fill(Path(ellipseIn: CGRect(x: moon.x - 22, y: moon.y - 22, width: 44, height: 44)),
                         with: .color(Color(red: 1, green: 0.95, blue: 0.85)))
                let ridges: [(Color, CGFloat, CGFloat, Double)] = [
                    (Color(red: 0.36, green: 0.2, blue: 0.45), 0.58, 60, 12),
                    (Color(red: 0.24, green: 0.13, blue: 0.33), 0.7, 45, 28),
                    (Color(red: 0.12, green: 0.07, blue: 0.2), 0.82, 30, 60),
                ]
                for (color, base, amp, rate) in ridges {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: h))
                    for x in stride(from: 0, through: w, by: 6) {
                        let s = Double(x) / 140 + t * rate / 140
                        let y = h * base - amp * CGFloat(0.6 * sin(s) + 0.4 * sin(s * 2.3 + 1))
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(color))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Lumi, the spirit companion, as a pulsing wisp.
struct LumiOrb: View {
    @State private var pulse = false
    var size: CGFloat = 70

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(red: 0.6, green: 1, blue: 0.9).opacity(0.8), .clear],
                                         center: .center, startRadius: 0, endRadius: size * 0.7))
                .frame(width: size * 1.4, height: size * 1.4)
                .scaleEffect(pulse ? 1.15 : 0.9)
            Circle().fill(.white).frame(width: size * 0.22, height: size * 0.22)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } }
    }
}

// MARK: - Splash

struct SplashView: View {
    var onDone: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            MythBackdrop(speed: 0.6)
            VStack(spacing: 10) {
                LumiOrb(size: 64)
                    .offset(y: shown ? 0 : 30)
                Text("MYTHRUNNER")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                    .scaleEffect(shown ? 1 : 0.85)
                Text("Thirty realms. One journey through the world's myths.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { finish() }
        }
        .onTapGesture(perform: finish)
    }

    @State private var finished = false
    /// Leaves the splash once, whether by tap or by timer.
    private func finish() {
        guard !finished else { return }
        finished = true
        onDone()
    }
}

// MARK: - Loading

/// Pre-draws the textures every realm needs and shows a real story fact while it does.
struct LoadingView: View {
    @EnvironmentObject var model: AppModel
    var onDone: () -> Void
    @State private var progress: Double = 0
    @State private var fact: String = ""

    var body: some View {
        ZStack {
            MythBackdrop(speed: 1.4)
            VStack(spacing: 18) {
                LumiOrb(size: 48)
                Text("Gathering the old stories…")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                ProgressView(value: progress)
                    .tint(Color(red: 1, green: 0.78, blue: 0.34))
                    .frame(width: 320)
                if !fact.isEmpty {
                    Text("Did you know? \(fact)")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: 520)
                        .transition(.opacity)
                }
            }
            .padding(24)
        }
        .task { await load() }
    }

    private func load() async {
        let variant = model.tuning.loreVariant
        if let realm = model.realms.randomElement(), let f = realm.facts.randomElement() {
            withAnimation { fact = f.text(for: variant) }
        }
        // Warm the procedural art caches in small steps so the screen stays responsive.
        let steps: [() -> Void] = [
            { _ = TextureFactory.softDot() },
            { _ = RunnerFrames(look: RunnerLook(cloak: RGBA(hex: "#2B2D42"), trim: RGBA(hex: "#FFC857"), motif: .meander)) },
            { _ = TextureFactory.spiritGate(color: RGBA(hex: "#FFC857")) },
            { _ = TextureFactory.lightShaft() },
        ]
        for (i, step) in steps.enumerated() {
            step()
            withAnimation(.easeOut(duration: 0.25)) { progress = Double(i + 1) / Double(steps.count) }
            try? await Task.sleep(nanoseconds: 350_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        onDone()
    }
}

// MARK: - Title menu

struct TitleView: View {
    @EnvironmentObject var model: AppModel
    var onChooseRealm: () -> Void
    @State private var playing: Realm?
    @State private var showSettings = false
    @State private var showCodex = false
    @State private var confirmNewGame = false

    /// The first unlocked realm not yet completed (or the last unlocked one).
    private var continueRealm: Realm? {
        model.realms.first { model.isUnlocked($0) && !model.progress.completed.contains($0.id) }
            ?? model.realms.last { model.isUnlocked($0) }
    }
    private var hasProgress: Bool { !model.progress.completed.isEmpty || !model.progress.attempts.isEmpty }

    var body: some View {
        ZStack {
            MythBackdrop()
            HStack(alignment: .center, spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MYTHRUNNER")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .tracking(4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(model.progress.completed.count) of \(model.realms.count) realms · \(model.progress.loreSeen.count) stories")
                        .font(.headline).opacity(0.8)
                    if let next = continueRealm {
                        Text("Next: \(next.name) — \(next.culture)")
                            .font(.subheadline).opacity(0.75)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 440, alignment: .leading)

                VStack(spacing: 12) {
                    menuButton(hasProgress ? "Continue" : "Start the journey", icon: "play.fill", prominent: true) {
                        playing = continueRealm
                    }
                    menuButton("Choose realm", icon: "map.fill") { onChooseRealm() }
                    menuButton("New game", icon: "arrow.counterclockwise") { confirmNewGame = true }
                    HStack(spacing: 12) {
                        menuButton("Codex", icon: "book.closed.fill") { showCodex = true }
                        menuButton("Settings", icon: "gearshape.fill") { showSettings = true }
                    }
                }
                .frame(width: 300)
            }
            .padding(24)
        }
        .fullScreenCover(item: $playing) { realm in
            GameContainerView(realm: realm, onExit: { playing = nil }, onNext: { next in playing = next })
                .environmentObject(model)
                .id(realm.id)
        }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(model) }
        .sheet(isPresented: $showCodex) { CodexView().environmentObject(model) }
        .confirmationDialog("Start a new game? Your completed realms and collected stories will be erased.",
                            isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("Start over", role: .destructive) {
                model.progress = PlayerProgress()
                playing = model.realms.first
            }
        }
    }

    private func menuButton(_ title: String, icon: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? Color.black : Color.white)
        .background(prominent ? Color(red: 1, green: 0.78, blue: 0.34) : Color.white.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(prominent ? 0 : 0.3)))
    }
}
