import media_maintenance as mm


def base_probe(avg="30000/1001", nominal="30/1"):
    return {
        "streams": [
            {
                "codec_type": "video",
                "codec_name": "h264",
                "avg_frame_rate": avg,
                "r_frame_rate": nominal,
            }
        ],
        "format": {},
        "chapters": [],
    }


def main():
    cfg = dict(mm.DEFAULT_CONFIG)

    stable = {
        "positive_interval_count": 129,
        "duplicate_pts_count": 0,
        "backwards_pts_count": 0,
        "outside_5_percent": 0.0,
        "p95_p05_spread": 1.00003,
    }
    assert mm.classify_video_frame_timing(stable, cfg) == "cfr_like"
    assert "variable_frame_rate" not in mm.video_source_review_reasons(base_probe(), cfg, stable)

    # Regression: a clip may have perfectly stable decoded timestamps while its
    # declared frame count describes a materially different frame population.
    # HandBrake can then synthesize/retime frames; keep such a source in REVIEW.
    count_mismatch = dict(stable)
    count_mismatch.update(timestamp_count=103, declared_frame_count=118)
    assert mm.classify_video_frame_timing(count_mismatch, cfg) == "frame_count_mismatch"
    reasons = mm.video_source_review_reasons(base_probe(avg="7080/131", nominal="60/1"), cfg, count_mismatch)
    assert "frame_count_mismatch" in reasons

    # A few isolated cadence outliers above the 1% allowance stay conservative.
    borderline = dict(stable)
    borderline.update(outside_5_percent=2.3, p95_p05_spread=1.0)
    assert mm.classify_video_frame_timing(borderline, cfg) == "variable"
    assert "variable_frame_rate" in mm.video_source_review_reasons(base_probe(), cfg, borderline)

    variable = dict(stable)
    variable.update(outside_5_percent=38.6, p95_p05_spread=2.0)
    assert mm.classify_video_frame_timing(variable, cfg) == "variable"
    assert "variable_frame_rate" in mm.video_source_review_reasons(base_probe(), cfg, variable)

    backwards = dict(stable)
    backwards["backwards_pts_count"] = 2
    assert mm.classify_video_frame_timing(backwards, cfg) == "non_monotonic"
    reasons = mm.video_source_review_reasons(base_probe(avg="57/1", nominal="60/1"), cfg, backwards)
    assert "non_monotonic_frame_timestamps" in reasons
    assert "variable_frame_rate" not in reasons

    duplicate = dict(stable)
    duplicate["duplicate_pts_count"] = 1
    assert mm.classify_video_frame_timing(duplicate, cfg) == "duplicate_pts"
    assert "duplicate_frame_timestamps" in mm.video_source_review_reasons(base_probe(), cfg, duplicate)

    # If summary rates agree, timing classification is not needed at all.
    assert "variable_frame_rate" not in mm.video_source_review_reasons(base_probe(avg="30/1", nominal="30/1"), cfg, None)

    print("VFR timing classifier regression: PASS")


if __name__ == "__main__":
    main()
