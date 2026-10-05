import SwiftUI

/// The journey: 30 realms as a horizontally scrolling trail of cards.
struct RealmMapView: View {
    @EnvironmentObject var model: AppModel
    @State private var playing: Realm?
    @State private var showSettings = false
    @State private var showCodex = false
    @State private var regionFilter: Region?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.07, blue: 0.2), Color(red: 0.22, green: 0.13, blue: 0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                header
                regionChips
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 14) {
                            ForEach(filteredRealms) { realm in
                                RealmCard(realm: realm,
                                          palette: model.palette(for: realm),
                                          unlocked: model.isUnlocked(realm),
                                          completed: model.progress.completed.contains(realm.id),
                                          relics: model.progress.relicsFound[realm.id] ?? 0)
                                    .id(realm.id)
                                    .onTapGesture {
                                        if model.isUnlocked(realm) { playing = realm }
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                    .onAppear { scrollToCurrent(proxy) }
                }
            }
            .padding(.vertical, 12)
        }
        .fullScreenCover(item: $playing) { realm in
            GameContainerView(realm: realm, onExit: { playing = nil }, onNext: { next in playing = next })
                .environmentObject(model)
                .id(realm.id)
        }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(model) }
        .sheet(isPresented: $showCodex) { CodexView().environmentObject(model) }
    }

    private var filteredRealms: [Realm] {
        guard let r = regionFilter else { return model.realms }
        return model.realms.filter { $0.region == r }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MYTHRUNNER").font(.system(size: 28, weight: .heavy, design: .rounded))
                Text("\(model.progress.completed.count)/\(model.realms.count) realms · \(model.progress.loreSeen.count) stories collected")
                    .font(.subheadline.weight(.semibold)).opacity(0.75)
            }
            Spacer()
            Button { showCodex = true } label: { Label("Codex", systemImage: "book.closed.fill") }
            Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape.fill") }
        }
        .buttonStyle(.bordered)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
    }

    private var regionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: regionFilter == nil) { regionFilter = nil }
                ForEach(Region.allCases, id: \.self) { r in
                    chip(r.displayName, selected: regionFilter == r) { regionFilter = r }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.bold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? Color.white : Color.white.opacity(0.12), in: Capsule())
                .foregroundStyle(selected ? Color.black : Color.white)
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        if let current = model.realms.last(where: { model.isUnlocked($0) }) {
            proxy.scrollTo(current.id, anchor: .center)
        }
    }
}

struct RealmCard: View {
    let realm: Realm
    let palette: ResolvedPalette
    let unlocked: Bool
    let completed: Bool
    let relics: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [palette.skyTop.color, palette.skyBottom.color], startPoint: .top, endPoint: .bottom)
            // Simple layered hills echo the in-game parallax.
            HillShape(phase: Double(realm.order), height: 0.45).fill(palette.far.color)
            HillShape(phase: Double(realm.order) * 1.7, height: 0.3).fill(palette.mid.color)
            HillShape(phase: Double(realm.order) * 2.3, height: 0.18).fill(palette.ground.color)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(realm.order)")
                        .font(.caption.weight(.heavy))
                        .padding(6)
                        .background(.black.opacity(0.35), in: Circle())
                    Text(realm.region.displayName.uppercased())
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.black.opacity(0.35), in: Capsule())
                    Spacer()
                    if completed { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
                }
                Spacer()
                Text(realm.name).font(.headline.weight(.heavy))
                Text(realm.culture).font(.caption.weight(.semibold)).opacity(0.9)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < relics ? "diamond.fill" : "diamond").font(.caption2)
                    }
                    if realm.tags.contains("lesserKnown") {
                        Text("Hidden gem").font(.caption2.weight(.bold)).padding(.leading, 4)
                    }
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 3)
            .padding(12)

            if !unlocked {
                Color.black.opacity(0.55)
                Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 210, height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

struct HillShape: Shape {
    var phase: Double
    var height: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        for x in stride(from: 0, through: rect.width, by: 6) {
            let t = Double(x / rect.width)
            let y = rect.maxY - rect.height * height * CGFloat(0.75 + 0.25 * sin(t * 6 + phase))
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
