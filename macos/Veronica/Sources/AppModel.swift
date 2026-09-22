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

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await EngineRunner.shared.snapshot()
            errorMessage = nil
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

    func reveal(_ path: String?) {
        guard let path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func revealReview(_ item: ReviewItem) {
        guard let root = snapshot?.archiveRoot else { return }
        reveal(URL(fileURLWithPath: root).appendingPathComponent(item.relpath).path)
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
