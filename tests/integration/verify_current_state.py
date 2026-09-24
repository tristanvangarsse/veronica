#!/usr/bin/env python3

import json
import sqlite3
import subprocess
import sys
from collections import Counter
from pathlib import Path

REPO = Path("/Users/tristan/Developer/veronica-mac-app")
BASE_STATE = Path.home() / "Library/Application Support/Veronica"

ENGINE = REPO / "media_maintenance.py"


def run_engine(*args):
    p = subprocess.run(
        ["python3", str(ENGINE), *args],
        capture_output=True,
        text=True,
    )
    return p


def load_snapshot():
    p = run_engine(
        "ui-snapshot",
        "--state-dir",
        str(BASE_STATE),
    )
    if p.returncode != 0:
        print("FAIL: ui-snapshot")
        print(p.stderr or p.stdout)
        raise SystemExit(1)
    return json.loads(p.stdout)


def latest_plan_for_state(state_dir):
    db = state_dir / "media-maintenance.sqlite"
    if not db.exists():
        return None

    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row
    try:
        row = con.execute(
            """
            SELECT *
            FROM plans
            ORDER BY created_at DESC
            LIMIT 1
            """
        ).fetchone()

        if row is None:
            return None

        operations = con.execute(
            """
            SELECT
              operation,
              reason,
              executable,
              COUNT(*) AS count
            FROM plan_items
            WHERE plan_id=?
            GROUP BY operation, reason, executable
            ORDER BY count DESC
            """,
            (row["plan_id"],),
        ).fetchall()

        processing = con.execute(
            """
            SELECT
              operation,
              status,
              COUNT(*) AS count
            FROM processing_history
            GROUP BY operation, status
            ORDER BY operation, status
            """
        ).fetchall()

        dispositions = con.execute(
            """
            SELECT
              disposition,
              COUNT(*) AS count
            FROM disposition_history
            GROUP BY disposition
            ORDER BY disposition
            """
        ).fetchall()

        commits = con.execute(
            """
            SELECT
              status,
              COUNT(*) AS count
            FROM commit_items
            GROUP BY status
            ORDER BY status
            """
        ).fetchall()

        return {
            "db": str(db),
            "plan": dict(row),
            "operations": [dict(x) for x in operations],
            "processing": [dict(x) for x in processing],
            "dispositions": [dict(x) for x in dispositions],
            "commits": [dict(x) for x in commits],
        }
    finally:
        con.close()


def collect_states():
    states = []

    if (BASE_STATE / "media-maintenance.sqlite").exists():
        states.append(BASE_STATE)

    folder_root = BASE_STATE / "folders"
    if folder_root.exists():
        for child in sorted(folder_root.iterdir()):
            if (child / "media-maintenance.sqlite").exists():
                states.append(child)

    return states


def print_table(title, rows):
    print(f"\n=== {title} ===")
    if not rows:
        print("(none)")
        return

    keys = list(rows[0].keys())
    widths = {
        key: max(
            len(key),
            max(len(str(row.get(key, ""))) for row in rows),
        )
        for key in keys
    }

    print("  ".join(key.ljust(widths[key]) for key in keys))
    print("  ".join("-" * widths[key] for key in keys))

    for row in rows:
        print(
            "  ".join(
                str(row.get(key, "")).ljust(widths[key])
                for key in keys
            )
        )


snapshot = load_snapshot()

print("=== UI SNAPSHOT ===")
print("version:", snapshot.get("version"))
print("configured:", snapshot.get("configured"))
print("archive_available:", snapshot.get("archive_available"))
print("date_scope:", snapshot.get("date_scope"))
print("scan_folders:", snapshot.get("scan_folders"))
print("active_assets:", snapshot.get("active_assets"))
print("committed_outputs:", snapshot.get("committed_outputs"))
print("rolled_back_outputs:", snapshot.get("rolled_back_outputs"))
print("total_saving_bytes:", snapshot.get("total_saving_bytes"))
print("unresolved_reviews:", len(snapshot.get("unresolved_reviews", [])))
print("recent_changes:", len(snapshot.get("recent_changes", [])))

latest = snapshot.get("latest_plan")

if latest:
    print("\n=== SNAPSHOT LATEST PLAN ===")
    for key in [
        "plan_id",
        "run_date",
        "item_count",
        "executable_count",
        "remaining_executable_count",
        "review_count",
        "unresolved_review_count",
    ]:
        print(f"{key}:", latest.get(key))
else:
    print("\nNo latest plan in snapshot.")

states = collect_states()

print("\n=== STATE DIRECTORIES ===")
for state in states:
    print(state)

for state in states:
    result = latest_plan_for_state(state)

    print("\n")
    print("=" * 72)
    print("STATE:", state)
    print("=" * 72)

    if result is None:
        print("No database/plan")
        continue

    plan = result["plan"]

    print("\nLatest plan:")
    for key in [
        "plan_id",
        "run_date",
        "item_count",
        "executable_count",
        "review_count",
        "status",
        "created_at",
    ]:
        print(f"{key}:", plan.get(key))

    print_table(
        "PLAN OPERATIONS",
        result["operations"],
    )

    print_table(
        "PROCESSING HISTORY",
        result["processing"],
    )

    print_table(
        "DISPOSITIONS",
        result["dispositions"],
    )

    print_table(
        "COMMIT ITEMS",
        result["commits"],
    )


print("\n=== CONSISTENCY CHECKS ===")

failures = []

reviews = snapshot.get("unresolved_reviews", [])
snapshot_review_count = len(reviews)

if latest:
    unresolved_from_plan = latest.get("unresolved_review_count")
    if unresolved_from_plan is not None:
        if int(unresolved_from_plan) != snapshot_review_count:
            failures.append(
                f"snapshot unresolved review mismatch: "
                f"latest_plan={unresolved_from_plan} "
                f"review_list={snapshot_review_count}"
            )

committed_outputs = int(snapshot.get("committed_outputs") or 0)

processing_committed = 0
for state in states:
    result = latest_plan_for_state(state)
    if result is None:
        continue

    for row in result["processing"]:
        if row["status"] == "COMMITTED":
            processing_committed += int(row["count"])

if committed_outputs != processing_committed:
    failures.append(
        f"committed output mismatch: "
        f"snapshot={committed_outputs} "
        f"processing_history={processing_committed}"
    )

if failures:
    print("FAIL")
    for failure in failures:
        print(" -", failure)
    raise SystemExit(2)

print("PASS")
