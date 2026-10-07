import GameController

/// What a hardware keyboard or game controller asked for. Touch input stays in GameScene.
enum InputCommand {
    /// The single game button (jump / hold to flip) went down or up.
    case action(pressed: Bool)
    /// Menu / Esc / P: toggle the pause menu.
    case pause
    /// B / Backspace: leave the current overlay.
    case back
}

@MainActor
protocol InputTarget: AnyObject {
    func handle(_ command: InputCommand)
}

/// Listens to hardware keyboards and Bluetooth/MFi gamepads and forwards them to whichever
/// game is on screen. One shared instance, so a retry's new game never fights the old one
/// over the GameController handlers.
///
/// Keyboard: Space / ↑ / W / Return = jump (hold to flip) · Esc / P = pause · Backspace = back
/// Gamepad:  A / ↑ / R1 / R2 = jump (hold to flip) · Menu = pause · B = back
@MainActor
final class InputRouter {
    static let shared = InputRouter()

    weak var target: InputTarget?

    /// Every key/button currently holding the action down. The action is released only when
    /// all of them are up, so rolling from Space to the A button never drops a flip.
    private var held: Set<String> = []
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.attachKeyboard() }
        })
        observers.append(center.addObserver(forName: .GCKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.releaseAll(prefix: "kb-") }
        })
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let pad = note.object as? GCController else { return }
            MainActor.assumeIsolated { self?.attach(pad) }
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let pad = note.object as? GCController else { return }
            MainActor.assumeIsolated { self?.releaseAll(prefix: Self.prefix(for: pad)) }
        })
        attachKeyboard()
        GCController.controllers().forEach(attach)
    }

    // MARK: Keyboard

    private func attachKeyboard() {
        GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = { [weak self] _, _, key, pressed in
            MainActor.assumeIsolated { self?.key(key, pressed: pressed) }
        }
    }

    private func key(_ key: GCKeyCode, pressed: Bool) {
        switch key {
        case .spacebar, .upArrow, .keyW, .returnOrEnter, .keypadEnter:
            setHeld("kb-\(key.rawValue)", pressed)
        case .escape, .keyP:
            if pressed { target?.handle(.pause) }
        case .deleteOrBackspace:
            if pressed { target?.handle(.back) }
        default:
            break
        }
    }

    // MARK: Gamepad

    private static func prefix(for pad: GCController) -> String { "pad-\(ObjectIdentifier(pad).hashValue)-" }

    private func attach(_ pad: GCController) {
        guard let gamepad = pad.extendedGamepad else { return }
        let prefix = Self.prefix(for: pad)
        let actionButtons: [(String, GCControllerButtonInput)] = [
            ("a", gamepad.buttonA), ("up", gamepad.dpad.up),
            ("r1", gamepad.rightShoulder), ("r2", gamepad.rightTrigger),
        ]
        for (name, button) in actionButtons {
            button.pressedChangedHandler = { [weak self] _, _, pressed in
                MainActor.assumeIsolated { self?.setHeld(prefix + name, pressed) }
            }
        }
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            MainActor.assumeIsolated { if pressed { self?.target?.handle(.pause) } }
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            MainActor.assumeIsolated { if pressed { self?.target?.handle(.back) } }
        }
    }

    // MARK: Action state

    private func setHeld(_ id: String, _ pressed: Bool) {
        let wasDown = !held.isEmpty
        if pressed { held.insert(id) } else { held.remove(id) }
        if held.isEmpty == wasDown { target?.handle(.action(pressed: !wasDown)) }
    }

    private func releaseAll(prefix: String) {
        held.filter { $0.hasPrefix(prefix) }.forEach { setHeld($0, false) }
    }
}
