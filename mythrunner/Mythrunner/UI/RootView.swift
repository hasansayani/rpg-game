import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel
    /// Splash → loading → (age gate on first launch) → title menu ⇄ realm map.
    enum Stage { case splash, loading, title, map }
    @State private var stage: Stage = .splash

    var body: some View {
        #if DEBUG
        // Screenshot/QA shortcuts: `-previewRealm norse` opens a realm directly,
        // `-guardianGallery YES` shows every guardian side by side.
        let args = UserDefaults.standard
        if let id = args.string(forKey: "previewRealm"), let realm = model.realms.first(where: { $0.id == id }) {
            GameContainerView(realm: realm, onExit: {}, onNext: { _ in })
        } else if args.bool(forKey: "guardianGallery") {
            GuardianGalleryView()
        } else {
            mainFlow
        }
        #else
        mainFlow
        #endif
    }

    @ViewBuilder private var mainFlow: some View {
        Group {
            switch stage {
            case .splash:
                SplashView { stage = .loading }
            case .loading:
                LoadingView { stage = .title }
            case .title:
                if model.settings.age == nil {
                    AgeGateView { age in model.settings.age = age }
                } else {
                    TitleView { stage = .map }
                }
            case .map:
                RealmMapView(onHome: { stage = .title })
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: stage)
    }
}

// MARK: - Age gate

/// First-launch question. The answer tunes visuals, difficulty and how Lumi explains things.
struct AgeGateView: View {
    var initialAge = 10
    var onDone: (Int) -> Void
    @State private var age = 10

    var body: some View {
        let band = AgeBand(age: age)
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.4), Color(red: 1, green: 0.62, blue: 0.4)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("MYTHRUNNER")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                    Text("Run through 30 realms of world mythology with Lumi, your spirit guide.")
                        .font(.title3.weight(.semibold))
                    Text("How old are you?")
                        .font(.title2.weight(.bold))
                        .padding(.top, 8)
                    Text("We use this to tune colors, speed and how Lumi tells the stories. It stays on this device.")
                        .font(.callout)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 380, alignment: .leading)

                VStack(spacing: 14) {
                    Picker("Age", selection: $age) {
                        ForEach(4...99, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 140, height: 140)
                    .clipped()
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))

                    Text(band.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Button {
                        onDone(age)
                    } label: {
                        Text("Let's go")
                            .font(.title3.weight(.heavy))
                            .padding(.horizontal, 36).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 1, green: 0.3, blue: 0.43))
                }
            }
            .padding(24)
        }
        .onAppear { age = initialAge }
    }
}
