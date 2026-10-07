import SwiftUI

/// Shown between a failure and the respawn: carry on from the last checkpoint, or leave the realm.
struct ContinueMenu: View {
    var retries: Int
    var checkpoint: Int
    var inGuardian: Bool
    var onContinue: () -> Void
    var onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(inGuardian ? "The guardian got you!" : "You fell!")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                Text(inGuardian ? "Try the encounter again from the start."
                     : checkpoint == 0 ? "Start again from the beginning of the realm."
                     : "Start again from checkpoint ⚑ \(checkpoint).")
                    .font(.headline).opacity(0.85)
                Text("Every myth has a second chance · tries so far: \(retries)")
                    .font(.caption).opacity(0.7)
                HStack(spacing: 14) {
                    Button(action: onQuit) {
                        Label("Quit", systemImage: "xmark").frame(minWidth: 110)
                    }
                    .buttonStyle(.bordered)
                    Button(action: onContinue) {
                        Label("Continue", systemImage: "arrow.clockwise").frame(minWidth: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 1, green: 0.78, blue: 0.34))
                    .foregroundStyle(.black)
                }
                .padding(.top, 6)
                Text("Space / Ⓐ to continue · Esc / Ⓑ to quit")
                    .font(.caption2).opacity(0.6)
            }
            .foregroundStyle(.white)
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}
