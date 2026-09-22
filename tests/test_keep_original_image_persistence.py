import tempfile
from pathlib import Path

import media_maintenance as mm


def main():
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "Media"
        root.mkdir()
        db = Path(td) / "state.sqlite"
        con = mm.init_db(db, root)

        run_id = "run-image-keep"
        plan_id = "plan-image-keep"
        asset_rel = "Streams/Image/2024/sketch_002.png"
        qh = "quickhash-image"
        policy = "streams-image-test-policy"

        con.execute(
            "INSERT INTO runs(run_id,started_at,run_date,cutoff,root,tool_version,status) VALUES(?,?,?,?,?,?,?)",
            (run_id, mm.now_iso(), "2027-01-03", "2025-01-03", str(root), mm.VERSION, "COMPLETE"),
        )
        con.execute(
            "INSERT INTO assets(relpath,size,mtime_ns,tags_json,personal_tags_json,xattrs_json,last_seen_run,active) VALUES(?,?,?,?,?,?,?,1)",
            (asset_rel, 1000, 1, "[]", "[]", "[]", run_id),
        )
        asset_id = con.execute("SELECT asset_id FROM assets WHERE relpath=?", (asset_rel,)).fetchone()[0]
        con.execute(
            "INSERT INTO plans(plan_id,created_at,run_id,run_date,cutoff,status,item_count,executable_count,review_count,plan_sha256) VALUES(?,?,?,?,?,?,?,?,?,?)",
            (plan_id, mm.now_iso(), run_id, "2027-01-03", "2025-01-03", "FROZEN", 1, 1, 0, "sha"),
        )
        con.execute(
            "INSERT INTO plan_items(plan_id,seq,asset_id,relpath,source_quick_hash,source_size,source_mtime_ns,operation,policy_version,reason,target_json,executable) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
            (plan_id, 1, asset_id, asset_rel, qh, 1000, 1, "CONVERT_IMAGE", policy, "test", "{}", 1),
        )
        con.execute(
            "INSERT INTO staging_runs(staging_id,plan_id,started_at,completed_at,status,staging_dir,report_path) VALUES(?,?,?,?,?,?,?)",
            ("stage1", plan_id, mm.now_iso(), mm.now_iso(), "COMPLETE", str(Path(td) / "stage"), None),
        )
        con.execute(
            "INSERT INTO staging_items(staging_id,relpath,operation,status,source_size,output_size,saving_bytes,saving_percent,verification_json) VALUES(?,?,?,?,?,?,?,?,?)",
            ("stage1", asset_rel, "CONVERT_IMAGE", "KEEP_ORIGINAL", 1000, 1668, -668, -66.8, "{}"),
        )
        con.commit()
        con.close()

        # Reopening runs the v0.8.7 migration/backfill.
        con = mm.init_db(db, root)
        kept = mm.historical_keep_original(con, asset_id, "CONVERT_IMAGE", policy, qh, 1000)
        assert kept is not None, "image KEEP_ORIGINAL should be durable"
        resolved = mm.resolved_keep_original_relpaths(con, plan_id, "CONVERT_IMAGE")
        assert asset_rel in resolved, "image KEEP_ORIGINAL should be resolved in run-status/next-batch accounting"

        # Changed content must invalidate the disposition.
        assert mm.historical_keep_original(con, asset_id, "CONVERT_IMAGE", policy, "changed", 1000) is None
        # Changed policy must invalidate the disposition.
        assert mm.historical_keep_original(con, asset_id, "CONVERT_IMAGE", "new-policy", qh, 1000) is None
        con.close()

    print("image KEEP_ORIGINAL persistence regression: PASS")


if __name__ == "__main__":
    main()
