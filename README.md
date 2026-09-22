# Veronica

Veronica is a macOS application for conservative annual media care. It combines a native SwiftUI interface with the production-proven Python media engine that performs immutable planning, verified staging, bounded commits, per-file quarantine, rollback, durable `KEEP_ORIGINAL`, and guarded human review decisions.

Version **0.13.2** adds a native diagnostics workflow on top of the portability foundation: it removes personal archive-path assumptions from the app, supports a clean first launch, stores the selected media library in Application Support, adds Settings and dependency diagnostics, and prepares the app bundle for a self-contained release engine and media tools.

## User experience

A fresh installation opens with **Choose Media Library…**. Veronica stores only its own state under:

```text
~/Library/Application Support/Veronica
```

The selected library can live anywhere the user can access. Setup does not modify media. The database is created on the first scan.

The app contains:

- **Dashboard** — archive status, annual scope, indexed files, committed replacements, savings, and recent changes.
- **Activity** — live planning/staging/verification/commit progress.
- **Review** — files that Veronica deliberately refuses to guess about, with guarded **Keep As Is** decisions.
- **History** — committed replacements with before/after sizes, savings, dates, and Finder reveal.
- **Settings** — selected library, Application Support location, annual policy, and runtime/tool readiness.

## Annual policy

In calendar year **Y**, annual maintenance includes media through **December 31 of Y-2**, regardless of the month/day the app is run.

Examples:

- any 2026 run includes through 2024-12-31;
- any 2027 run includes through 2025-12-31;
- any 2028 run includes through 2026-12-31.

The engine still stops on unresolved review items or any staging/verification/commit anomaly.

## Architecture

The SwiftUI app is intentionally thin. It does not duplicate media safety policy.

```text
Veronica.app
  -> SwiftUI interface
  -> Veronica engine
  -> SQLite state in Application Support
  -> verified media operations
```

For development, `EngineRunner` can use the bundled Python source with an installed Python 3 and installed media tools.

For release builds, `EngineRunner` first looks for:

```text
Contents/Resources/VeronicaEngine/veronica-engine
Contents/Resources/Tools/bin/{ffmpeg,ffprobe,HandBrakeCLI}
```

This permits a public app release to be independent of Homebrew and a user-installed Python runtime without rewriting the engine in Swift.

## Development build

Requirements:

- macOS 13 or later;
- Xcode;
- XcodeGen;
- Python 3.9+ for the development engine;
- Pillow;
- FFmpeg/ffprobe;
- HandBrakeCLI.

Generate the Xcode project:

```bash
./scripts/generate_xcode_project.sh
```

Or manually:

```bash
cd macos
xcodegen generate
open Veronica.xcodeproj
```

## Preparing a standalone release on macOS

The source ZIP does **not** redistribute Python, FFmpeg, or HandBrake binaries. Public release binaries must include their own license notices and be built/signed on macOS.

Build the standalone Python engine:

```bash
./scripts/build_standalone_engine_macos.sh
```

The script creates a private build environment, installs PyInstaller and Pillow, and stages a self-contained `veronica-engine` executable into the app resources.

For media tools, `scripts/stage_media_tools_macos.sh` can stage locally installed tools for development and runs an `otool` dependency check. It deliberately refuses to call Homebrew-linked binaries portable when they depend on external non-system libraries. For a public GitHub release, use redistributable self-contained macOS builds and include their license notices.

Check whether all self-contained resource slots are populated:

```bash
./scripts/check_release_readiness_macos.sh
```

Then generate/build the app in Xcode. Developer ID signing and Apple notarization must be performed on macOS with the developer's own Apple credentials.

## GitHub-ready repository

The repository includes:

- `.github/workflows/ci.yml` for Python 3.9 regression tests and a macOS Swift build;
- `.gitignore` for generated Xcode/build artifacts;
- `LICENSE` and `THIRD_PARTY_NOTICES.md`;
- reproducible `macos/project.yml` rather than a committed generated Xcode project;
- scripts for engine synchronization, project generation, standalone-engine packaging, and release-readiness checks.

A suitable local canonical checkout is any normal development directory, for example `~/Developer/veronica`.

## Existing installations

Historical Veronica state remains valid. The engine can infer the existing library root from SQLite when no `settings.json` exists, so upgrading does not require reselecting the library. Once a database belongs to a library, Veronica refuses to repoint that same historical database to a different root; this protects source identity, quarantine, and rollback history.

Legacy Veronica state from the previous Documents-based storage location can be migrated explicitly:

```bash
python3 veronica.py migrate-state
python3 veronica.py migrate-state --apply
```

## Engine commands

The GUI is the primary interface, but the CLI remains available for diagnostics and recovery:

```bash
python3 veronica.py ui-snapshot
python3 veronica.py preflight
python3 veronica.py annual --yes
python3 veronica.py status
```

`configure-library --root /path/to/library` stores the selected root in Application Support for fresh installations.

## Debugging without screenshots

Veronica writes a local app log to `~/Library/Application Support/Veronica/logs/veronica.log`. In Settings, **Developer Mode** enables more detailed local engine diagnostics. **Copy Debug Info** puts a privacy-safe report on the clipboard, and **Export Diagnostics…** creates a small ZIP containing a sanitized diagnostic report and recent log excerpt. Media files and the SQLite database are never included.

For Swift/Xcode build failures, run `./scripts/debug_build_macos.sh`; it writes `/tmp/veronica-build.log` and prints the last 120 lines for easy sharing.

## Safety invariants

0.13.2 does not weaken the proven media engine. It retains strict geometry/aspect-ratio checks, no auto-crop, square-pixel requirements, frame timing/VFR review gates, color metadata preservation, audio checks, creation/birthtime preservation, Finder tags, immutable plans, worthwhile-savings checks, bounded staging/commit windows, per-file quarantine, rollback, historical completion recognition, and durable guarded dispositions.

## License

Veronica source code is open source under the MIT License. Copyright remains with the copyright holder. Third-party components retain their own licenses; see `THIRD_PARTY_NOTICES.md`.
