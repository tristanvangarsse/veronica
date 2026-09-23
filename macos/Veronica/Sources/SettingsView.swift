import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings").font(.largeTitle.bold())
                    Text("Library location, Veronica data, runtime readiness, and diagnostics.").foregroundStyle(.secondary)
                }

                GroupBox("Media library") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.snapshot?.archiveRoot ?? "No library selected").textSelection(.enabled)
                                Text(model.snapshot?.archiveAvailable == true ? "Available" : "Unavailable")
                                    .font(.caption)
                                    .foregroundStyle(model.snapshot?.archiveAvailable == true ? Color.secondary : Color.red)
                            }
                            Spacer()
                            Button("Choose…") { Task { await model.chooseLibrary() } }
                        }
                        Text("Changing the library does not delete historical Veronica state. A new annual scan establishes the selected library's current inventory.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }

                GroupBox("Annual policy") {
                    if let annual = model.snapshot?.annual {
                        LabeledContent("Current scope") { Text("Media through \(annual.includeThrough)") }
                        LabeledContent("Rule") { Text("Through December 31 two calendar years ago") }
                    }
                }

                GroupBox("File naming") {
                    if let naming = model.snapshot?.filenamePolicy {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(
                                "Standardize media filenames",
                                isOn: Binding(
                                    get: { naming.enabled },
                                    set: { value in
                                        Task {
                                            await model.updateFilenamePolicy(enabled: value)
                                        }
                                    }
                                )
                            )

                            Text("When enabled, eligible media is named using its resolved Veronica date followed by the existing filename.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Divider()

                            LabeledContent("Format") {
                                Picker(
                                    "Format",
                                    selection: Binding(
                                        get: { naming.dateFormat },
                                        set: { value in
                                            Task {
                                                await model.updateFilenamePolicy(dateFormat: value)
                                            }
                                        }
                                    )
                                ) {
                                    Text("YYYY-MM-DD_filename.ext")
                                        .tag("YYYY-MM-DD_")
                                }
                                .labelsHidden()
                                .frame(width: 230)
                            }

                            LabeledContent("Maximum filename size") {
                                Stepper(
                                    value: Binding(
                                        get: { naming.maxBytes },
                                        set: { value in
                                            Task {
                                                await model.updateFilenamePolicy(maxBytes: value)
                                            }
                                        }
                                    ),
                                    in: 32...255,
                                    step: 1
                                ) {
                                    Text("\(naming.maxBytes) UTF-8 bytes")
                                        .monospacedDigit()
                                }
                            }

                            Text("The limit includes the date prefix and file extension. Veronica truncates only the original filename portion and never splits a UTF-8 character. The filesystem safety ceiling is 255 bytes.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            LabeledContent("Example") {
                                Text("2023-01-01_Screenshot 1.jpg")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        .padding(.vertical, 4)
                        .disabled(model.isRunningAnnual)
                    }
                }

                GroupBox("Veronica data") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Location") { Text(model.snapshot?.stateDir ?? "—").textSelection(.enabled) }
                        LabeledContent("Database") { Text(model.snapshot?.databaseExists == true ? "Ready" : "Created on first scan") }
                        Button("Reveal Veronica Data in Finder") { model.revealStateDirectory() }
                    }.padding(.vertical, 4)
                }

                GroupBox("Runtime & media tools") {
                    if let p = model.snapshot?.preflight {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(p.requiredToolsReady ? "Ready for annual maintenance" : "Dependencies required")
                                        .font(.headline)
                                    Text(p.requiredToolsReady
                                         ? "All required runtime components are available."
                                         : "Annual maintenance remains disabled until the missing requirements below are available.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Refresh") {
                                    Task { await model.refresh() }
                                }
                                .disabled(model.isLoading)
                            }

                            if !p.missingRequirements.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Missing: \(p.missingRequirements.joined(separator: ", "))")
                                        .font(.callout.weight(.medium))

                                    if p.tools["ffmpeg"]?.available != true || p.tools["ffprobe"]?.available != true {
                                        Text("brew install ffmpeg")
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                    }

                                    if p.tools["HandBrakeCLI"]?.available != true {
                                        Text("brew install handbrake")
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                    }

                                    if !p.pillow.available {
                                        Text("python3 -m pip install Pillow==11.3.0")
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                    }

                                    if p.python.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Python 3 is required before Veronica can run its engine.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(10)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            }

                            Divider()

                            ToolRow(name: "Python / engine runtime", ready: !p.python.isEmpty, detail: p.pythonVersion)
                            ToolRow(name: "Pillow", ready: p.pillow.available, detail: p.pillow.version)

                            ForEach(["file", "ffprobe", "ffmpeg", "HandBrakeCLI", "xattr"], id: \.self) { name in
                                ToolRow(name: name, ready: p.tools[name]?.available == true, detail: p.tools[name]?.path)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                GroupBox("Diagnostics") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Developer Mode", isOn: Binding(get: { model.developerMode }, set: { model.setDeveloperMode($0) }))
                        Text("Developer Mode keeps more detailed local engine diagnostics. It never changes media-processing policy.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Copy Debug Info") { model.copyDiagnosticReport() }
                            Button("Export Diagnostics…") { model.exportDiagnostics() }
                            Button("Reveal Log in Finder") { model.revealLogFile() }
                        }
                        Text("Exported diagnostics are privacy-sanitized: home/library paths are replaced and media filenames are omitted from the structured event summary.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }

                GroupBox("About") {
                    LabeledContent("Veronica version") { Text(model.snapshot?.version ?? "0.13.2") }
                    Text("Veronica uses verified staging, per-file quarantine, rollback, and durable audit history.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
            }.padding(28)
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
