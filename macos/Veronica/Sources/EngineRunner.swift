import Foundation

struct EngineResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

enum EngineRunnerError: LocalizedError {
    case engineMissing
    case pythonMissing
    case invalidOutput(String)

    var errorDescription: String? {
        switch self {
        case .engineMissing: return "Veronica's bundled media engine could not be found."
        case .pythonMissing: return "Veronica's Python runtime could not be found. Development builds can also use an installed Python 3."
        case .invalidOutput(let text): return "The Veronica engine returned invalid data: \(text)"
        }
    }
}

private final class StreamAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutData = Data()
    private var stderrData = Data()

    func append(_ data: Data, isError: Bool) {
        guard !data.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        if isError { stderrData.append(data) } else { stdoutData.append(data) }
    }

    func strings() -> (stdout: String, stderr: String) {
        lock.lock()
        defer { lock.unlock() }
        return (
            String(data: stdoutData, encoding: .utf8) ?? "",
            String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}

final class EngineRunner {
    static let shared = EngineRunner()

    private func resourceURL(_ components: String...) -> URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        return components.reduce(resources) { $0.appendingPathComponent($1) }
    }

    private func standaloneEngineURL() -> URL? {
        let candidates = [
            resourceURL("VeronicaEngine", "veronica-engine"),
            resourceURL("veronica-engine")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func engineScriptURL() throws -> URL {
        if let url = Bundle.main.url(forResource: "veronica", withExtension: "py", subdirectory: "Engine") { return url }
        if let url = Bundle.main.url(forResource: "veronica", withExtension: "py") { return url }
        throw EngineRunnerError.engineMissing
    }

    private func pythonURL() throws -> URL {
        let bundled = [
            resourceURL("Runtime", "bin", "python3"),
            resourceURL("Runtime", "Python.framework", "Versions", "Current", "bin", "python3")
        ].compactMap { $0 }
        for url in bundled where FileManager.default.isExecutableFile(atPath: url.path) { return url }

        let developmentCandidates = ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"]
        for path in developmentCandidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        throw EngineRunnerError.pythonMissing
    }

    private func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        var pathParts: [String] = []
        if let tools = resourceURL("Tools", "bin"), FileManager.default.fileExists(atPath: tools.path) {
            pathParts.append(tools.path)
        }
        if let runtime = resourceURL("Runtime", "bin"), FileManager.default.fileExists(atPath: runtime.path) {
            pathParts.append(runtime.path)
        }
        if let existing = env["PATH"], !existing.isEmpty { pathParts.append(existing) }
        env["PATH"] = pathParts.joined(separator: ":")
        env["PYTHONUNBUFFERED"] = "1"
        return env
    }

    func run(_ arguments: [String], onOutput: (@Sendable (String) -> Void)? = nil) async throws -> EngineResult {
        let process = Process()
        if let executable = standaloneEngineURL() {
            process.executableURL = executable
            process.arguments = arguments
            process.currentDirectoryURL = executable.deletingLastPathComponent()
        } else {
            let engine = try engineScriptURL()
            process.executableURL = try pythonURL()
            process.arguments = [engine.path] + arguments
            process.currentDirectoryURL = engine.deletingLastPathComponent()
        }
        process.environment = environment()

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        let accumulator = StreamAccumulator()

        func install(_ handle: FileHandle, isError: Bool) {
            handle.readabilityHandler = { h in
                let chunk = h.availableData
                guard !chunk.isEmpty else { return }
                accumulator.append(chunk, isError: isError)
                if let text = String(data: chunk, encoding: .utf8), !text.isEmpty { onOutput?(text) }
            }
        }
        install(out.fileHandleForReading, isError: false)
        install(err.fileHandleForReading, isError: true)

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                let outTail = out.fileHandleForReading.readDataToEndOfFile()
                let errTail = err.fileHandleForReading.readDataToEndOfFile()
                accumulator.append(outTail, isError: false)
                accumulator.append(errTail, isError: true)
                let collected = accumulator.strings()
                if let text = String(data: outTail + errTail, encoding: .utf8), !text.isEmpty { onOutput?(text) }
                continuation.resume(returning: EngineResult(exitCode: process.terminationStatus, stdout: collected.stdout, stderr: collected.stderr))
            }
            do { try process.run() }
            catch { continuation.resume(throwing: error) }
        }
    }

    func snapshot() async throws -> UISnapshot {
        let result = try await run(["ui-snapshot"])
        guard result.exitCode == 0 else { throw EngineRunnerError.invalidOutput(result.stderr) }
        guard let data = result.stdout.data(using: .utf8) else { throw EngineRunnerError.invalidOutput(result.stdout) }
        return try JSONDecoder().decode(UISnapshot.self, from: data)
    }

    func configureLibrary(_ path: String) async throws {
        let result = try await run(["configure-library", "--root", path])
        guard result.exitCode == 0 else {
            throw EngineRunnerError.invalidOutput(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }
}
