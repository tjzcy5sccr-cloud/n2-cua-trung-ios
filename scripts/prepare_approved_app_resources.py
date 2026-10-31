#!/usr/bin/env python3
"""Validate full iOS study resources without deleting unreviewed course content.

Review flags are source metadata, not visible UI labels. This script must never
strip entries, examples, compound words, or extra grammar notes from the IPA.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKS = [
    ROOT / "N2CuaTrung/Resources/content.json",
    ROOT / "content-packs/n2-expansion-01.json",
    ROOT / "content-packs/openjlpt-n2-core.json",
    ROOT / "content-packs/vn26-original-practice-01.json",
    ROOT / "content-packs/n2-reading-listening-02.json",
]
COUNTS = {"vocab": 0, "grammar": 0, "kanji": 0, "readings": 0, "listening": 0}
def main():
    for path in PACKS:
        raw = path.read_bytes()
        pack = json.loads(raw)
        current = {}
        for key in COUNTS:
            array = pack.get(key, [])
            if not isinstance(array, list):
                raise ValueError(f"Invalid {key} in {path}")
            COUNT = len(array)
            COUNTS[key] += COUNT
            current[key] = COUNT
            if key in ("vocab", "grammar", "kanji"):
                ids = [e["id"] for e in array]
                assert len(ids) == len(set(ids)), (path, key, "duplicate IDs")
        assert path.read_bytes() == raw, "Validation must not mutate learning data!"
        print(path.relative_to(ROOT), "complete source items:", current, flush=True)
    expected = {"vocab": 2002, "grammar": 180, "kanji": 471, "readings": 74, "listening": 70}
    assert COUNTS == expected, f"Learning content unexpectedly missing: {COUNTS}, expected: {expected}"
    notes = ROOT / "N2CuaTrung/Resources/grammar-details.json"
    details = json.loads(notes.read_text(encoding="utf-8"))
    assert len(details) >= 50, "Extra grammar explanations were removed!"
    print("PASS: ALL N2 CONTENT PRESERVED", COUNTS, "grammar-details:", len(details), flush=True)

if __name__ == "__main__":
    main()
