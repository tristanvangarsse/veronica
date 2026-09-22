# Third-party release binaries

Veronica development builds can use Python, FFmpeg/ffprobe and HandBrakeCLI installed on the developer Mac.
Public releases should instead carry redistributable, self-contained macOS builds and their required license notices.

Do not commit Homebrew cellar paths or arbitrary dylibs and assume they are portable. Use `scripts/check_release_readiness_macos.sh` and inspect `otool -L` before distributing an app.
