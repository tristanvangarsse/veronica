#!/usr/bin/env python3
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

import media_maintenance as mm


def main() -> int:
    project = Path(__file__).resolve().parents[1]
    script = project / "media_maintenance.py"
    with tempfile.TemporaryDirectory() as td:
        base = Path(td)
        media_root = base / "Media"
        media_root.mkdir()
        old = base / "Documents" / "Media Maintenance"
        new = base / "Library" / "Application Support" / "Veronica"
        old.mkdir(parents=True)
        con = mm.init_db(old / "media-maintenance.sqlite", media_root)
        con.execute(
            "INSERT INTO staging_runs(staging_id,plan_id,started_at,status,staging_dir,report_path) VALUES(?,?,?,?,?,?)",
            ("s1", "p1", "now", "COMPLETE", str(old / "staging" / "s1"), str(old / "staging-s1.md")),
        )
        # Foreign keys are off for this synthetic historical-path row because p1 is absent.
        con.commit()
        con.execute("PRAGMA foreign_keys=OFF")
        con.execute(
            "INSERT INTO commits(commit_id,staging_id,plan_id,started_at,status,quarantine_dir,report_path) VALUES(?,?,?,?,?,?,?)",
            ("c1", "s1", "p1", "now", "COMMITTED", str(old / "quarantine" / "c1"), str(old / "commit-c1.md")),
        )
        con.execute(
            "INSERT INTO commit_items(commit_id,relpath,operation,status,quarantine_path,final_path) VALUES(?,?,?,?,?,?)",
            ("c1", "x.m4v", "CONVERT_VIDEO", "COMMITTED", str(old / "quarantine" / "c1" / "x.m4v"), str(media_root / "x.mp4")),
        )
        con.commit()
        con.close()

        dry = subprocess.run(
            [sys.executable, str(script), "migrate-state", "--from-dir", str(old), "--to-dir", str(new)],
            cwd=str(project), capture_output=True, text=True,
        )
        assert dry.returncode == 0, dry.stdout + dry.stderr
        assert "DRY RUN" in dry.stdout
        assert old.exists() and not new.exists()

        applied = subprocess.run(
            [sys.executable, str(script), "migrate-state", "--from-dir", str(old), "--to-dir", str(new), "--apply"],
            cwd=str(project), capture_output=True, text=True,
        )
        assert applied.returncode == 0, applied.stdout + applied.stderr
        assert not old.exists() and new.exists()

        con = sqlite3.connect(new / "media-maintenance.sqlite")
        staging_dir, report_path = con.execute("SELECT staging_dir,report_path FROM staging_runs WHERE staging_id='s1'").fetchone()
        quarantine_dir, commit_report = con.execute("SELECT quarantine_dir,report_path FROM commits WHERE commit_id='c1'").fetchone()
        quarantine_path, final_path = con.execute("SELECT quarantine_path,final_path FROM commit_items WHERE commit_id='c1'").fetchone()
        con.close()
        assert staging_dir == str(new / "staging" / "s1")
        assert report_path == str(new / "staging-s1.md")
        assert quarantine_dir == str(new / "quarantine" / "c1")
        assert commit_report == str(new / "commit-c1.md")
        assert quarantine_path == str(new / "quarantine" / "c1" / "x.m4v")
        assert final_path == str(media_root / "x.mp4")

    print("Veronica state migration: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
