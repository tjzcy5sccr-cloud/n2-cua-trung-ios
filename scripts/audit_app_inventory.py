#!/usr/bin/env python3
"""Kiểm tra dữ liệu đưa vào app; không chứng nhận độ chính xác bản dịch."""
import json
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parents[1]
base = json.loads((root / "N2CuaTrung/Resources/content.json").read_text(encoding="utf-8"))
names = ["n2-expansion-01", "openjlpt-n2-core", "vn26-original-practice-01", "n2-reading-listening-02"]
packs = [json.loads((root / "content-packs" / (name + ".json")).read_text(encoding="utf-8")) for name in names]
approved = {"editorial_reviewed", "source_verified", "independently_verified"}
fields = {"vocab": "meaningStatus", "grammar": "grammarStatus", "kanji": "meaningStatus"}
report = {"bundled": {}, "packs": {}, "merged": {}, "unapproved": {}, "collisions": {}}
for section in ("vocab", "grammar", "kanji", "readings", "listening"):
    status_field = fields.get(section)
    def valid(row):
        if not status_field:
            return True
        meaning = (row.get("meaning") or "").strip()
        return row.get(status_field) in approved and bool(meaning) and not meaning.startswith("EN ·")
    original = base.get(section, [])
    report["bundled"][section] = len(original)
    entries = [x for x in original if valid(x)]
    seen = {x["id"]: x for x in entries}
    collisions = 0
    rejected = sum(not valid(x) for x in original)
    for pack in packs:
        rows = pack.get(section) or []
        report["packs"].setdefault(pack["id"], {})[section] = len(rows)
        for item in rows:
            if not valid(item):
                rejected += 1
                continue
            if item["id"] in seen:
                collisions += 1
            seen[item["id"]] = item
    report["merged"][section] = len(seen)
    report["unapproved"][section] = rejected
    report["collisions"][section] = collisions
    if len(seen) != len(set(seen)):
        raise SystemExit("Duplicate merged IDs in " + section)
output = root / "qa-reports" / "n2-app-inventory.json"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
