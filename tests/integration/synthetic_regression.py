#!/usr/bin/env python3

import json
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path("/Users/tristan/Developer/veronica-mac-app")
ENGINE = REPO / "media_maintenance.py"


def run(*args, check=True):
    p = subprocess.run(
        ["python3", str(ENGINE), *args],
        capture_output=True,
        text=True,
    )
    if check and p.returncode != 0:
        print("COMMAND FAILED:")
        print("python3", ENGINE, *args)
        print("--- stdout ---")
        print(p.stdout)
        print("--- stderr ---")
        print(p.stderr)
        raise SystemExit(p.returncode)
    return p


def ffmpeg(*args):
    p = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args],
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        print(p.stderr)
        raise SystemExit(p.returncode)


def latest_plan(state):
    db = state / "media-maintenance.sqlite"
    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row
    try:
        plan = con.execute(
            """
            SELECT *
            FROM plans
            ORDER BY created_at DESC
            LIMIT 1
            """
        ).fetchone()

        rows = con.execute(
            """
            SELECT operation, reason, executable, COUNT(*) AS count
            FROM plan_items
            WHERE plan_id=?
            GROUP BY operation, reason, executable
            ORDER BY count DESC
            """,
            (plan["plan_id"],),
        ).fetchall()

        return dict(plan), [dict(x) for x in rows]
    finally:
        con.close()


tmp = Path(tempfile.mkdtemp(prefix="veronica-synthetic-"))
library = tmp / "Completely Arbitrary Library Name"
state = tmp / "state"

try:
    # Deliberately arbitrary structure. No Streams / Photo_Library naming.
    img_dir = library / "holiday stuff" / "random nested folder"
    vid_dir = library / "misc" / "whatever"
    audio_dir = library / "audio bucket"

    img_dir.mkdir(parents=True)
    vid_dir.mkdir(parents=True)
    audio_dir.mkdir(parents=True)

    # Large image: should become a conversion candidate.
    ffmpeg(
        "-f", "lavfi",
        "-i", "color=size=5000x3000:rate=1:color=blue",
        "-frames:v", "1",
        str(img_dir / "2024-01-10_big.jpg"),
    )

    # Small image: should be no-benefit.
    ffmpeg(
        "-f", "lavfi",
        "-i", "color=size=800x600:rate=1:color=red",
        "-frames:v", "1",
        str(img_dir / "2024-01-11_small.jpg"),
    )

    # Straightforward video.
    ffmpeg(
        "-f", "lavfi",
        "-i", "testsrc=size=640x360:rate=30",
        "-t", "1",
        "-pix_fmt", "yuv420p",
        str(vid_dir / "2024-01-12_clip.mp4"),
    )

    # Tiny audio should be skipped by threshold.
    ffmpeg(
        "-f", "lavfi",
        "-i", "sine=frequency=1000:duration=1",
        str(audio_dir / "2024-01-13_tiny.wav"),
    )

    # Protected/document file should remain preserved.
    (library / "misc" / "notes.csv").write_text(
        "a,b\n1,2\n",
        encoding="utf-8",
    )

    print("=== SYNTHETIC PATHS ===")
    print("library:", library)
    print("state:", state)

    print("\n=== CONFIGURE FOLDER ===")
    run(
        "configure-folders",
        "--state-dir", str(state),
        "--add", str(library),
    )

    print("\n=== CONFIGURE ALL DATES ===")
    run(
        "configure-date-scope",
        "--state-dir", str(state),
        "--mode", "all",
    )

    print("\n=== FIRST PLAN ===")
    p = run(
        "plan",
        "--root", str(library),
        "--state-dir", str(state),
    )
    print(p.stdout)

    plan1, rows1 = latest_plan(state)

    print("Plan 1:", plan1["plan_id"])
    for row in rows1:
        print(row)

    ops1 = {
        row["operation"]: ops1_count
        for row in rows1
        for ops1_count in [row["count"]]
    }

    # More robust aggregation because same op can have multiple reasons.
    aggregate1 = {}
    for row in rows1:
        aggregate1[row["operation"]] = (
            aggregate1.get(row["operation"], 0) + row["count"]
        )

    required = {
        "CONVERT_IMAGE": 1,
        "SKIP_NO_BENEFIT": 2,  # small image + tiny audio
        "PRESERVE": 1,
    }

    failures = []

    for op, minimum in required.items():
        if aggregate1.get(op, 0) < minimum:
            failures.append(
                f"expected at least {minimum} {op}, got {aggregate1.get(op, 0)}"
            )

    if aggregate1.get("REVIEW", 0):
        failures.append(
            f"unexpected REVIEW items in simple synthetic library: "
            f"{aggregate1.get('REVIEW')}"
        )

    print("\n=== SECOND PLAN, SAME FILES ===")
    p = run(
        "plan",
        "--root", str(library),
        "--state-dir", str(state),
    )
    print(p.stdout)

    plan2, rows2 = latest_plan(state)

    print("Plan 2:", plan2["plan_id"])
    for row in rows2:
        print(row)

    aggregate2 = {}
    for row in rows2:
        aggregate2[row["operation"]] = (
            aggregate2.get(row["operation"], 0) + row["count"]
        )

    if aggregate1 != aggregate2:
        failures.append(
            "repeat planning changed operation counts without any source changes:\n"
            f"first={aggregate1}\n"
            f"second={aggregate2}"
        )

    print("\n=== UI SNAPSHOT ===")
    snap = run(
        "ui-snapshot",
        "--state-dir", str(state),
    )
    data = json.loads(snap.stdout)

    print("active_assets:", data.get("active_assets"))
    print("date_scope:", data.get("date_scope"))
    print("scan_folders:", data.get("scan_folders"))
    print("unresolved_reviews:", len(data.get("unresolved_reviews", [])))

    if data.get("date_scope", {}).get("mode") != "all":
        failures.append("date scope did not remain 'all'")

    configured_paths = {
        str(Path(p).expanduser().resolve())
        for p in data.get("scan_folders", [])
    }

    expected_library = str(library.expanduser().resolve())

    if expected_library not in configured_paths:
        failures.append(
            "configured arbitrary folder missing from snapshot: "
            f"expected={expected_library} actual={sorted(configured_paths)}"
        )

    if failures:
        print("\n=== FAIL ===")
        for failure in failures:
            print(" -", failure)
        raise SystemExit(2)

    print("\n=== PASS ===")
    print("Synthetic arbitrary-folder planning is stable.")

finally:
    shutil.rmtree(tmp, ignore_errors=True)
