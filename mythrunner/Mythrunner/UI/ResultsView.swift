import SwiftUI

/// End-of-realm recap. Doubles as the "learning moment": stories you heard are shown in full,
/// stories you missed are teased to encourage a replay.
struct ResultsView: View {
    let realm: Realm
    let result: RunResult
    let next: Realm?
    var onRetry: () -> Void
    var onNext: (Realm) -> Void
    var onMap: () -> Void
    @EnvironmentObject var model: AppModel

    var body: some View {
        let variant = model.tuning.loreVariant
        let lore = model.lore(for: realm)
        let heard = Set(result.loreSeen).union(model.progress.loreSeen)

        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.won ? "Realm complete!" : "So close!")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text(realm.name).font(.headline).opacity(0.8)
                    HStack(spacing: 16) {
                        stat("Relics", "\(result.relics)/3", "diamond.fill")
                        stat("Flips", "\(result.flips)", "arrow.counterclockwise")
                        stat("Motes", "\(result.motes)/\(result.totalMotes)", "sparkles")
                        stat("Stories", "\(result.loreSeen.count)/\(lore.count)", "book.fill")
                    }
                    .padding(.vertical, 6)
                    Spacer(minLength: 0)
                    HStack {
                        Button("Map", action: onMap).buttonStyle(.bordered)
                        Button("Retry", action: onRetry).buttonStyle(.bordered)
                        if let next {
                            Button("Next: \(next.name)") { onNext(next) }.buttonStyle(.borderedProminent)
                        }
                    }
                }
                .frame(maxWidth: 300, alignment: .leading)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Stories from \(realm.culture)").font(.headline)
                        ForEach(lore) { item in
                            let known = heard.contains(item.id)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(known ? item.title : "Undiscovered story")
                                    .font(.caption.weight(.heavy)).opacity(0.7)
                                Text(known ? item.lore.text(for: variant) : "Ride further or grab the relic to hear it.")
                                    .font(.callout)
                                    .opacity(known ? 1 : 0.55)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(known ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .padding(20)
        }
    }

    private func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
            Text(value).font(.title3.weight(.heavy))
            Text(title).font(.caption2).opacity(0.7)
        }
    }
}
