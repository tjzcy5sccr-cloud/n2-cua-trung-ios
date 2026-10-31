#!/usr/bin/env python3
"""Expand 4 separate N2 in-app packs with already-approved material, not textbook copies.

Existing app content stays intact in the "Tổng hợp" mode. Only source entries
explicitly marked editorial_reviewed/source_verified/independently_verified are
newly admitted into individual series. Unreviewed material stays in repository
source and QA reports, not in the freshly expanded per-series learning packs.
"""
import collections
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "content-packs"
SERIES = ["mimikara", "shin-kanzen", "sou-matome", "speed-master"]
KINDS = ("vocab", "grammar", "kanji", "readings", "listening")
APPROVED = {"editorial_reviewed", "source_verified", "independently_verified"}
SOURCES = [
    ("core", BASE / "openjlpt-n2-core.json"),
    ("expansion", BASE / "n2-expansion-01.json"),
    ("vn26", BASE / "vn26-original-practice-01.json"),
    ("reading-listening", BASE / "n2-reading-listening-02.json"),
]
KEY = {"vocab": "meaningStatus", "grammar": "grammarStatus", "kanji": "meaningStatus"}

def js(path):
    return json.loads(path.read_text(encoding="utf-8"))

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

packs = {name: js(BASE / f"n2-series-{name}.json") for name in SERIES}
# Existing seeded records already shown in the older IPA: preserve their IDs and
# fields, do not pretend status is reviewed.
assigned = {kind: {} for kind in KINDS}
for name, pack in packs.items():
    for kind in KINDS:
        for entry in pack.get(kind, []):
            if entry["id"] in assigned[kind]:
                raise ValueError(f"Duplicate seed {kind}/{entry['id']}")
            assigned[kind][entry["id"]] = name

candidates = []
added = collections.defaultdict(lambda: collections.Counter())
pending = collections.defaultdict(lambda: collections.Counter())
for label, path in SOURCES:
    data = js(path)
    for kind in ("vocab", "grammar", "kanji"):
        for entry in data.get(kind, []):
            if entry["id"] in assigned[kind]:
                continue
            status = entry.get(KEY[kind]) or "missing_review_status"
            if status not in APPROVED:
                pending[kind][status] += 1
                candidates.append({"source": label, "section": kind,
                                   "id": entry["id"], "japanese": entry.get("word") or entry.get("pattern") or entry.get("char"),
                                   "meaning": entry.get("meaning", ""), "status": status})
                continue

            # Distribute into distinct method-oriented collections. This is
            # N2 Cua Trung's ORIGINAL grouping, not the order/contents of books.
            tag = (entry.get("topic", "") + entry.get("pattern", "") + entry.get("word", ""))
            bias = {"mimikara": 0, "shin-kanzen": 0, "sou-matome": 0, "speed-master": 0}
            if kind == "vocab":
                if any(x in tag for x in ("Sinh hoạt", "Giao tiếp", "Giải trí")):
                    bias["mimikara"] -= 5
                if any(x in tag for x in ("Công việc", "Xã hội", "Kinh tế")):
                    bias["shin-kanzen"] -= 5
                if "Học tập" in tag:
                    bias["sou-matome"] -= 5
                if any(x in tag for x in ("Công nghệ", "Kanji")):
                    bias["speed-master"] -= 5
            elif kind == "grammar":
                if any(x in tag for x in ("一方", "わけ", "に対して", "にもかかわらず")):
                    bias["shin-kanzen"] -= 4
            elif kind == "kanji":
                bias["speed-master"] -= 2
            scored = []
            for name in SERIES:
                original_count = len(packs[name][kind])
                stable = int(hashlib.sha256(f"{kind}:{entry['id']}:{name}".encode()).hexdigest()[:4], 16) % 9
                scored.append((original_count * 10 + bias[name] * 10 + stable, name))
            chosen = min(scored)[1]
            value = dict(entry)
            if kind == "vocab" and entry.get("exampleStatus") not in APPROVED:
                # Japanese and Vietnamese examples must be reviewed together.
                value["example"] = ""
                value["exampleVi"] = ""
            if kind == "grammar":
                if entry.get("translationStatus") not in APPROVED:
                    value["example"] = ""
                    value["translation"] = ""
                value["samples"] = [
                    sample for sample in (entry.get("samples") or [])
                    if sample.get("translationStatus") in APPROVED
                ]
            if kind == "kanji":
                # Unreviewed unrelated compound examples must not enter a reviewed Kanji card.
                value["word"] = ""
            packs[chosen][kind].append(value)
            assigned[kind][entry["id"]] = chosen
            added[chosen][kind] += 1

for name, pack in packs.items():
    pack["version"] = max(pack.get("version", 1), 2)
    save(BASE / f"n2-series-{name}.json", pack)

manifest = js(BASE / "manifest-series.json")
for entry in manifest["packs"]:
    entry["version"] = packs[entry["id"].removeprefix("n2-series-")]["version"]
save(BASE / "manifest-series.json", manifest)

summary = {
    "result": "Reviewed items expanded; source-only items staged for manual checking",
    "sources": [name for name, _ in SOURCES],
    "newApprovedCounts": {name: dict(added[name]) for name in SERIES},
    "stillUnreviewedCounts": {key: dict(value) for key, value in pending.items()},
    "totalPerSeries": {name: {kind: len(packs[name].get(kind, [])) for kind in KINDS} for name in SERIES},
    "notComplete100Percent": True,
    "notCopiesOfNamedTextbooks": True,
}
output = ROOT / "qa-reports"
output.mkdir(exist_ok=True)
save(output / "series-expansion-summary.json", summary)
save(output / "series-pending-source-review.json", {
    "licenseNote": "Unreviewed metadata source-only, not app content",
    "entries": candidates
})
print(json.dumps(summary, ensure_ascii=False, indent=2), flush=True)
