#!/usr/bin/env python3
"""Generate approved-only iOS resources on the GitHub runner.

The complete originals remain in GitHub source and translation QA artifacts.
This modifies runner WORKTREE just before XcodeGen and never commits it.
Never embed unapproved dictionary candidates or machine-translated examples in IPA.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    ROOT / "N2CuaTrung/Resources/content.json",
    ROOT / "content-packs/n2-expansion-01.json",
    ROOT / "content-packs/openjlpt-n2-core.json",
    ROOT / "content-packs/vn26-original-practice-01.json",
    ROOT / "content-packs/n2-reading-listening-02.json",
]
APPROVED = {"editorial_reviewed", "source_verified", "independently_verified"}

def clean_pack(pack):
    result = dict(pack)
    before = {k: len(pack.get(k, [])) for k in ("vocab", "grammar", "kanji")}
    vocab = []
    approved_words = {}
    for raw in pack.get("vocab", []):
        if raw.get("meaningStatus") not in APPROVED:
            continue
        entry = dict(raw)
        if entry.get("exampleStatus") not in APPROVED:
            entry["example"] = ""
            entry["exampleVi"] = ""
            for key in list(entry):
                if key.startswith("exampleTranslation") or key.startswith("exampleSense"):
                    entry.pop(key, None)
        # Keep the approval status for runtime protection and widget filtering.
        vocab.append(entry)
        approved_words[entry["word"]] = entry
    result["vocab"] = vocab
    grammar = []
    for raw in pack.get("grammar", []):
        if raw.get("grammarStatus") not in APPROVED:
            continue
        entry = dict(raw)
        if entry.get("translationStatus") not in APPROVED:
            entry["example"] = ""
            entry["translation"] = ""
        entry["samples"] = [
            sample for sample in entry.get("samples", []) or []
            if sample.get("translationStatus") in APPROVED
        ]
        grammar.append(entry)
    result["grammar"] = grammar
    kanji = []
    for raw in pack.get("kanji", []):
        if raw.get("meaningStatus") not in APPROVED:
            continue
        entry = dict(raw)
        # A listed compound may itself have no reviewed Vietnamese definition.
        candidates = [
            x.split("（", 1)[0].strip()
            for x in entry.get("word", "").replace("，", "、").replace(",", "、").split("、")
        ]
        entry["word"] = "、".join(x for x in candidates if x in approved_words)
        kanji.append(entry)
    result["kanji"] = kanji
    after = {k: len(result.get(k, [])) for k in ("vocab", "grammar", "kanji")}
    return result, before, after

def main():
    for path in FILES:
        obj = json.loads(path.read_text(encoding="utf-8"))
        cleaned, before, after = clean_pack(obj)
        path.write_text(json.dumps(cleaned, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
        print(path.relative_to(ROOT), "source:", before, "published:", after, flush=True)
        for v in cleaned["vocab"]:
            assert v.get("meaningStatus") in APPROVED
            if v.get("exampleStatus") not in APPROVED:
                assert not v["example"] and not v.get("exampleVi")
        assert all(k.get("meaningStatus") in APPROVED for k in cleaned["kanji"])
        assert all(g.get("grammarStatus") in APPROVED for g in cleaned["grammar"])
    # Extra grammar text supplied without review status must remain on GitHub only.
    details = ROOT / "N2CuaTrung/Resources/grammar-details.json"
    details.write_text("{}\n", encoding="utf-8")
    print("PASS: all bundled learning resources contain approved-only word, Kanji and grammar meanings.")

if __name__ == "__main__":
    main()
