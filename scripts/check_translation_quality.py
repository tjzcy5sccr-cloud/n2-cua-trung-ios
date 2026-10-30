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
    assert record.get("exampleStatus") in ("machine_unreviewed", "editorial_reviewed", "machine_translated_unreviewed"), record["id"]
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

# Chống tái xuất hiện nội dung ngữ pháp đã từng dịch sai; kiểm toàn gói.
grammar = data["grammar"]
assert len(grammar) == 93, "Unexpected grammar count"
assert all(g.get("grammarStatus") == "editorial_reviewed" for g in grammar), "Grammar notes not audited"
assert all(g.get("translationStatus") == "editorial_reviewed" for g in grammar), "Main grammar translations not corrected"
for g in grammar:
    assert len(g["rule"]) >= 22 and len(g["meaning"]) > 3, g["pattern"]
    assert len(g["translation"]) > 8 and not any(
        token in g["rule"] for token in ["_BAR_", "******", "m Bobbiet", "Gova a i"])
    for sample in g.get("samples", []):
        assert sample.get("translationStatus") in ("needs_sentence_review", "editorial_reviewed", "machine_translated_unreviewed")
reviewed_examples = sum(v["exampleStatus"] == "editorial_reviewed" for v in vocab)
assert reviewed_examples >= 50, "Revised vocabulary example translations missing"
assert all(v.get("exampleVi") for v in vocab if v.get("exampleStatus") == "editorial_reviewed")
print("Grammar glossary: 93/93 explanations and 93/93 main translations revised")
print("Vocabulary example translations editorially revised:", reviewed_examples, "/", len(vocab))
print("Grammar extra sample translations still require individual review:",
      sum(s.get("translationStatus") == "needs_sentence_review"
          for g in grammar for s in g.get("samples", [])))
# Gesture and voice regression tests are static checks, not substitutes for device tests.
app = ROOT / "N2CuaTrung/Sources"
for name in ["FlashcardView.swift", "KanjiSwipeDeckView.swift"]:
    code = (app / name).read_text(encoding="utf-8")
    assert "TapGesture()" in code and ".exclusively(before: DragGesture(minimumDistance: 16))" in code, name
    assert "ScrollView(.vertical)" not in code.split("private func cardSurface(", 1)[1].split("private func flip(", 1)[0], name
    assert "changeCard(by: dx < 0 ? 1 : -1)" in code, name
    assert "changeCard(by: dy < 0 ? 1 : -1)" in code, name
    assert "voice.stop()" in code and "let next = cards[nextIndex]" in code, name
    assert ".highPriorityGesture" not in code, name
voice = (app / "StudyStore.swift").read_text(encoding="utf-8")
assert "pendingSpeechWork?.cancel()" in voice
assert "generation == self.speechGeneration" in voice
print("PASS: exclusive tap/swipe gestures keep page fixed, show next card, and cancel queued old speech.")

# Nếu đã dịch tự động, bắt buộc lưu được nội dung + dấu vết nghĩa trọng tâm.
for v in vocab:
    if v.get("exampleStatus") == "machine_translated_unreviewed":
        assert len(v.get("exampleVi", "")) >= 3, v["id"]
        assert v.get("exampleTranslationGloss"), v["id"]
        assert v.get("exampleSenseCheck") in (
            "gloss_token_overlap", "needs_context_review", "cannot_assess"), v["id"]
for g in grammar:
    for sample in g.get("samples", []):
        if sample.get("translationStatus") == "machine_translated_unreviewed":
            assert len(sample.get("translation", "")) >= 3
            assert sample.get("translationGloss")
print("Automated examples must retain their main gloss, machine label, and check status.")
print("Note: These checks cannot replace manual per-entry dictionary validation.")
