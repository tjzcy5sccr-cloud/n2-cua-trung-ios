#!/usr/bin/env python3
"""Produce approved-only iOS resources in CI, without altering the GitHub source.

The original learning records and untranslated candidates remain in the GitHub
repository. A build runner is disposable; bundle files are trimmed only after
full-source QA is complete. Source-count regressions are caught before filtering.
"""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/"content-packs"
PATHS=[
 ROOT/"N2CuaTrung/Resources/content.json",
 *[BASE/(n+".json") for n in (
     "n2-expansion-01","openjlpt-n2-core","vn26-original-practice-01",
     "n2-reading-listening-02","n2-series-mimikara","n2-series-shin-kanzen",
     "n2-series-sou-matome","n2-series-speed-master")],
]
APPROVED={"editorial_reviewed","source_verified","independently_verified"}
SOURCE_EXPECTED={"vocab":2002,"grammar":180,"kanji":471,"readings":74,"listening":70}
STUDY_TYPES=("vocab","grammar","kanji")
ALL_TYPES=(*STUDY_TYPES,"readings","listening")

def approved_item(kind,item):
    flag="grammarStatus" if kind=="grammar" else "meaningStatus"
    value=item.get("meaning") or ""
    return (item.get(flag) in APPROVED and value.strip() and not value.startswith("EN ·"))

def clean_json(pack):
    clean=dict(pack)
    reviewed_words={v["word"] for v in pack.get("vocab",[]) if approved_item("vocab",v)}
    for kind in STUDY_TYPES:
        keep=[]
        for raw in pack.get(kind,[]):
            if not approved_item(kind,raw):continue
            entry=dict(raw)
            if kind=="vocab" and entry.get("exampleStatus") not in APPROVED:
                entry["example"]=""
                entry["exampleVi"]=""
            elif kind=="grammar":
                if entry.get("translationStatus") not in APPROVED:
                    entry["example"]=""
                    entry["translation"]=""
                entry["samples"]=[
                    sample for sample in entry.get("samples",[]) or []
                    if sample.get("translationStatus") in APPROVED
                    and sample.get("text") and sample.get("translation")]
            elif kind=="kanji":
                # Compounds must have independently approved Vietnamese definitions.
                words=[s.strip().split("（",1)[0] for s in entry.get("word","").replace("，","、").replace(",","、").split("、")]
                entry["word"]="、".join(w for w in words if w in reviewed_words)
            keep.append(entry)
        clean[kind]=keep
    return clean

def main():
    originals={path:json.loads(path.read_text(encoding="utf-8")) for path in PATHS}
    counts={kind:sum(len(pack.get(kind,[])) for path,pack in originals.items() if "n2-series-" not in path.name) for kind in ALL_TYPES}
    assert counts==SOURCE_EXPECTED, f"GitHub source lost items before packaging: {counts}"
    report={"sourceCountsBeforeFiltering":counts,"packedSources":{},"policy":"Only explicit reviewed items and examples are shipped; full source stays in GitHub."}
    for path,pack in originals.items():
        clean=clean_json(pack)
        for kind in STUDY_TYPES:
            assert all(approved_item(kind,item) for item in clean[kind])
        if "n2-series-" in path.name:
            orig_ids=[x["id"] for kind in STUDY_TYPES for x in pack.get(kind,[]) if x["id"].startswith("trung-original-")]
            clean_ids={x["id"] for kind in STUDY_TYPES for x in clean[kind]}
            assert all(x in clean_ids for x in orig_ids), ("Original reviewed lessons disappeared",path)
        path.write_text(json.dumps(clean,ensure_ascii=False,separators=(",",":"))+"\n",encoding="utf-8")
        report["packedSources"][path.name]={
            "source":{k:len(pack.get(k,[])) for k in ALL_TYPES},
            "visible":{k:len(clean.get(k,[])) for k in ALL_TYPES}}
    # Older supplemental grammar examples lack per-entry review metadata.
    # Keep them in GitHub source, not in new unsigned IPA bundles.
    details=ROOT/"N2CuaTrung/Resources/grammar-details.json"
    details.write_text("{}\n",encoding="utf-8")
    output=ROOT/"qa-reports/ipa-approved-only-coverage.json"
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("PASS: source data intact in GitHub and only reviewed entries prepared for iOS.")
    print(json.dumps(report["packedSources"],ensure_ascii=False,indent=2),flush=True)

if __name__=="__main__":
    main()
