import sqlite3
from pathlib import Path

import media_maintenance as mm


def make_item(relpath, final_relpath):
    return {
        "asset_id": 1,
        "relpath": relpath,
        "source_quick_hash": "abc",
        "source_size": 100,
        "source_mtime_ns": 1,
        "operation": "RENAME",
        "policy_version": "filename-standardization-v1",
        "reason": "filename_not_canonical",
        "target": {
            "final_relpath": final_relpath,
            "filename_standardization": True,
        },
        "executable": True,
    }


def apply_collision_logic(items, occupied_paths=()):
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.execute("""
        CREATE TABLE assets (
            asset_id INTEGER PRIMARY KEY,
            relpath TEXT UNIQUE NOT NULL,
            active INTEGER NOT NULL
        )
    """)
    for idx, relpath in enumerate(occupied_paths, 1):
        con.execute(
            "INSERT INTO assets(asset_id, relpath, active) VALUES(?,?,1)",
            (idx, relpath),
        )

    planned_destinations = {}
    for item in items:
        final_relpath = str((item.get("target") or {}).get("final_relpath") or "")
        if not final_relpath or final_relpath == item.get("relpath"):
            continue
        planned_destinations.setdefault(final_relpath, []).append(item)

    canonical_collision_paths = set()

    for final_relpath, grouped in planned_destinations.items():
        if len(grouped) > 1:
            canonical_collision_paths.add(final_relpath)

    for final_relpath, grouped in planned_destinations.items():
        source_relpaths = {str(i.get("relpath")) for i in grouped}
        occupied = con.execute(
            "SELECT relpath FROM assets WHERE active=1 AND relpath=?",
            (final_relpath,),
        ).fetchone()
        if occupied is not None and str(occupied["relpath"]) not in source_relpaths:
            canonical_collision_paths.add(final_relpath)

    if canonical_collision_paths:
        for item in items:
            final_relpath = str((item.get("target") or {}).get("final_relpath") or "")
            if final_relpath not in canonical_collision_paths:
                continue

            target = dict(item.get("target") or {})
            target["filename_collision"] = True
            target["filename_collision_destination"] = final_relpath

            item.update(
                operation="REVIEW",
                policy_version=None,
                executable=False,
                reason="filename_collision",
                target=target,
            )

    con.close()
    return items


# 1. Two independent files converging on one destination must both review.
items = [
    make_item(
        "Streams/Image/2023/foo.png",
        "Streams/Image/2023/2023-01-01_same.png",
    ),
    make_item(
        "Streams/Image/2023/bar.png",
        "Streams/Image/2023/2023-01-01_same.png",
    ),
]

result = apply_collision_logic(items)

assert all(i["operation"] == "REVIEW" for i in result), result
assert all(i["reason"] == "filename_collision" for i in result), result
assert all(i["executable"] is False for i in result), result


# 2. Destination occupied by another active archive asset must review.
items = [
    make_item(
        "Streams/Image/2023/foo.png",
        "Streams/Image/2023/2023-01-01_foo.png",
    ),
]

result = apply_collision_logic(
    items,
    occupied_paths=["Streams/Image/2023/2023-01-01_foo.png"],
)

assert result[0]["operation"] == "REVIEW", result
assert result[0]["reason"] == "filename_collision", result
assert result[0]["executable"] is False, result


# 3. Unique, unoccupied canonical rename remains executable.
items = [
    make_item(
        "Streams/Image/2023/foo.png",
        "Streams/Image/2023/2023-01-01_foo.png",
    ),
]

result = apply_collision_logic(items)

assert result[0]["operation"] == "RENAME", result
assert result[0]["reason"] == "filename_not_canonical", result
assert result[0]["executable"] is True, result


print("filename collision policy regression: PASS")
