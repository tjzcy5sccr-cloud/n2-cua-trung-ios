#!/usr/bin/env python3
"""Đối chiếu từ vựng JLPT N2 với từ điển Nhật–Việt được phép tái sử dụng.

Nguồn tiếng Việt: bunchaway/tu-dien-nhat-viet (CC BY-SA 4.0), final.csv.
Dữ liệu KHÔNG có cột kana: bản khớp từ là GỢI Ý, không phải nghĩa đã xác minh.
Không đụng vào nghĩa đã biên tập, ID SRS, nội dung Nhật hay bản dịch ví dụ.
Không tự công bố "100% chính xác". Không chép kho Mazii/Jdict chưa được cấp phép.
"""
import argparse
import collections
import csv
import io
import json
import re
import unicodedata
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "content-packs/openjlpt-n2-core.json"
MANIFEST = ROOT / "content-packs/manifest.json"
QA = ROOT / "content-packs/N2_VI_TRANSLATION_QA.json"
SOURCE = "https://raw.githubusercontent.com/bunchaway/tu-dien-nhat-viet/main/final.csv"
LICENSE = "https://creativecommons.org/licenses/by-sa/4.0/"

def load_reference():
    request = urllib.request.Request(
        SOURCE, headers={"User-Agent": "N2-of-Trung-Educational-Dictionary-Audit/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        blob = response.read(45_000_000)
    if len(blob) < 100_000:
        raise RuntimeError("Từ điển tải chưa đủ nội dung, không cập nhật.")
    result = collections.defaultdict(set)
    for row in csv.reader(io.StringIO(blob.decode("utf-8-sig"), newline="")):
        if len(row) < 2:
            continue
        word = unicodedata.normalize("NFC", row[0].strip())
        gloss = row[1].strip()
        if word and gloss:
            result[word].add(gloss)
    return result

def acceptable(word, choices):
    if len(choices) != 1:
        return None
    definition = next(iter(choices)).strip()
    if not (2 <= len(definition) <= 350):
        return None
    # Nghĩa tiếng Việt phải có từ ngữ thực và không phải đoạn HTML/URL.
    if re.search(r"https?://|<[^>]*>|\\x00", definition, re.I):
        return None
    if not re.search(r"[a-zA-ZÀ-ỹ]", definition):
        return None
    return definition

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Cập nhật candidate + version")
    args = parser.parse_args()
    pack = json.loads(CORE.read_text(encoding="utf-8"))
    source = load_reference()
    stats = collections.Counter()
    examples = []
    for entry in pack["vocab"]:
        if entry.get("meaningStatus") in ("editorial_reviewed", "source_verified"):
            stats["editorial_preserved"] += 1
            continue
        match = source.get(unicodedata.normalize("NFC", entry["word"]))
        if not match:
            stats["no_exact_match"] += 1
            continue
        gloss = acceptable(entry["word"], match)
        if gloss is None:
            stats["ambiguous_or_filtered"] += 1
            continue
        if entry.get("meaningStatus") == "dictionary_matched_unverified" and entry.get("meaning") == gloss:
            stats["already_matched"] += 1
            continue
        # Giữ nghĩa máy gốc trong QA nếu cần; không ghi nguyên văn vào repo để giảm trùng lặp.
        entry["meaning"] = gloss
        entry["meaningStatus"] = "dictionary_matched_unverified"
        entry["meaningSource"] = "bunchaway/tu-dien-nhat-viet (CC BY-SA 4.0)"
        stats["new_candidate"] += 1
        if len(examples) < 14:
            examples.append({"jp":entry["word"],"reading":entry["reading"],"suggested":gloss[:120]})
    print("Vietnamese dictionary entries:", len(source))
    print("Coverage:", json.dumps(stats, ensure_ascii=False, sort_keys=True))
    print("Example suggestions:", json.dumps(examples, ensure_ascii=False))
    if not args.apply or not stats["new_candidate"]:
        print("Dry-run / no changes; nothing was committed.")
        return
    pack["version"] += 1
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    remote = next(p for p in manifest["packs"] if p["id"] == pack["id"])
    remote["version"] = pack["version"]
    qa = json.loads(QA.read_text(encoding="utf-8"))
    qa["packVersion"] = pack["version"]
    qa["candidateSource"] = {
        "name": "Từ điển Nhật–Việt mở (Bunchaway)",
        "url": "https://github.com/bunchaway/tu-dien-nhat-viet",
        "license": "CC BY-SA 4.0",
        "licenseURL": LICENSE,
        "method": "Khớp chính xác mặt chữ Nhật + 1 nghĩa duy nhất từ CSV",
        "limitations": "Chưa khớp kana, chưa đối chiếu Mazii/Jdict; KHÔNG tính là verified.",
    }
    qa["automaticDictionaryAudit"] = dict(stats)
    qa["automaticDictionaryExamples"] = examples
    qa["scopeLimitation"] = (
        "Nghĩa 'dictionary_matched_unverified' là gợi ý có nguồn mở, "
        "không phải nghĩa đã duyệt; không được dùng làm đáp án thi. "
        "Mọi từ đa nghĩa, đồng tự khác cách đọc phải đối chiếu thêm Mazii/Jdict.")
    CORE.write_text(json.dumps(pack, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    QA.write_text(json.dumps(qa, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("Saved candidate-only updates as pack version",pack["version"])

if __name__ == "__main__":
    main()
