import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Guardian encounter", selection: $model.settings.guardianMode) {
                        ForEach(GuardianModeSetting.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Gameplay")
                } footer: {
                    Text("Chase & Escape: outrun the guardian. Gauntlet: survive 20 seconds of attacks. Weak Points: jump into 3 glowing targets. Realm's Choice mixes all three.")
                }

                Section {
                    Stepper(value: ageBinding, in: 4...99) {
                        HStack {
                            Text("Player age")
                            Spacer()
                            Text("\(model.settings.age ?? 10)").monospacedDigit()
                        }
                    }
                    LabeledContent("Experience", value: model.tuning.band.title)
                } header: {
                    Text("Player")
                } footer: {
                    Text("Younger players get brighter colors, gentler hills, closer checkpoints and simpler stories. Older players get moodier skies, more speed and fuller history.")
                }

                Section("Feel") {
                    Toggle("Haptics", isOn: $model.settings.haptics)
                    Toggle("Show FPS & draw calls", isOn: $model.settings.showFPS)
                }

                Section("Prototype") {
                    Toggle("Unlock all 30 realms", isOn: $model.settings.unlockAll)
                    Button("Reset progress", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
            .confirmationDialog("Erase all progress and collected stories?", isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button("Erase", role: .destructive) { model.progress = PlayerProgress() }
            }
        }
    }

    private var ageBinding: Binding<Int> {
        Binding(get: { model.settings.age ?? 10 }, set: { model.settings.age = $0 })
    }
}
