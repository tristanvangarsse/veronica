#!/usr/bin/env python3

import hashlib
import json
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ENGINE = REPO / "media_maintenance.py"


def run(*args, check=True):
    cmd = ["python3", str(ENGINE), *map(str, args)]
    print("\n$", " ".join(cmd))
    result = subprocess.run(
        cmd,
        cwd=REPO,
        text=True,
        capture_output=True,
    )

    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)

    if check and result.returncode != 0:
        raise RuntimeError(
            f"Command failed with exit code {result.returncode}: "
            + " ".join(cmd)
        )

    return result


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def newest(pattern):
    files = sorted(pattern.parent.glob(pattern.name), key=lambda p: p.stat().st_mtime)
    if not files:
        raise RuntimeError(f"No files matched {pattern}")
    return files[-1]


tmp = Path(tempfile.mkdtemp(prefix="veronica-lifecycle-"))
library = tmp / "Totally Arbitrary Folder Layout"
media_dir = library / "whatever" / "nested" / "place"
state = tmp / "state"

media_dir.mkdir(parents=True)
state.mkdir(parents=True)

source = media_dir / "2020-01-02_lifecycle-test.jpg"

print("=== PATHS ===")
print("tmp:", tmp)
print("library:", library)
print("state:", state)
print("source:", source)

failures = []

try:
    print("\n=== CREATE LARGE TEST IMAGE ===")

    create = subprocess.run(
        [
            "python3",
            "-c",
            """
from PIL import Image
from pathlib import Path
import sys

path = Path(sys.argv[1])

# 5000 x 3000 = 15 MP, deliberately above Veronica's 10 MP general target.
img = Image.new("RGB", (5000, 3000), (180, 100, 220))
img.save(path, format="JPEG", quality=96)
""",
            str(source),
        ],
        text=True,
        capture_output=True,
    )

    if create.returncode != 0:
        print(create.stderr)
        raise RuntimeError("Could not create synthetic JPEG")

    original_hash = sha256(source)
    original_size = source.stat().st_size

    print("original hash:", original_hash)
    print("original size:", original_size)

    print("\n=== CONFIGURE FOLDER ===")
    run(
        "configure-folders",
        "--state-dir", state,
        "--add", library,
    )

    print("\n=== CONFIGURE ALL DATES ===")
    run(
        "configure-date-scope",
        "--state-dir", state,
        "--mode", "all",
    )

    print("\n=== PLAN ===")
    run(
        "plan",
        "--root", library,
        "--state-dir", state,
    )

    plan = newest(state / "plan-*.json")
    print("plan:", plan)

    plan_data = json.loads(plan.read_text())
    executable = [
        x for x in plan_data.get("items", [])
        if x.get("executable")
    ]

    print("executable items:", len(executable))

    if len(executable) != 1:
        failures.append(
            f"expected exactly 1 executable item, got {len(executable)}"
        )
    elif executable[0].get("operation") != "CONVERT_IMAGE":
        failures.append(
            "expected executable operation CONVERT_IMAGE, got "
            + str(executable[0].get("operation"))
        )

    print("\n=== STAGE / VERIFY ===")
    run(
        "stage",
        "--plan", plan,
        "--state-dir", state,
        "--max-images", "1",
        "--max-videos", "0",
        "--max-audio", "0",
    )

    db = state / "media-maintenance.sqlite"

    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row

    staging_row = con.execute(
        """
        SELECT staging_id
        FROM staging_runs
        ORDER BY started_at DESC
        LIMIT 1
        """
    ).fetchone()

    if staging_row is None:
        failures.append("no staging run was recorded")
        staging_id = None
    else:
        staging_id = staging_row["staging_id"]
        print("staging_id:", staging_id)

    staged = con.execute(
        """
        SELECT status, output_path
        FROM staging_items
        ORDER BY rowid DESC
        LIMIT 1
        """
    ).fetchone()

    if staged is None:
        failures.append("no staging item was recorded")
    else:
        print("staged status:", staged["status"])
        print("staged output:", staged["output_path"])
        if staged["status"] != "STAGED_VERIFIED":
            failures.append(
                f"expected STAGED_VERIFIED, got {staged['status']}"
            )

    con.close()

    if staging_id is None:
        raise RuntimeError("Cannot continue without staging ID")

    print("\n=== COMMIT ===")
    run(
        "commit-batch",
        "--staging-id", staging_id,
        "--state-dir", state,
        "--max-items", "1",
        "--yes",
    )

    converted = source.with_suffix(".jpg")

    # Same suffix is possible, so locate the committed final path from SQLite.
    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row

    committed = con.execute(
        """
        SELECT commit_id, final_path, quarantine_path, status
        FROM commit_items
        ORDER BY rowid DESC
        LIMIT 1
        """
    ).fetchone()

    if committed is None:
        failures.append("no commit item recorded")
        commit_id = None
        final_path = None
        quarantine_path = None
    else:
        commit_id = committed["commit_id"]
        final_path = Path(committed["final_path"])
        quarantine_path = Path(committed["quarantine_path"])

        print("commit_id:", commit_id)
        print("status:", committed["status"])
        print("final_path:", final_path)
        print("quarantine_path:", quarantine_path)

        if committed["status"] != "COMMITTED":
            failures.append(
                f"expected COMMITTED, got {committed['status']}"
            )

        if not final_path.exists():
            failures.append("committed final file does not exist")

        if not quarantine_path.exists():
            failures.append("quarantined original does not exist")

    con.close()

    if final_path and final_path.exists():
        committed_hash = sha256(final_path)
        committed_size = final_path.stat().st_size
        print("committed hash:", committed_hash)
        print("committed size:", committed_size)

        if committed_hash == original_hash:
            failures.append("committed file hash equals original hash")

        if committed_size >= original_size:
            failures.append(
                "expected committed file to be smaller than original "
                f"({committed_size} >= {original_size})"
            )

    print("\n=== RERUN PLAN AFTER COMMIT ===")
    run(
        "plan",
        "--root", library,
        "--state-dir", state,
    )

    rerun_plan = newest(state / "plan-*.json")
    rerun_data = json.loads(rerun_plan.read_text())

    rerun_exec = [
        x for x in rerun_data.get("items", [])
        if x.get("executable")
    ]

    print("rerun executable count:", len(rerun_exec))

    for item in rerun_exec:
        print(
            item.get("operation"),
            item.get("reason"),
            item.get("relpath"),
        )

    if rerun_exec:
        failures.append(
            f"expected zero executable items after commit, got {len(rerun_exec)}"
        )

    if commit_id is None:
        raise RuntimeError("Cannot test rollback without commit ID")

    print("\n=== ROLLBACK ===")
    run(
        "rollback",
        "--state-dir", state,
        "--commit-id", commit_id,
        "--yes",
    )

    print("\n=== VERIFY ORIGINAL RESTORED ===")

    if not source.exists():
        failures.append("original source path does not exist after rollback")
    else:
        restored_hash = sha256(source)
        restored_size = source.stat().st_size

        print("restored hash:", restored_hash)
        print("restored size:", restored_size)

        if restored_hash != original_hash:
            failures.append(
                "rollback did not restore original byte-for-byte"
            )

        if restored_size != original_size:
            failures.append(
                "rollback did not restore original file size"
            )

    print("\n=== DATABASE FINAL STATE ===")

    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row

    for title, sql in [
        (
            "commit items",
            """
            SELECT status, COUNT(*) count
            FROM commit_items
            GROUP BY status
            ORDER BY status
            """,
        ),
        (
            "rollbacks",
            """
            SELECT status, COUNT(*) count
            FROM rollbacks
            GROUP BY status
            ORDER BY status
            """,
        ),
        (
            "processing",
            """
            SELECT operation, status, COUNT(*) count
            FROM processing_history
            GROUP BY operation, status
            ORDER BY operation, status
            """,
        ),
    ]:
        print("\n" + title + ":")
        for row in con.execute(sql):
            print(dict(row))

    con.close()

    if failures:
        print("\n=== FAIL ===")
        for failure in failures:
            print(" -", failure)
        raise SystemExit(2)

    print("\n=== PASS ===")
    print("Lifecycle regression passed:")
    print("- arbitrary nested folder")
    print("- image planned")
    print("- staged")
    print("- verified")
    print("- committed")
    print("- rerun produced no duplicate executable work")
    print("- rollback restored original bytes")

finally:
    shutil.rmtree(tmp, ignore_errors=True)
