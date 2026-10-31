#!/usr/bin/env python3
"""Build local-only, UNVERIFIED flashcard candidates from owner's 3 source PDFs.

Requires PyMuPDF (pip install pymupdf). Source words and translations are
NEVER committed to GitHub. --private-out writes only to your personal device.
Candidates must be source/translation verified before study pack inclusion.
"""
import argparse
import collections
import json
import re
from pathlib import Path

import fitz

JAPANESE = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")
NUMBERED = re.compile(r"^[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳]\s*([\u3400-\u9fff])")
GRAMMAR_DAY = re.compile(r"\bBài\s*\d+\s*[:：]", re.I)
POS = re.compile(r"^(?:(?:n|v|s|adj|adv|adi|adn|aux|phr|int)\b[,.]?\s*)+", re.I)


def vocabulary_candidates(page, page_number):
    blocks = sorted((b for b in page.get_text("blocks")
                     if 70 < b[1] < 715), key=lambda b: b[1])
    starts = []
    for block in blocks:
        if block[0] < 115 and JAPANESE.search(block[4]):
            if not starts or block[1] - starts[-1] > 25:
                starts.append(block[1])
    words = page.get_text("words")
    result = []
    for idx, top in enumerate(starts):
        bottom = starts[idx + 1] if idx + 1 < len(starts) else 720
        row = [w for w in words if top - 6 <= (w[1] + w[3]) / 2 < bottom - 6]
        reading_part = "".join(w[4] for w in row if w[0] < 190)
        head_part = "".join(w[4] for w in row if 190 <= w[0] < 362)
        text_part = " ".join(w[4] for w in row if w[0] >= 376).strip()
        head = head_part if JAPANESE.search(head_part) else reading_part
        if not JAPANESE.search(head):
            continue
        result.append({
            "id": f"goi-vi:{page_number}:{len(result)}",
            "bookId": "goi-vi", "page": page_number, "skill": "Từ vựng",
            "heading": head, "reading": reading_part if head_part else "",
            "detail": POS.sub("", text_part).strip()
        })
    return result


def kanji_candidates(page, page_number):
    result = []
    for block in page.get_text("blocks"):
        match = NUMBERED.match(" ".join(block[4].split()))
        if match:
            result.append({
                "id": f"kanji-vi:{page_number}:{len(result)}",
                "bookId": "kanji-vi", "page": page_number, "skill": "Kanji",
                "heading": match.group(1), "reading": "", "detail": ""
            })
    return result


def grammar_candidates(page, page_number):
    # A lesson heading is NOT a verified grammar pattern. Leave blank rather
    # than mislabel an example as an N2 grammar rule.
    lessons = sum(len(GRAMMAR_DAY.findall(" ".join(b[4].split())))
                  for b in page.get_text("blocks"))
    return [{
        "id": f"bunpou-vi:{page_number}:{i}",
        "bookId": "bunpou-vi", "page": page_number,
        "skill": "Ngữ pháp", "heading": "", "reading": "", "detail": ""
    } for i in range(lessons)]


def extract(sources):
    all_cards, missing = [], {}
    for book, path in sources.items():
        doc = fitz.open(path)
        unseen = []
        for page_no, page in enumerate(doc, 1):
            records = {
                "goi-vi": vocabulary_candidates,
                "kanji-vi": kanji_candidates,
                "bunpou-vi": grammar_candidates
            }[book](page, page_no)
            if not records:
                unseen.append(page_no)
            all_cards.extend(records)
        missing[book] = unseen
    counts = collections.Counter(x["bookId"] for x in all_cards)
    report = {
        "status": "UNVERIFIED_CANDIDATES_ONLY",
        "candidateCounts": dict(counts),
        "noRecognizedCandidatePages": missing,
        "approvedCards": 0,
        "accuracyNote": ("Page geometry helps recover missing rows but does not "
                         "prove Japanese readings or Vietnamese definitions.")
    }
    return all_cards, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vocabulary", type=Path, required=True)
    parser.add_argument("--kanji", type=Path, required=True)
    parser.add_argument("--grammar", type=Path, required=True)
    parser.add_argument("--private-out", type=Path,
                        help="Personal local candidate JSON; never commit this file.")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    records, report = extract({
        "goi-vi": args.vocabulary,
        "kanji-vi": args.kanji,
        "bunpou-vi": args.grammar
    })
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if args.private_out:
        args.private_out.parent.mkdir(parents=True, exist_ok=True)
        args.private_out.write_text(json.dumps(records, ensure_ascii=False, indent=2),
                                    encoding="utf-8")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2),
                               encoding="utf-8")


if __name__ == "__main__":
    main()
