#!/usr/bin/env python3
import subprocess
import sys
import tempfile
from pathlib import Path


def run_case(script: Path, project: Path, base: Path, run_date: str, expected_cutoff: str) -> None:
    root = base / f"root-{run_date}"
    state = base / f"state-{run_date}"
    root.mkdir()
    state.mkdir()
    proc = subprocess.run(
        [sys.executable, str(script), "annual", "--root", str(root), "--state-dir", str(state),
         "--run-date", run_date, "--yes"],
        cwd=str(project), capture_output=True, text=True,
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert f"Cutoff: files before {expected_cutoff}" in proc.stdout
    assert "Annual maintenance COMPLETE" in proc.stdout
    reports = list(state.glob(f"annual-{run_date}-*.md"))
    assert len(reports) == 1
    text = reports[0].read_text(encoding="utf-8")
    assert "Status: **COMPLETE**" in text
    assert "Review items: **0**" in text


def main() -> int:
    project = Path(__file__).resolve().parents[1]
    script = project / "media_maintenance.py"
    with tempfile.TemporaryDirectory() as td:
        base = Path(td)
        # Calendar-year annual policy: a run in year Y includes through Dec 31 of Y-2.
        run_case(script, project, base, "2026-09-22", "2025-01-01")
        run_case(script, project, base, "2027-01-02", "2026-01-01")
        run_case(script, project, base, "2027-02-05", "2026-01-01")
    print("annual controller calendar-cutoff integration: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
