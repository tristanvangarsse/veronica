import json
import tempfile
from pathlib import Path

import media_audit as audit
import media_maintenance as mm


def main():
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        root = td / "Media"
        rel = Path("Streams/Image/2020/legacy-large.jpg")
        path = root / rel
        path.parent.mkdir(parents=True)
        path.write_bytes(b"legacy-review-content")
        qh = audit.quick_hash(path)
        size = path.stat().st_size

        state = td / "state"
        state.mkdir()
        db = state / "media-maintenance.sqlite"
        con = mm.init_db(db, root)
        run_id = "run-review"
        plan_id = "plan-review"
        reason = "legacy_v2_but_image_exceeds_current_target"
        con.execute(
            "INSERT INTO runs(run_id,started_at,run_date,cutoff,root,tool_version,status) VALUES(?,?,?,?,?,?,?)",
            (run_id, mm.now_iso(), "2026-09-22", "2024-09-22", str(root), mm.VERSION, "PLANNED"),
        )
        con.execute(
            "INSERT INTO assets(relpath,size,mtime_ns,quick_hash,tags_json,personal_tags_json,xattrs_json,last_seen_run,active) VALUES(?,?,?,?,?,?,?,?,1)",
            (str(rel), size, path.stat().st_mtime_ns, qh, '["compressed-v2"]', "[]", "[]", run_id),
        )
        asset_id = con.execute("SELECT asset_id FROM assets WHERE relpath=?", (str(rel),)).fetchone()[0]
        con.execute(
            "INSERT INTO plans(plan_id,created_at,run_id,run_date,cutoff,status,item_count,executable_count,review_count,plan_sha256) VALUES(?,?,?,?,?,?,?,?,?,?)",
            (plan_id, mm.now_iso(), run_id, "2026-09-22", "2024-09-22", "PLANNED", 1, 0, 1, "sha"),
        )
        con.execute(
            "INSERT INTO plan_items(plan_id,seq,asset_id,relpath,source_quick_hash,source_size,source_mtime_ns,operation,policy_version,reason,target_json,executable) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
            (plan_id, 1, asset_id, str(rel), qh, size, path.stat().st_mtime_ns, "REVIEW", None, reason, '{"max_megapixels":10}', 0),
        )
        con.execute(
            "INSERT INTO review_resolutions(asset_id,plan_id,review_reason,resolution,decided_at,source_quick_hash,source_size,details_json) VALUES(?,?,?,?,?,?,?,?)",
            (asset_id, plan_id, reason, "KEEP_AS_IS", mm.now_iso(), qh, size, json.dumps({"note": "reviewed"})),
        )
        con.commit()

        item = {
            "asset_id": asset_id,
            "relpath": str(rel),
            "source_quick_hash": qh,
            "source_size": size,
            "operation": "REVIEW",
            "policy_version": None,
            "reason": reason,
            "target": {"max_megapixels": 10},
            "executable": False,
        }
        resolved = mm.apply_historical_review_resolution(con, dict(item))
        assert resolved["operation"] == "SKIP_REVIEW_RESOLVED"
        assert resolved["target"]["review_resolution"] == "KEEP_AS_IS"
        assert resolved["target"]["review_original_reason"] == reason

        # Source changes invalidate the human resolution.
        changed = dict(item)
        changed["source_quick_hash"] = "changed"
        assert mm.apply_historical_review_resolution(con, changed)["operation"] == "REVIEW"

        changed_size = dict(item)
        changed_size["source_size"] = size + 1
        assert mm.apply_historical_review_resolution(con, changed_size)["operation"] == "REVIEW"

        # A different review reason must be reconsidered independently.
        changed_reason = dict(item)
        changed_reason["reason"] = "different_review_reason"
        assert mm.apply_historical_review_resolution(con, changed_reason)["operation"] == "REVIEW"
        con.close()

    print("review resolution persistence regression: PASS")


if __name__ == "__main__":
    main()
