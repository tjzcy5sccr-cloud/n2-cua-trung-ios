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
import unicodedata
from pathlib import Path

import fitz

JAPANESE = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")
NUMBERED = re.compile(r"^[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳]\s*([\u3400-\u9fff])")
GRAMMAR_DAY = re.compile(r"\bBài\s*\d+\s*[:：]", re.I)
GRAMMAR_PATTERN = re.compile(r"^\s*([A-H])\s*[:：.;；]\s*(.*)", re.I)
POS = re.compile(r"^(?:(?:n|v|s|adj|adv|adi|adn|aux|phr|int)\b[,.]?\s*)+", re.I)


def vocabulary_candidates(page, page_number):
    """Read every Japanese-left-column row, including pages with no POS tags.

    Imported content is a private UNVERIFIED source candidate, not a completed
    flashcard. Splitting wrapped kana, kanji and Vietnamese sense lines is
    inherently imperfect and must be checked on the original PDF.
    """
    spans = [
        (float(s["bbox"][0]), float(s["bbox"][1]), s["text"].strip())
        for block in page.get_text("dict")["blocks"] if "lines" in block
        for line in block["lines"] for s in line["spans"] if s["text"].strip()
    ]
    left = sorted((y, x, t) for x, y, t in spans
                  if 68 <= x < 180 and 68 <= y < 720 and JAPANESE.search(t))
    groups = []
    for y, x, value in left:
        if not groups or y - groups[-1][-1][0] >= 27:
            groups.append([(y, x, value)])
        else:
            groups[-1].append((y, x, value))

    pos_anchors = []
    for x, y, value in sorted(spans, key=lambda s: s[1]):
        if 300 <= x < 445 and 68 <= y < 720 and POS.match(value):
            if not pos_anchors or y - pos_anchors[-1] > 9:
                pos_anchors.append(y)

    available = set(range(len(pos_anchors)))
    assignments = []
    for group in groups:
        y = group[0][0]
        near = [i for i in available if abs(pos_anchors[i] - y) <= 33]
        if near:
            index = min(near, key=lambda i: abs(pos_anchors[i] - y))
            available.remove(index)
            assignments.append(index)
        else:
            assignments.append(None)

    def join_parts(parts):
        return "".join(v for _, _, v in sorted(parts)).strip()

    results = []
    for i, group in enumerate(groups):
        reading_start = group[0][0]
        next_start = groups[i + 1][0][0] if i + 1 < len(groups) else 725
        reading = join_parts([
            (y, x, t) for x, y, t in spans
            if reading_start - 6 <= y < next_start - 12
            and 68 <= x < 180 and JAPANESE.search(t)
        ])
        index = assignments[i]
        if index is not None:
            anchor = pos_anchors[index]
            first = ((pos_anchors[index - 1] + anchor) / 2 if index > 0
                     else max(65, reading_start - 25))
            last = ((anchor + pos_anchors[index + 1]) / 2
                    if index + 1 < len(pos_anchors) else next_start - 12)
            last = min(last, next_start - 8)
        else:
            first, last = reading_start - 20, next_start - 12

        row = [(x, y, t) for x, y, t in spans if first <= y < last]
        written = join_parts([
            (y, x, t) for x, y, t in row
            if 180 <= x < 380 and JAPANESE.search(t)
        ])
        fragments = []
        for x, y, value in row:
            if x < 300 or JAPANESE.search(value):
                continue
            meaning = POS.sub("", value).strip()
            if meaning and not re.search(
                r"(?i)Somatome|Page\s*\d+|Cà Fe Muối", meaning
            ):
                fragments.append((y, x, meaning))
        meaning = " ".join(text for _, _, text in sorted(fragments)).strip()
        head = written if JAPANESE.search(written) else reading
        if not JAPANESE.search(head):
            continue

        issues = []
        if not re.search(r"[\u3040-\u30ff]", reading):
            issues.append("MISSING_KANA_READING")
        if not meaning:
            issues.append("MISSING_VIETNAMESE_GLOSS")
        if JAPANESE.search(meaning):
            issues.append("POSSIBLY_JAPANESE_IN_GLOSS")
        if len(head) > 120 or len(reading) > 140 or len(meaning) > 225:
            issues.append("POSSIBLY_MERGED_ROWS")
        results.append({
            "id": f"goi-vi:{page_number}:{len(results)}",
            "bookId": "goi-vi", "page": page_number, "skill": "Từ vựng",
            "heading": head[:200], "reading": reading[:150],
            "detail": meaning[:250], "qaFlags": issues
        })
    return results


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
    """Find individual A:/B:/C: grammatical forms without claiming correctness.

    Furigana and columns can break a single Japanese pattern across lines.
    Such candidates are flagged; users must compare with their personal PDF.
    """
    lines = page.get_text("text").splitlines()
    found = []
    for index, line in enumerate(lines):
        match = GRAMMAR_PATTERN.match(line.strip())
        if not match:
            continue
        heading = match.group(2).strip()
        if not JAPANESE.search(heading):
            continue
        meaning = ""
        for following in lines[index + 1:index + 9]:
            compact = following.strip()
            if GRAMMAR_PATTERN.match(compact) or GRAMMAR_DAY.search(compact):
                break
            if re.search(r"Ý\s*nghĩa\s*[:：]", compact, re.I):
                meaning = re.split(
                    r"Ý\s*nghĩa\s*[:：]", compact, maxsplit=1, flags=re.I
                )[-1].strip()
                break
        needs_manual = len(heading.strip(" 。.、")) < 3 or not bool(meaning)
        found.append({
            "id": f"bunpou-vi:{page_number}:{len(found)}",
            "bookId": "bunpou-vi", "page": page_number,
            "skill": "Ngữ pháp", "heading": heading,
            "reading": "", "detail": meaning,
            "qaFlags": ["CHECK_FURIGANA_AND_LINE_BREAKS"] if needs_manual else []
        })
    return found


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
            source_text = "".join(
                char for char in unicodedata.normalize(
                    "NFKC", page.get_text("text")) if not char.isspace()
            )
            for candidate in records:
                title = "".join(
                    char for char in unicodedata.normalize(
                        "NFKC", candidate["heading"]) if not char.isspace()
                )
                reading = "".join(
                    char for char in unicodedata.normalize(
                        "NFKC", candidate.get("reading", "")) if not char.isspace()
                )
                flags = candidate.setdefault("qaFlags", [])
                if title and title not in source_text:
                    flags.append("HEADING_NOT_CONTIGUOUS_ON_SOURCE_PAGE")
                if book == "goi-vi" and reading and reading not in source_text:
                    flags.append("READING_NOT_CONTIGUOUS_ON_SOURCE_PAGE")
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
