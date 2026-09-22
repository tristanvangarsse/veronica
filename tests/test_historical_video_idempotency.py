#!/usr/bin/env python3
from pathlib import Path
import sqlite3
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import media_maintenance as m


def main() -> None:
    tmp = Path(tempfile.mkdtemp(prefix="media-maintenance-v082-test-"))
    con = m.init_db(tmp / "state.sqlite", tmp)
    con.execute(
        "INSERT INTO runs(run_id,started_at,run_date,cutoff,root,tool_version,status) VALUES(?,?,?,?,?,?,?)",
        ("r", m.now_iso(), "2027-01-03", "2025-01-03", str(tmp), m.VERSION, "TEST"),
    )
    con.execute(
        "INSERT INTO assets(relpath,size,mtime_ns,quick_hash,detected_kind,extension,tags_json,personal_tags_json,xattrs_json,last_seen_run,active) VALUES(?,?,?,?,?,?,?,?,?,?,1)",
        ("Streams/Video/2024/test.mp4", 100, 1, "committed-output", "video", ".mp4", "[]", "[]", "[]", "r"),
    )
    aid = int(con.execute("SELECT asset_id FROM assets").fetchone()[0])
    con.execute(
        "INSERT INTO processing_history(asset_id,policy_version,operation,status,processed_at,output_quick_hash,output_full_hash,details_json) VALUES(?,?,?,?,?,?,?,?)",
        (aid, "streams-video-handbrake-square-pixel-720p-v3", "CONVERT_VIDEO", "COMMITTED", m.now_iso(), "committed-output", "full-v3", "{}"),
    )
    con.commit()

    hit = m.historical_video_completion(con, aid, "committed-output", None)
    assert hit is not None and hit["policy_version"].endswith("-v3")
    assert m.historical_video_completion(con, aid, "changed-output", None) is None
    assert m.historical_video_completion(con, aid, "changed-output", "full-v3") is not None

    cfg = m.load_config(ROOT / "config.example.json")
    assert cfg["policies"]["streams_video"].endswith("v4-no-autocrop")
    print("PASS historical video idempotency")


if __name__ == "__main__":
    main()
