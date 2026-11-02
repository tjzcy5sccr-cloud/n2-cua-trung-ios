#!/usr/bin/env python3
"""Regression: independent N2 lessons refresh in Sou Matome without claiming book review."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def read(path):
    return (root / path).read_text(encoding="utf-8")

pack = json.loads(read("content-packs/n2-series-sou-matome.json"))
manifest = json.loads(read("content-packs/manifest-sou-matome.json"))
src = read("N2CuaTrung/Sources/ContentUpdates.swift")
store = read("N2CuaTrung/Sources/StudyStore.swift")
ui = read("N2CuaTrung/Sources/ContentUpdatesView.swift")
whole = read("N2CuaTrung/Sources/SouMatomeWholeBooksView.swift")
coverage = json.loads(read("qa-reports/sou-matome-2963-private-candidate-coverage.json"))

assert pack["seriesId"] == "sou-matome"
assert pack["id"] == "n2-series-sou-matome"
assert manifest["schemaVersion"] == 1
assert len(manifest["packs"]) == 1
assert manifest["packs"][0]["id"] == pack["id"]
assert manifest["packs"][0]["version"] == pack["version"]
assert manifest["packs"][0]["url"].endswith("/content-packs/n2-series-sou-matome.json")

approved = {"editorial_reviewed", "source_verified", "independently_verified"}
available = {
    "vocab": sum(x.get("meaningStatus") in approved for x in pack["vocab"]),
    "kanji": sum(x.get("meaningStatus") in approved for x in pack["kanji"]),
    "grammar": sum(x.get("grammarStatus") in approved for x in pack["grammar"]),
    "readings": len(pack["readings"]),
    "listening": len(pack["listening"]),
}
assert sum(available.values()) > 0, "The OTA pack must have study-visible items"
assert "includeIndependentSouMatomePractice" in src
assert '"n2-series-sou-matome"' in src
assert "let selected = bookOnlyEligiblePacks(packs)" in src
assert '.filter { $0.isApprovedForStudy }' in src
assert "includeIndependentSouMatomePractice: includeIndependentSouMatomePractice" in src
assert "private let independentPracticeKey" in store
assert "func setIndependentSouMatomePractice" in store
assert "UserDefaults.standard.set(enabled, forKey: independentPracticeKey)" in store
assert 'Toggle("Hiện bài luyện N2 độc lập"' in ui
assert "SouMatomeSourceEntriesView()" in ui
assert "Tìm" in whole and "Gói luyện N2 cũ chưa gắn trang sách" in whole

# The user's textbook-derived 2,963 draft records remain private and must not
# be included in the public lesson pack or called verified translations.
assert coverage["sourceCandidateRows"]["total"] == 2963
assert coverage["reviewedAndApproved"] == 0
assert "bookOnlyEligiblePacks" in src
print("PASS: OTA-visible independent N2 content", available, "count", sum(available.values()))
print("PASS: Book PDF reviews remain isolated; 2,963 private candidates not auto-approved")
