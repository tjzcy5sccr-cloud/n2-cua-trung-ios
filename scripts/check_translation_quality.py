#!/usr/bin/env python3
"""QA tiếng Việt / bộ thủ. Chỉ kiểm tra tính toàn vẹn, không chứng nhận nghĩa chính xác 100%."""
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "content-packs/openjlpt-n2-core.json"
MANIFEST = ROOT / "content-packs/manifest.json"
RADICALS = ROOT / "N2CuaTrung/Sources/KangxiRadicalsView.swift"

data = json.loads(CORE.read_text(encoding="utf-8"))
manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
remote = next(p for p in manifest["packs"] if p["id"] == data["id"])
assert remote["version"] == data["version"], "Manifest and content pack versions differ"

vocab, kanji = data["vocab"], data["kanji"]
assert len(vocab) == 1756 and len(kanji) == 376, "Unexpected dataset truncation"
assert len({v["id"] for v in vocab}) == len(vocab), "Duplicate vocab IDs"
assert len({v["id"] for v in kanji}) == len(kanji), "Duplicate Kanji IDs"
for record in vocab:
    assert record.get("meaningStatus") in ("editorial_reviewed", "source_verified", "machine_unreviewed", "dictionary_matched_unverified"), record["id"]
    assert record.get("exampleStatus") in ("machine_unreviewed", "editorial_reviewed"), record["id"]
    assert record["word"] and record["reading"], record["id"]
for record in kanji:
    assert record.get("meaningStatus") in ("editorial_reviewed", "machine_unreviewed"), record["id"]
    assert len(record["char"]) == 1, record["id"]

vmap = {v["word"]: v for v in vocab}
kmap = {v["char"]: v for v in kanji}
assert vmap["あくび"]["meaning"].startswith("ngáp")
assert vmap["一昨年"]["meaning"] == "năm kia"
assert vmap["エプロン"]["meaning"] == "tạp dề"
assert "mỡ" in vmap["脂"]["meaning"] and "dương vật" not in vmap["脂"]["meaning"]
assert "tóm tắt" in vmap["粗筋"]["meaning"]
assert "tỉnh" in kmap["県"]["meaning"]

vetted_vocab = sum(v["meaningStatus"] == "editorial_reviewed" for v in vocab)
vetted_kanji = sum(v["meaningStatus"] == "editorial_reviewed" for v in kanji)
assert vetted_vocab >= 179 and vetted_kanji >= 95

source = RADICALS.read_text(encoding="utf-8")
r_match = re.search(r'private static let rawRadicals = """\n(.*?)\n"""', source, re.S)
k_match = re.search(r'private static let rawKanji = """\n(.*?)\n"""', source, re.S)
assert r_match and k_match, "Radical reference missing"
radicals = [line.split("|") for line in r_match.group(1).splitlines()]
mapping = [line.split("|") for line in k_match.group(1).splitlines()]
assert len(radicals) == 214, "Kangxi table must have exactly 214 radicals"
assert all(len(v) == 3 for v in radicals), "Invalid radical row"
assert len({v[0] for v in radicals}) == 214
for i, (char, _, _) in enumerate(radicals):
    unicode_radical = unicodedata.normalize("NFKC", chr(0x2F00 + i))
    assert char == unicode_radical, (i + 1, char, unicode_radical)
assert len(mapping) >= 471
assert all(len(x) == 3 and 1 <= int(x[1]) <= 214 for x in mapping)
mapped = {m[0] for m in mapping}
assert {k["char"] for k in kanji}.issubset(mapped)
print("PASS: 214 canonical radicals, Kanji reference mapping, consistent pack version")
print("Vietnamese editorial review:", vetted_vocab, "vocab;", vetted_kanji, "Kanji")
print("Source-verified Vietnamese meanings:", sum(v.get("meaningStatus") == "source_verified" for v in vocab))
candidates = sum(v.get("meaningStatus") == "dictionary_matched_unverified" for v in vocab)
print("Dictionary candidates (NOT VERIFIED):", candidates)
print("Pending verification:", len(vocab)-vetted_vocab, "vocab;", len(kanji)-vetted_kanji, "Kanji")
print("Note: These checks cannot replace manual per-entry dictionary validation.")
