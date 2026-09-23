import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot: UISnapshot?
    @Published var isLoading = false
    @Published var isRunningAnnual = false
    @Published var errorMessage: String?
    @Published var activityLines: [String] = []
    @Published var events: [EngineEvent] = []
    @Published var developerMode = DiagnosticsCenter.shared.developerMode

    func refresh() async {
        DiagnosticsCenter.shared.log("INFO", "App", "Refreshing UI snapshot")
        isLoading = true
        defer { isLoading = false }
        do {
            let refreshed = try await EngineRunner.shared.snapshot()
            snapshot = refreshed

            let missing = refreshed.preflight.missingRequirements
            if missing.isEmpty {
                errorMessage = nil
            } else {
                errorMessage = "Veronica is missing required dependencies: \(missing.joined(separator: ", ")). Install them, then refresh or relaunch Veronica. Annual maintenance will remain disabled until they are available."
            }
        } catch {
            errorMessage = error.localizedDescription
            DiagnosticsCenter.shared.log("ERROR", "App", "Snapshot refresh failed: \(error.localizedDescription)")
        }
    }

    func updateFilenamePolicy(
        enabled: Bool? = nil,
        dateFormat: String? = nil,
        maxBytes: Int? = nil
    ) async {
        guard let current = snapshot?.filenamePolicy else { return }

        let nextEnabled = enabled ?? current.enabled
        let nextDateFormat = dateFormat ?? current.dateFormat
        let nextMaxBytes = maxBytes ?? current.maxBytes

        do {
            try await EngineRunner.shared.configureFilenames(
                enabled: nextEnabled,
                dateFormat: nextDateFormat,
                maxBytes: nextMaxBytes
            )
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func chooseLibrary() async {
        let panel = NSOpenPanel()
        panel.title = "Choose Media Library"
        panel.message = "Choose the top-level folder Veronica should maintain. Veronica never modifies files during setup."
        panel.prompt = "Choose Library"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if let current = snapshot?.archiveRoot {
            panel.directoryURL = URL(fileURLWithPath: current)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try await EngineRunner.shared.configureLibrary(url.path)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runAnnual() async {
        guard !isRunningAnnual else { return }
        guard snapshot?.configured == true else {
            errorMessage = "Choose a media library before running annual maintenance."
            return
        }
        guard snapshot?.archiveAvailable == true else {
            errorMessage = "The configured media library is currently unavailable."
            return
        }
        guard snapshot?.preflight.requiredToolsReady == true else {
            errorMessage = "Veronica is missing one or more required media tools. Open Settings to see what is unavailable."
            return
        }

        isRunningAnnual = true
        activityLines = []
        events = []
        errorMessage = nil

        let eventURL = FileManager.default.temporaryDirectory.appendingPathComponent("veronica-events-\(UUID().uuidString).jsonl")
        let pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.loadEvents(from: eventURL)
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        defer {
            pollTask.cancel()
            loadEvents(from: eventURL)
            try? FileManager.default.removeItem(at: eventURL)
            isRunningAnnual = false
        }

        do {
            let result = try await EngineRunner.shared.run(["annual", "--yes", "--events-jsonl", eventURL.path]) { chunk in
                Task { @MainActor in
                    let newLines = chunk.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
                    self.activityLines.append(contentsOf: newLines)
                }
            }
            loadEvents(from: eventURL)
            if result.exitCode != 0 {
                errorMessage = "Annual maintenance stopped safely. Review the Activity and Review screens for details."
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadEvents(from url: URL) {
        guard let data = try? Data(contentsOf: url), !data.isEmpty,
              let text = String(data: data, encoding: .utf8) else { return }
        let decoder = JSONDecoder()
        let decoded = text.split(separator: "\n").compactMap { line -> EngineEvent? in
            guard let d = String(line).data(using: .utf8) else { return nil }
            return try? decoder.decode(EngineEvent.self, from: d)
        }
        if !decoded.isEmpty { events = decoded }
    }

    func keepAsIs(_ item: ReviewItem) async {
        guard let plan = item.planPath else {
            errorMessage = "This review item is missing its immutable plan path."
            return
        }
        do {
            let result = try await EngineRunner.shared.run([
                "resolve-review", "--plan", plan,
                "--relpath", item.relpath,
                "--resolution", "KEEP_AS_IS",
                "--note", "Reviewed in Veronica.app; preserve original.",
                "--yes"
            ])
            guard result.exitCode == 0 else {
                errorMessage = result.stderr.isEmpty ? result.stdout : result.stderr
                return
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func processNormally(_ item: ReviewItem) async {
        guard item.canProcessNormally else {
            errorMessage = "This review issue cannot safely be bypassed."
            return
        }
        guard let plan = item.planPath else {
            errorMessage = "This review item is missing its immutable plan path."
            return
        }

        do {
            let result = try await EngineRunner.shared.run([
                "resolve-review", "--plan", plan,
                "--relpath", item.relpath,
                "--resolution", "PROCESS_NORMALLY",
                "--note", "Reviewed in Veronica.app; allow normal policy evaluation.",
                "--yes"
            ])

            guard result.exitCode == 0 else {
                errorMessage = result.stderr.isEmpty ? result.stdout : result.stderr
                return
            }

            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reveal(_ path: String?) {
        guard let path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func revealReview(_ item: ReviewItem) {
        guard let root = snapshot?.archiveRoot else { return }
        reveal(URL(fileURLWithPath: root).appendingPathComponent(item.relpath).path)
    }

    func setDeveloperMode(_ enabled: Bool) {
        developerMode = enabled
        DiagnosticsCenter.shared.developerMode = enabled
        DiagnosticsCenter.shared.log("INFO", "Diagnostics", "Developer mode \(enabled ? "enabled" : "disabled")")
    }

    func copyDiagnosticReport() {
        let report = DiagnosticsCenter.shared.privacySafeReport(snapshot: snapshot, errorMessage: errorMessage, events: events)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        DiagnosticsCenter.shared.log("INFO", "Diagnostics", "Copied privacy-safe diagnostic report")
    }

    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.title = "Export Veronica Diagnostics"
        panel.nameFieldStringValue = "Veronica-Diagnostics.zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try DiagnosticsCenter.shared.exportDiagnostics(to: url, snapshot: snapshot, errorMessage: errorMessage, events: events)
            DiagnosticsCenter.shared.log("INFO", "Diagnostics", "Exported privacy-safe diagnostics ZIP")
        } catch {
            errorMessage = error.localizedDescription
            DiagnosticsCenter.shared.log("ERROR", "Diagnostics", "Export failed: \(error.localizedDescription)")
        }
    }

    func revealLogFile() {
        let url = DiagnosticsCenter.shared.logURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revealStateDirectory() {
        reveal(snapshot?.stateDir)
    }

    var latestEvent: EngineEvent? { events.last }

    var currentProgress: Double? {
        guard let event = events.last(where: { $0.index != nil && $0.total != nil }),
              let index = event.index, let total = event.total, total > 0 else { return nil }
        return min(max(Double(index) / Double(total), 0), 1)
    }
}
