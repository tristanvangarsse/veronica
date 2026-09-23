#!/usr/bin/env python3

import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "media_maintenance.py"

with tempfile.TemporaryDirectory(prefix="veronica-filename-settings-") as td:
    base = Path(td)
    state = base / "State"
    media = base / "Media"
    media.mkdir()

    subprocess.run(
        [
            "python3", str(ENGINE),
            "configure-library",
            "--state-dir", str(state),
            "--root", str(media),
        ],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )

    result = subprocess.run(
        [
            "python3", str(ENGINE),
            "configure-filenames",
            "--state-dir", str(state),
            "--enabled", "false",
            "--date-format", "YYYY-MM-DD_",
            "--max-bytes", "144",
        ],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )

    saved = json.loads(result.stdout)
    assert saved == {
        "enabled": False,
        "date_format": "YYYY-MM-DD_",
        "max_bytes": 144,
    }, saved

    settings = json.loads((state / "settings.json").read_text())
    assert settings["filename_standardization_enabled"] is False
    assert settings["filename_date_format"] == "YYYY-MM-DD_"
    assert settings["filename_max_bytes"] == 144
    assert settings["archive_root"] == str(media.resolve())

    snap = subprocess.run(
        [
            "python3", str(ENGINE),
            "ui-snapshot",
            "--state-dir", str(state),
        ],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )

    payload = json.loads(snap.stdout)
    assert payload["filename_policy"] == {
        "enabled": False,
        "date_format": "YYYY-MM-DD_",
        "max_bytes": 144,
    }, payload["filename_policy"]

print("filename settings regression: PASS")
