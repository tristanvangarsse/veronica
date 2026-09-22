# Veronica native application architecture

## Principle

SwiftUI owns presentation and user interaction. The existing engine remains the only implementation of media planning, verification, conversion, commit, quarantine, rollback, and durable review semantics.

## Runtime layers

```text
SwiftUI
  -> EngineRunner
       -> preferred: Contents/Resources/VeronicaEngine/veronica-engine
       -> development fallback: bundled Engine/veronica.py + Python 3
  -> engine discovers tools on PATH
       -> preferred release path: Contents/Resources/Tools/bin
       -> development fallback: installed tools
  -> ~/Library/Application Support/Veronica
  -> selected user media library
```

The application is deliberately not sandboxed yet because the engine must operate on a user-selected archive and preserve filesystem metadata/xattrs/birthtime. Public distribution should use Developer ID signing/notarization and a deliberate entitlements review rather than enabling sandboxing casually.

## First run

`ui-snapshot` succeeds even when no state database exists. It returns `configured=false`, allowing SwiftUI to present a folder picker instead of an error. `configure-library` writes only Veronica's Application Support settings and does not touch media.

Existing installations remain compatible: if no settings file exists but SQLite contains the historical archive root, that root is used automatically.

An existing database cannot be repointed to a different archive. This prevents historical source identity, quarantine, rollback, and commit records from becoming associated with unrelated files.

## Native screens

- Dashboard: current state and annual action.
- Activity: live JSON-lines engine events.
- Review: unresolved current-plan decisions.
- History: committed replacements.
- Settings: selected library, state location, annual policy, and dependency readiness.

## Release packaging

A public app should not require Homebrew or a user-installed Python runtime. The repository therefore supports a standalone engine executable produced on macOS with PyInstaller. EngineRunner automatically prefers that executable.

FFmpeg/ffprobe and HandBrakeCLI must likewise be bundled using redistributable macOS builds with their license obligations satisfied. The repository's staging script is intentionally conservative: it can copy local binaries for testing but refuses to call them portable when `otool` exposes external non-system dependencies.

Apple Developer ID signing and notarization must occur on macOS with the release maintainer's credentials.
