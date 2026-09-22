import datetime as dt

from media_audit import Auditor


def timestamp(year, month, day):
    return dt.datetime(year, month, day, 12, 0, 0).timestamp()


def resolve(row):
    auditor = object.__new__(Auditor)
    auditor.resolve_date(row)
    return row


# Structured Streams archive:
# birth + mtime + containing year all agree.
row = resolve({
    "name": "Screenshot 2.png",
    "embedded_creation_time": None,
    "birth_ts": timestamp(2023, 1, 1),
    "mtime_ts": timestamp(2023, 1, 1),
    "folder_year": 2023,
    "relpath": "Streams/Image/2023/Screenshot 2.png",
})

assert row["best_date"] == "2023-01-01", row
assert row["date_confidence"] == "MEDIUM", row
assert row["date_source"] == "filesystem_birth_mtime_folder_agree", row


# If mtime disagrees materially, do not silently promote the date.
row = resolve({
    "name": "Screenshot.png",
    "embedded_creation_time": None,
    "birth_ts": timestamp(2023, 1, 1),
    "mtime_ts": timestamp(2026, 9, 22),
    "folder_year": 2023,
    "relpath": "Streams/Image/2023/Screenshot.png",
})

assert row["date_confidence"] == "LOW", row
assert row["date_source"] == "filesystem_birth", row


# Photo_Library year directories are project grouping, not authoritative
# archive-year evidence, so keep the old conservative behavior there.
row = resolve({
    "name": "Screenshot.png",
    "embedded_creation_time": None,
    "birth_ts": timestamp(2023, 1, 1),
    "mtime_ts": timestamp(2023, 1, 1),
    "folder_year": 2023,
    "relpath": "Photo_Library/2023/Screenshot.png",
})

assert row["date_confidence"] == "LOW", row
assert row["date_source"] == "filesystem_birth", row

print("date evidence policy regression: PASS")
