#!/usr/bin/env python3
"""Read ONLY an owner's local Kanji supplement and export private metadata.

No PDF excerpts or audio are stored in this public repository. This extracts
the *short* labels and on/kun reading lines from the 208-page supplement.
Hán-Việt is not contextual Vietnamese meaning. All output is UNAPPROVED.
"""
import argparse
import collections
import json
import re
from pathlib import Path

import fitz

HEAD = re.compile(r"^\s*[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳]\s*([\u3400-\u9fff])")
KANA = re.compile(r"[\u3040-\u30ff]")
JP = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")


def han_viet_label(value):
    value = value.strip()
    return bool(value) and not JP.search(value) and len(value) <= 38 and (
        any(c.isalpha() for c in value) and value == value.upper()
    )


def parse_source(page, number):
    """Yield numbered headings with source reading and Han-Viet labels."""
    lines = [v.strip() for v in page.get_text("text").splitlines() if v.strip()]
    indices = [index for index, value in enumerate(lines) if HEAD.match(value)]
    found = []
    for ordinal, at in enumerate(indices):
        kanji = HEAD.match(lines[at]).group(1)
        ending = indices[ordinal + 1] if ordinal + 1 < len(indices) else len(lines)
        context = lines[at + 1:min(at + 8, ending)]
        han, reads = [], []
        for value in context:
            if han_viet_label(value):
                han.append(value)
            elif KANA.search(value):
                offset = KANA.search(value).start()
                reading = re.sub(r"[^\u3040-\u30ffー／・（）(),，/\s]",
                                 "", value[offset:]).strip().replace("/", "／")
                if reading:
                    reads.append(reading)
            elif han or reads:
                break
            if reads:
                break

        if not han:
            for value in context[:3]:
                match = KANA.search(value)
                if match:
                    left = value[:match.start()].strip()
                    if han_viet_label(left):
                        han.append(left)
                    if not reads:
                        reading = re.sub(r"[^\u3040-\u30ffー／・（）(),，/\s]",
                                         "", value[match.start():]).strip().replace("/", "／")
                        if reading:
                            reads.append(reading)
                    break

        # A PDF often puts a long on/kun list on two consecutive lines.
        # Combine only kana-only continuations; never guess missing characters.
        reassembled = False
        if reads and reads[0].endswith(("／", "・")):
            for at_line, value in enumerate(context):
                if not KANA.search(value):
                    continue
                if value in context[:at_line] and at_line == 0:
                    continue
                # The first kana line is the reading itself, so continue after it.
                for suffix in context[at_line + 1:]:
                    suffix = suffix.strip()
                    if not re.fullmatch(r"[\u3040-\u30ffー／・]+", suffix):
                        break
                    reads[0] += suffix
                    reassembled = True
                    if not reads[0].endswith(("／", "・")):
                        break
                break

        found.append({
            "_reading_reassembled": reassembled,
            "id": f"kanji-vi:{number}:{ordinal}",
            "bookId": "kanji-vi",
            "page": number,
            "skill": "Kanji",
            "heading": kanji,
            "reading": "",
            "detail": "",
            "sourceHanViet": " ".join(han),
            "sourceOnKun": " ".join(reads)
        })
    return found


def extract(pdf):
    all_rows = []
    for page_index, page in enumerate(pdf, 1):
        rows = parse_source(page, page_index)
        # The last character's reading can continue after next-page header.
        if rows and page_index < len(pdf) and rows[-1]["sourceOnKun"].endswith(("／", "・")):
            next_lines = [x.strip() for x in pdf[page_index].get_text("text").splitlines()
                          if x.strip()]
            for line in next_lines[:8]:
                if re.fullmatch(r"[\u3040-\u30ffー／・]+", line):
                    rows[-1]["sourceOnKun"] += line
                    rows[-1]["_reading_reassembled"] = True
                    break
        all_rows.extend(rows)
    return all_rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pdf", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    pdf = fitz.open(args.pdf)
    if pdf.page_count != 208:
        raise SystemExit("Unexpected Kanji supplement page count; requires 208.")
    rows = extract(pdf)
    problems = collections.Counter()
    for row in rows:
        flags = ["NEEDS_CONTEXTUAL_VIETNAMESE_MEANING"]
        if not row["sourceHanViet"]:
            flags.append("MISSING_HAN_VIET_LABEL")
        if not row["sourceOnKun"]:
            flags.append("MISSING_SOURCE_ON_KUN")
        if row["sourceOnKun"].endswith(("／", "・")):
            flags.append("SOURCE_READING_SPLIT_ACROSS_PAGE")
        if row.pop("_reading_reassembled", False):
            flags.append("SOURCE_READING_REASSEMBLED_NEEDS_CONFIRMATION")
        row["qaFlags"] = flags
        problems.update(flags)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    report = {
        "metadataCandidates": len(rows),
        "hanVietLabels": sum(bool(row["sourceHanViet"]) for row in rows),
        "sourceReadingLines": sum(bool(row["sourceOnKun"]) for row in rows),
        "issues": dict(problems),
        "approvedItems": 0,
        "status": "SHORT_SOURCE_LABELS_ONLY_CONTEXTUAL_MEANINGS_UNVERIFIED"
    }
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
