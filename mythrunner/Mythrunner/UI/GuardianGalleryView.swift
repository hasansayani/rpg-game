#if DEBUG
import SpriteKit
import SwiftUI

/// Debug-only: every realm's guardian on one screen, for art review (`-guardianGallery YES`).
struct GuardianGalleryView: View {
    @EnvironmentObject var model: AppModel
    @State private var page = 0

    var body: some View {
        let perPage = 10
        let realms = Array(model.realms.dropFirst(page * perPage).prefix(perPage))
        SpriteView(scene: GuardianGalleryScene(realms: realms, model: model))
            .id(page)
            .ignoresSafeArea()
            .onTapGesture { page = (page + 1) % 3 }
            .onAppear { page = UserDefaults.standard.integer(forKey: "galleryPage") }
    }
}

private final class GuardianGalleryScene: SKScene {
    init(realms: [Realm], model: AppModel) {
        super.init(size: CGSize(width: 1400, height: 640))
        scaleMode = .aspectFit
        backgroundColor = UIColor(white: 0.16, alpha: 1)
        let dot = TextureFactory.softDot()
        for (i, realm) in realms.enumerated() {
            let col = i % 5, row = i / 5
            let center = CGPoint(x: 140 + CGFloat(col) * 280, y: row == 0 ? 360 : 40)
            let palette = model.palette(for: realm)
            let g = GuardianNode(realm: realm, color: palette.guardian, eye: palette.accent,
                                 cute: model.tuning.cuteGuardians, dot: dot)
            // Serpents trail far behind their head, so shift them right and shrink them to fit the cell.
            let serpent = g.shape == .serpent
            g.position = CGPoint(x: center.x + (serpent ? 100 : 0), y: center.y + 40 + g.hoverHeight * 0.5)
            g.setScale(serpent ? 0.6 : 0.8)
            addChild(g)
            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = "\(realm.order). \(realm.guardian.name)"
            label.fontSize = 16
            label.position = CGPoint(x: center.x, y: center.y + 12)
            addChild(label)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func update(_ currentTime: TimeInterval) {
        for case let g as GuardianNode in children {
            let base = g.position.y - g.hoverHeight * 0.5 - 40
            g.animate(time: currentTime) { _ in base }
        }
    }
}
#endif
