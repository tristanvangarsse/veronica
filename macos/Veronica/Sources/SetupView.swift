import SwiftUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)
            VStack(spacing: 8) {
                Text("Welcome to Veronica").font(.largeTitle.bold())
                Text("Choose the media library you want Veronica to maintain. Setup does not modify any media files.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            Button {
                Task { await model.chooseLibrary() }
            } label: {
                Label("Choose Media Library…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Veronica stores its database, plans, reports, staging, and quarantine in ~/Library/Application Support/Veronica.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }
}
