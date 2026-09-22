import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings").font(.largeTitle.bold())
                    Text("Library location, Veronica data, and runtime readiness.").foregroundStyle(.secondary)
                }

                GroupBox("Media library") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.snapshot?.archiveRoot ?? "No library selected")
                                    .textSelection(.enabled)
                                Text(model.snapshot?.archiveAvailable == true ? "Available" : "Unavailable")
                                    .font(.caption)
                                    .foregroundStyle(model.snapshot?.archiveAvailable == true ? Color.secondary : Color.red)
                            }
                            Spacer()
                            Button("Choose…") { Task { await model.chooseLibrary() } }
                        }
                        Text("Changing the library does not delete historical Veronica state. A new annual scan establishes the selected library's current inventory.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Annual policy") {
                    if let annual = model.snapshot?.annual {
                        LabeledContent("Current scope") { Text("Media through \(annual.includeThrough)") }
                        LabeledContent("Rule") { Text("Through December 31 two calendar years ago") }
                    }
                }

                GroupBox("Veronica data") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Location") { Text(model.snapshot?.stateDir ?? "—").textSelection(.enabled) }
                        LabeledContent("Database") { Text(model.snapshot?.databaseExists == true ? "Ready" : "Created on first scan") }
                        Button("Reveal Veronica Data in Finder") { model.revealStateDirectory() }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Runtime & media tools") {
                    if let p = model.snapshot?.preflight {
                        VStack(alignment: .leading, spacing: 8) {
                            ToolRow(name: "Python / engine runtime", ready: !p.python.isEmpty, detail: p.pythonVersion)
                            ToolRow(name: "Pillow", ready: p.pillow.available, detail: p.pillow.version)
                            ForEach(["file", "ffprobe", "ffmpeg", "HandBrakeCLI", "xattr"], id: \.self) { name in
                                ToolRow(name: name, ready: p.tools[name]?.available == true, detail: p.tools[name]?.path)
                            }
                            if !p.requiredToolsReady {
                                Text("Development builds can use tools installed on this Mac. Release builds are designed to bundle their own runtime and media tools.")
                                    .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                GroupBox("About") {
                    LabeledContent("Veronica version") { Text(model.snapshot?.version ?? "0.13.1") }
                    Text("Open-source media maintenance with verified staging, per-file quarantine, rollback, and durable audit history.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
            }
            .padding(28)
        }
    }
}

private struct ToolRow: View {
    let name: String
    let ready: Bool
    let detail: String?
    var body: some View {
        HStack {
            Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ready ? Color.green : Color.red)
            Text(name)
            Spacer()
            if let detail, !detail.isEmpty {
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
        }
    }
}
