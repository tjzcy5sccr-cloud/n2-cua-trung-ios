#!/usr/bin/env python3
"""Book-only audit of privately owned Sou Matome PDF and candidate JSON.

No outside dictionary, website, or model-generated corrections are consulted.
Only aggregate metadata and record IDs are written. The source PDF and words
remain on the owner's device, not in the repository.
"""
import argparse
import collections
import json
import unicodedata
from pathlib import Path

import fitz

KNOWN = {
    "goi-vi": 163,
    "kanji-vi": 208,
    "bunpou-vi": 185,
}


def compact(value):
    return "".join(
        character for character in unicodedata.normalize("NFKC", value or "")
        if not character.isspace()
    )


def check_source_records(records, pdf_by_book):
    issues = []
    summary = {}
    for book_id, expected_pages in KNOWN.items():
        doc = pdf_by_book[book_id]
        if len(doc) != expected_pages:
            raise ValueError(
                f"Expected {expected_pages} pages for {book_id}; got {len(doc)}"
            )
        items = [x for x in records if x.get("bookId") == book_id]
        page_cache = {}
        stats = collections.Counter()
        for item in items:
            page = item.get("page")
            record_id = item.get("id")
            if not isinstance(page, int) or not 1 <= page <= expected_pages:
                raise ValueError(f"Invalid private page locator: {record_id}")
            if not isinstance(record_id, str) or not record_id.startswith(
                f"{book_id}:{page}:"
            ):
                raise ValueError(f"Invalid private candidate ID: {record_id}")
            text = page_cache.setdefault(
                page, compact(doc[page - 1].get_text("text"))
            )
            heading = compact(item.get("heading", ""))
            reasons = []
            if not heading or heading not in text:
                reasons.append("HEADING_NOT_CONTIGUOUS_IN_SOURCE_PDF")
            if not item.get("detail", "").strip():
                reasons.append("MEANING_NOT_CAPTURED_FROM_SOURCE_PDF")
            if book_id == "goi-vi":
                reading = compact(item.get("reading", ""))
                if reading and reading not in text:
                    reasons.append("READING_NOT_CONTIGUOUS_IN_SOURCE_PDF")
            if book_id == "kanji-vi":
                han = compact(item.get("sourceHanViet", ""))
                if han and han not in text:
                    reasons.append("HAN_VIET_LABEL_NEEDS_PAGE_REVIEW")
            for reason in reasons:
                stats[reason] += 1
                issues.append({
                    "id": record_id,
                    "bookId": book_id,
                    "page": page,
                    "reason": reason,
                })
        summary[book_id] = {
            "pages": expected_pages,
            "candidateCount": len(items),
            "diagnosticCounts": dict(stats),
        }
    return {
        "sourceOfTruth": "USER_IMPORTED_SOU_MATOME_PDFS_ONLY",
        "externalSourcesUsed": False,
        "verifiedTranslationCount": 0,
        "status": "SOURCE_TEXT_MATCH_ONLY_NOT_TRANSLATION_VERIFIED",
        "byBook": summary,
        "recordsNeedingReview": issues,
        "note": (
            "Text-layer exact match may fail on split ruby/furigana. "
            "Do not automatically change the Japanese or the Vietnamese meaning."
        ),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--vocabulary", type=Path, required=True)
    parser.add_argument("--kanji", type=Path, required=True)
    parser.add_argument("--grammar", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    records = json.loads(args.candidates.read_text(encoding="utf-8"))
    if len({row["id"] for row in records}) != len(records):
        raise SystemExit("Duplicate candidate identifiers.")
    documents = {
        "goi-vi": fitz.open(args.vocabulary),
        "kanji-vi": fitz.open(args.kanji),
        "bunpou-vi": fitz.open(args.grammar),
    }
    report = check_source_records(records, documents)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for book, stats in report["byBook"].items():
        print(book, stats["candidateCount"], stats["diagnosticCounts"])
    print("No external sources were read; no approvals were issued.")


if __name__ == "__main__":
    main()
