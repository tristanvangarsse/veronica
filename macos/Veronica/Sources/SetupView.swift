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
                Text("Add the folders you want Veronica to scan. Setup does not modify any media files.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            Button {
                Task { await model.addScanFolders() }
            } label: {
                Label("Add Folders…", systemImage: "folder.badge.plus")
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
