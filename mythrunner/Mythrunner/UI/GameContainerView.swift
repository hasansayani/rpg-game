import SpriteKit
import SwiftUI

/// Owns the SpriteKit scene for one realm attempt and overlays SwiftUI pause/results UI.
@MainActor
final class GameController: ObservableObject, InputTarget {
    enum MenuCommand { case confirm, back }

    let scene: GameScene
    @Published var paused = false
    @Published var result: RunResult?
    /// Keyboard/gamepad choices on the results screen; GameHost owns the navigation.
    var onMenuCommand: ((MenuCommand) -> Void)?

    init(realm: Realm, model: AppModel) {
        let s = model.settings
        let setup = GameScene.Setup(realm: realm, totalRealms: model.realms.count, tuning: s.tuning,
                                    mode: s.guardianMode.resolve(for: realm.guardian),
                                    companion: model.catalog.companion, haptics: s.haptics)
        let bounds = UIScreen.main.bounds
        let size = CGSize(width: max(bounds.width, bounds.height), height: min(bounds.width, bounds.height))
        scene = GameScene(size: size, setup: setup)
        scene.onPause = { [weak self] in self?.setPaused(true) }
        scene.onFinish = { [weak self] result in
            guard let self else { return }
            model.progress.record(result)
            self.scene.isPaused = true
            self.result = result
        }
        InputRouter.shared.target = self
    }

    func handle(_ command: InputCommand) {
        if result != nil {
            switch command {
            case .action(pressed: true): onMenuCommand?(.confirm)
            case .back, .pause: onMenuCommand?(.back)
            case .action: break
            }
        } else if paused {
            switch command {
            case .action(pressed: true), .pause, .back: setPaused(false)
            case .action: break
            }
        } else {
            switch command {
            case .action(let pressed): pressed ? scene.session.press() : scene.session.release()
            case .pause: setPaused(true)
            case .back: break
            }
        }
    }

    func setPaused(_ value: Bool) {
        paused = value
        scene.isPaused = value
        if !value { scene.resetClock() }
    }
}

/// Entry point for one realm. Each retry bumps `attempt`, which rebuilds GameHost (and its scene) from scratch.
struct GameContainerView: View {
    let realm: Realm
    var onExit: () -> Void
    var onNext: (Realm) -> Void
    @EnvironmentObject var model: AppModel
    @State private var attempt = 0

    var body: some View {
        GameHost(realm: realm, model: model, onExit: onExit, onNext: onNext)
            .id(attempt)
            .environment(\.retryAction, RetryAction { attempt += 1 })
    }
}

/// Holds the real controller; recreated (via `.id`) for each retry so every attempt starts fresh.
private struct GameHost: View {
    let realm: Realm
    let onExit: () -> Void
    let onNext: (Realm) -> Void
    @ObservedObject var model: AppModel
    @StateObject private var controller: GameController
    @Environment(\.retryAction) private var retry

    init(realm: Realm, model: AppModel, onExit: @escaping () -> Void, onNext: @escaping (Realm) -> Void) {
        self.realm = realm
        self.model = model
        self.onExit = onExit
        self.onNext = onNext
        _controller = StateObject(wrappedValue: GameController(realm: realm, model: model))
    }

    var body: some View {
        ZStack {
            SpriteView(scene: controller.scene,
                       isPaused: controller.paused || controller.result != nil,
                       preferredFramesPerSecond: 120,
                       options: [.ignoresSiblingOrder],
                       debugOptions: model.settings.showFPS ? [.showsFPS, .showsNodeCount, .showsDrawCount] : [])
                .ignoresSafeArea()

            if controller.paused {
                PauseMenu(onResume: { controller.setPaused(false) },
                          onRetry: { retry?.run() },
                          onQuit: onExit)
            }
            if let result = controller.result {
                ResultsView(realm: realm, result: result,
                            next: result.won ? model.next(after: realm) : nil,
                            onRetry: { retry?.run() },
                            onNext: onNext,
                            onMap: onExit)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            let controller = controller
            controller.onMenuCommand = { [weak controller, realm, model, onNext, onExit, retry] command in
                guard let result = controller?.result else { return }
                switch command {
                case .confirm:
                    if !result.won { retry?.run() }
                    else if let next = model.next(after: realm) { onNext(next) }
                    else { onExit() }
                case .back:
                    onExit()
                }
            }
        }
    }
}

struct RetryAction {
    let run: () -> Void
}

private struct RetryActionKey: EnvironmentKey {
    static let defaultValue: RetryAction? = nil
}

extension EnvironmentValues {
    var retryAction: RetryAction? {
        get { self[RetryActionKey.self] }
        set { self[RetryActionKey.self] = newValue }
    }
}

struct PauseMenu: View {
    var onResume: () -> Void
    var onRetry: () -> Void
    var onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Paused").font(.largeTitle.weight(.heavy))
                Button("Resume", action: onResume).buttonStyle(.borderedProminent)
                Button("Restart realm", action: onRetry).buttonStyle(.bordered)
                Button("Back to map", action: onQuit).buttonStyle(.bordered)
                Text("Keyboard: Space jump · hold to flip · Esc pause\nController: Ⓐ jump · hold to flip · Menu pause")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .opacity(0.75)
                    .padding(.top, 6)
            }
            .foregroundStyle(.white)
            .padding(30)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}
