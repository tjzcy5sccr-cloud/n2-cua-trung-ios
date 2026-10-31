#!/usr/bin/env python3
"""Validate four real, isolated iOS selectable packs without inventing book contents."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT/"N2CuaTrung/Resources/content.json").read_text(encoding="utf-8"))
names=["mimikara","shin-kanzen","sou-matome","speed-master"]
groups=("vocab","grammar","kanji","readings","listening")
allpacks=[]
for key in names:
    path=ROOT/f"content-packs/n2-series-{key}.json"
    pack=json.loads(path.read_text(encoding="utf-8"))
    assert pack["id"]==f"n2-series-{key}",pack["id"]
    assert pack["seriesId"]==key
    assert pack["version"]>=1
    assert all(pack.get(kind) for kind in groups),(key, "Missing type")
    for kind in groups:
        ids=[x["id"] for x in pack[kind]]
        assert len(ids)==len(set(ids)),(key,kind,"duplicates")
        if kind in ("vocab","grammar"):
            assert all(1<=x["week"]<=35 for x in pack[kind])
        if kind in ("readings","listening"):
            assert all(len(x["choices"])>=2 and 0<=x["answer"]<len(x["choices"]) for x in pack[kind])
    allpacks.append(pack)

for kind in groups:
    base={v["id"]:v for v in source[kind]}
    combined=[v for pack in allpacks for v in pack[kind]]
    by_id={v["id"]:v for v in combined}
    assert len(combined)==len(by_id),(kind,"duplicate IDs across series")
    assert set(base).issubset(by_id),(kind,"missing original data")
    assert all(base[key]==by_id[key] for key in base),(kind,"seed data mutated")
    new_items=[v for v in combined if v["id"] not in base]
    if kind in ("vocab","grammar","kanji"):
        flag={"vocab":"meaningStatus","grammar":"grammarStatus","kanji":"meaningStatus"}[kind]
        assert all(v.get(flag) in {"editorial_reviewed","source_verified","independently_verified"}
                   for v in new_items),(kind,"unreviewed new item leaked into app")
    print(kind+":",len(base),"source items retained +",len(new_items),"approved additions")

manifest=json.loads((ROOT/"content-packs/manifest-series.json").read_text(encoding="utf-8"))
assert manifest["schemaVersion"]==1
assert len(manifest["packs"])==4
assert {x["id"] for x in manifest["packs"]}=={x["id"] for x in allpacks}
assert all("feature/n2-four-series-roadmap-2027/content-packs/" in x["url"] for x in manifest["packs"])
source_code=(ROOT/"N2CuaTrung/Sources/ContentUpdates.swift").read_text(encoding="utf-8")
study=(ROOT/"N2CuaTrung/Sources/StudyStore.swift").read_text(encoding="utf-8")
ui=(ROOT/"N2CuaTrung/Sources/LearningSeriesPickerView.swift").read_text(encoding="utf-8")
updates=(ROOT/"N2CuaTrung/Sources/ContentUpdatesView.swift").read_text(encoding="utf-8")
project=(ROOT/"project.yml").read_text(encoding="utf-8")
assert 'let selected = packs.filter { $0.seriesId == series.rawValue }' in source_code
assert 'if series == .all { return mergedCourse(packs: packs) }' in source_code
assert 'LearningSeries.allCases.compactMap(\\.packFilename)' in source_code
assert 'self.course = CoursePackManager.course(for: series, packs: packs)' in study
assert 'contentRevision = UUID()' in study and 'contentRevision = UUID()' in source_code
assert 'UserDefaults.standard.set(series.rawValue' in study
assert 'ForEach(LearningSeries.allCases)' in ui
assert 'Picker("Chọn bộ"' in updates
assert 'manifest-series.json' in source_code
assert all(f"content-packs/n2-series-{key}.json" in project for key in names)
# Verify this branch's reviewed-content gate and new independently authored batch.
models=(ROOT/"N2CuaTrung/Sources/Models.swift").read_text(encoding="utf-8")
assert "approvedStatuses.contains(meaningStatus" in models
assert "approvedStatuses.contains(exampleStatus" in models
assert 'contains(grammarStatus ?? "")' in models
assert 'contains(translationStatus ?? "")' in models
assert "contains(meaningStatus ?? \"\")" in models
assert source_code.count(".filter { $0.isApprovedForStudy }") >= 6
batch_ids=set()
for pack in allpacks:
    for section in ("vocab","grammar","kanji"):
        for entry in pack[section]:
            if entry["id"].startswith("trung-original-"):
                batch_ids.add(entry["id"])
                flag="grammarStatus" if section=="grammar" else "meaningStatus"
                assert entry[flag] == "editorial_reviewed"
                if section=="vocab":
                    assert entry["exampleStatus"] == "editorial_reviewed"
                    assert entry["example"] and entry["exampleVi"] and entry["reading"]
                if section=="grammar":
                    assert entry["translationStatus"] == "editorial_reviewed"
                    assert entry["example"] and entry["translation"] and entry["rule"]
assert len(batch_ids)==74,("Original batch items missing or duplicated",len(batch_ids))
print("PASS: 74 newly authored review-tagged examples and strict approved-only app filters.")
print("PASS: 4 separate packs, original content intact, isolated selection and auto-reload.")
print("NOTE: study series labels are learning approaches, NOT official book content.")
