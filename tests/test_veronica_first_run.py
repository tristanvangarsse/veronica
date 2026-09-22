#!/usr/bin/env python3
import json
import subprocess
import sys
import tempfile
from pathlib import Path


def run(project: Path, *args: str):
    return subprocess.run([sys.executable, str(project / "veronica.py"), *args], cwd=str(project), capture_output=True, text=True)


def main() -> int:
    project = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as td:
        base = Path(td)
        state = base / "state"
        library = base / "Library"
        library.mkdir()

        snap = run(project, "ui-snapshot", "--state-dir", str(state))
        assert snap.returncode == 0, snap.stdout + snap.stderr
        data = json.loads(snap.stdout)
        assert data["configured"] is False
        assert data["database_exists"] is False
        assert data["archive_root"] is None

        cfg = run(project, "configure-library", "--state-dir", str(state), "--root", str(library))
        assert cfg.returncode == 0, cfg.stdout + cfg.stderr
        settings = json.loads((state / "settings.json").read_text())
        assert settings["archive_root"] == str(library.resolve())

        snap2 = run(project, "ui-snapshot", "--state-dir", str(state))
        assert snap2.returncode == 0, snap2.stdout + snap2.stderr
        data2 = json.loads(snap2.stdout)
        assert data2["configured"] is True
        assert data2["database_exists"] is False
        assert data2["archive_root"] == str(library.resolve())
        assert data2["archive_available"] is True

        # Once historical state belongs to a library, do not silently repoint it.
        import media_maintenance as mm
        con = mm.init_db(state / "media-maintenance.sqlite", library)
        con.close()
        other = base / "OtherLibrary"
        other.mkdir()
        refused = run(project, "configure-library", "--state-dir", str(state), "--root", str(other))
        assert refused.returncode != 0
        assert "different media library" in (refused.stdout + refused.stderr)

    print("Veronica first-run setup: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
