#!/usr/bin/env python3
"""Validate Sou Matome source pack question structure (not textbook accuracy).

This script never publishes or copies the user's commercial source books.
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

STATUS = {"editorial_reviewed", "source_verified", "independently_verified"}
EXPECTED = ("vocab", "grammar", "kanji", "readings", "listening")


def normalize(text):
    text = unicodedata.normalize("NFKC", text or "")
    return re.sub(r"\s+", " ", text.strip()).casefold()


def validate(pack):
    issues = []
    summary = {}

    for kind in EXPECTED:
        items = pack.get(kind, [])
        if not isinstance(items, list):
            issues.append(f"{kind}: not an array")
            continue
        ids = [item.get("id") for item in items]
        if None in ids or len(ids) != len(set(ids)):
            issues.append(f"{kind}: missing or repeated item IDs")
        summary[kind] = len(items)
        for entry in items:
            item_id = entry.get("id", "<missing>")
            prefix = f"{kind}/{item_id}"
            if kind in ("vocab", "grammar", "kanji"):
                head = entry.get({"vocab": "word", "grammar": "pattern",
                                  "kanji": "char"}[kind], "")
                meaning = entry.get("meaning", "")
                if not head or not meaning:
                    issues.append(f"{prefix}: missing Japanese or Vietnamese meaning")
                if kind == "kanji" and len(head) != 1:
                    issues.append(f"{prefix}: Kanji headword must be one character")
                if kind == "vocab" and not entry.get("reading", "").strip():
                    issues.append(f"{prefix}: missing Japanese reading")
                flag = "grammarStatus" if kind == "grammar" else "meaningStatus"
                if entry.get(flag) in STATUS:
                    if not meaning.strip() or meaning.startswith("EN ·"):
                        issues.append(f"{prefix}: approved entry has invalid Vietnamese meaning")
                    first = entry.get("example", "")
                    second = entry.get("exampleVi", "") if kind == "vocab" else (
                        entry.get("translation", "") if kind == "grammar" else ""
                    )
                    if kind in ("vocab", "grammar") and bool(first) != bool(second):
                        issues.append(f"{prefix}: paired example/translation incomplete")
                continue

            choices = entry.get("choices", [])
            answer = entry.get("answer")
            if not isinstance(choices, list) or len(choices) < 2:
                issues.append(f"{prefix}: missing answer choices")
                continue
            if len({normalize(x) for x in choices}) != len(choices):
                issues.append(f"{prefix}: duplicate answer choices")
            if any(not normalize(x) for x in choices):
                issues.append(f"{prefix}: blank choice")
            if not isinstance(answer, int) or not (0 <= answer < len(choices)):
                issues.append(f"{prefix}: invalid correct-answer index")
            if not entry.get("explanation", "").strip():
                issues.append(f"{prefix}: missing answer explanation")
            if not entry.get("question", "").strip():
                issues.append(f"{prefix}: missing question")
    summary["total"] = sum(summary.values())
    return summary, issues


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
        "content-packs/n2-series-sou-matome.json")
    pack = json.loads(source.read_text(encoding="utf-8"))
    summary, problems = validate(pack)
    print("Sou Matome source pack:", json.dumps(summary, ensure_ascii=False))
    print("Structural / multiple-choice errors:", len(problems))
    for issue in problems[:50]:
        print("ERROR:", issue)
    print("NOTE: Passing structure checks does not verify textbook completeness or translation accuracy.")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
