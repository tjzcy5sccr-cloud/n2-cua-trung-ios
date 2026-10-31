#!/usr/bin/env python3
"""Audit privately reviewed Sou Matome study cards without uploading textbook text.

The script accepts a user-owned exported pack (or test fixture) and optionally
checks each source page against PDFs stored on the user's own computer.
It writes only counts, card IDs, page numbers and issue codes into its report.
The presence of a word on a PDF page does NOT certify translation correctness.
"""
import argparse
import collections
import json
import re
import sys
import unicodedata
from pathlib import Path

BOOKS = {
    "kanji": 177, "goi": 156, "bunpou": 156, "dokkai": 121,
    "choukai": 73, "kanji-vi": 208, "goi-vi": 163,
    "bunpou-vi": 185,
}
STATUS = {"editorial_reviewed", "source_verified", "independently_verified"}
JP = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")
KANA = re.compile(r"[\u3040-\u30ff]")
LOCATOR = re.compile(r"^private-book:([a-z-]+):page-(\d+)$")
FIELDS = ("vocab", "grammar", "kanji", "readings", "listening")


def normalize(value):
    return re.sub(r"\s+", "", unicodedata.normalize("NFKC", value or "")).casefold()


def inspect_pack(pack, source_directory=None):
    issues = []
    stats = collections.Counter()
    pairs = collections.defaultdict(set)
    indexed_pages = set()
    source_pages = {}
    source_documents = {}

    def add(group, card_id, code, page=None):
        issues.append({"group": group, "id": card_id, "code": code,
                       **({"page": page} if page is not None else {})})

    if source_directory is not None:
        try:
            import fitz
        except ImportError as e:
            raise SystemExit("PDF source validation needs PyMuPDF: pip install pymupdf") from e
        for book_id in BOOKS:
            candidate = source_directory / (book_id + ".pdf")
            if candidate.exists():
                doc = fitz.open(candidate)
                source_documents[book_id] = doc

    for group in FIELDS:
        entries = pack.get(group, [])
        if not isinstance(entries, list):
            raise ValueError("Expected list for " + group)
        stats["all_" + group] = len(entries)
        ids = set()
        for idx, entry in enumerate(entries):
            card_id = entry.get("id", f"missing-id-{idx}")
            if card_id in ids:
                add(group, card_id, "duplicate_id")
            ids.add(card_id)
            if group in ("readings", "listening"):
                choices = entry.get("choices", [])
                answer = entry.get("answer")
                if not isinstance(choices, list) or len(choices) < 2 or len(
                    set(map(normalize, choices))) != len(choices):
                    add(group, card_id, "invalid_or_duplicate_choices")
                if not isinstance(answer, int) or not 0 <= answer < len(choices):
                    add(group, card_id, "invalid_answer")
                if not entry.get("explanation", "").strip():
                    add(group, card_id, "missing_answer_explanation")
                continue

            flag = "grammarStatus" if group == "grammar" else "meaningStatus"
            if entry.get(flag) not in STATUS:
                add(group, card_id, "not_editorially_approved")
                continue
            stats["approved_" + group] += 1
            word = entry.get({"vocab":"word","grammar":"pattern","kanji":"char"}[group], "")
            meaning = entry.get("meaning", "")
            if not JP.search(word):
                add(group, card_id, "missing_japanese_text")
            if not meaning.strip() or normalize(meaning) == normalize(word) or meaning.startswith("EN ·"):
                add(group, card_id, "unusable_vietnamese_gloss")
            pairs[group].add(normalize(meaning))
            if group == "vocab":
                if not KANA.search(entry.get("reading", "")):
                    add(group, card_id, "missing_kana_reading")
                if bool(entry.get("example")) != bool(entry.get("exampleVi")):
                    add(group, card_id, "unpaired_example")
                if entry.get("exampleStatus") in STATUS and (
                        not entry.get("example") or not entry.get("exampleVi")):
                    add(group, card_id, "approved_example_missing_side")
            if group == "grammar":
                if bool(entry.get("example")) != bool(entry.get("translation")):
                    add(group, card_id, "unpaired_example")
            if group == "kanji" and len(word.strip()) != 1:
                add(group, card_id, "kanji_must_be_single_character")

            source_tag = entry.get("meaningSource") if group == "vocab" else None
            if source_tag and source_tag.startswith("private-book:"):
                match = LOCATOR.match(source_tag)
                if not match:
                    add(group, card_id, "invalid_source_locator")
                    continue
                book_id, page_str = match.groups()
                page = int(page_str)
                if book_id not in BOOKS or not 1 <= page <= BOOKS[book_id]:
                    add(group, card_id, "source_page_out_of_range", page)
                    continue
                indexed_pages.add((book_id, page))
                if source_directory is not None:
                    doc = source_documents.get(book_id)
                    if doc is None:
                        add(group, card_id, "source_pdf_missing", page)
                        continue
                    key = (book_id, page)
                    if key not in source_pages:
                        source_pages[key] = normalize(doc[page - 1].get_text("text"))
                    if not normalize(word) in source_pages[key]:
                        add(group, card_id, "japanese_text_not_found_on_source_page", page)
            elif card_id.startswith("sm-reviewed-"):
                add(group, card_id, "missing_private_page_pointer")

    for group in ("vocab", "grammar", "kanji"):
        if stats["approved_" + group] and len(pairs[group]) < 4:
            issues.append({"group":group,"id":"*","code":"quiz_needs_four_unique_meanings"})

    counts = dict(sorted(stats.items()))
    summary = collections.Counter(x["code"] for x in issues)
    return {
        "schemaVersion": 1,
        "sourceScope": "private_user_owned_local_study",
        "counts": counts,
        "sourcePagesReferenced": len(indexed_pages),
        "sourceDocumentsPresent": sorted(source_documents),
        "issueCounts": dict(sorted(summary.items())),
        "issues": issues,
        "complete": False,
        "accuracyNote": (
            "Automatic checks do not prove Japanese/Vietnamese translation correctness. "
            "Verified book/translation review, complete reading/listening mapping and "
            "human source comparison are still required for a 100% claim."
        )
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, required=True)
    parser.add_argument("--pdf-dir", type=Path,
                        help="Optional personal directory with book-id.pdf files")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--fail-on-issues", action="store_true")
    args = parser.parse_args()
    pack = json.loads(args.pack.read_text(encoding="utf-8"))
    report = inspect_pack(pack, args.pdf_dir)
    message = json.dumps({k:report[k] for k in (
        "counts", "sourcePagesReferenced", "issueCounts", "complete"
    )}, ensure_ascii=False, indent=2)
    print(message)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                               encoding="utf-8")
    if args.fail_on_issues and report["issues"]:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
