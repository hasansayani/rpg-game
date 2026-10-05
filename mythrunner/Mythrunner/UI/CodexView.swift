import SwiftUI

/// Every story Lumi has told, grouped by region. Undiscovered entries stay hidden.
struct CodexView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Region.allCases, id: \.self) { region in
                    let realms = model.realms.filter { $0.region == region }
                    Section(region.displayName) {
                        ForEach(realms) { realm in
                            NavigationLink {
                                CodexRealmView(realm: realm)
                            } label: {
                                HStack {
                                    Circle().fill(model.palette(for: realm).accent.color).frame(width: 10, height: 10)
                                    VStack(alignment: .leading) {
                                        Text(realm.culture).font(.headline)
                                        Text(realm.name).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(found(in: realm))/\(model.lore(for: realm).count)")
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Codex")
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func found(in realm: Realm) -> Int {
        model.lore(for: realm).filter { model.progress.loreSeen.contains($0.id) }.count
    }
}

struct CodexRealmView: View {
    let realm: Realm
    @EnvironmentObject var model: AppModel

    var body: some View {
        List {
            Section {
                LabeledContent("Culture", value: realm.culture)
                LabeledContent("Where", value: realm.place)
                LabeledContent("When", value: realm.era)
                if realm.living {
                    Text("This is a living tradition — people practice and tell these stories today.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Stories") {
                ForEach(model.lore(for: realm)) { item in
                    if model.progress.loreSeen.contains(item.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            Text(item.lore.text(for: model.tuning.loreVariant))
                        }
                    } else {
                        Label("Not discovered yet", systemImage: "lock.fill").foregroundStyle(.secondary)
                    }
                }
            }
            #if DEBUG
            if let note = realm.review {
                Section("Cultural review (debug only)") { Text(note).font(.footnote) }
            }
            #endif
        }
        .navigationTitle(realm.culture)
    }
}
