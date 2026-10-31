#!/usr/bin/env python3
"""Build source-only Japanese-Vietnamese N2/N3 review queues from reusable open data.

Permissions: Bunchaway Japanese/Vietnamese CSV and OpenJLPT data are CC BY-SA 4.0.
These outputs are NOT lessons: every field carries unreviewed status and must
be checked manually against Japanese context before adding into the iOS app.
Do not scrape JLPT180/VNJP or copy proprietary study-book sections.
"""
import collections
import csv
import io
import json
import re
import unicodedata
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa-reports"
QA.mkdir(exist_ok=True)
OPEN = "https://raw.githubusercontent.com/evanclan/OpenJLPT/main/data/json"
DICT = "https://raw.githubusercontent.com/bunchaway/tu-dien-nhat-viet/main/final.csv"
LICENSE = "CC BY-SA 4.0"
RIGHTS = {
    "derivedDatasetLicense": LICENSE,
    "sources": [
        {"name": "Bunchaway tu-dien-nhat-viet", "url": "https://github.com/bunchaway/tu-dien-nhat-viet",
         "license": LICENSE, "purpose": "Vietnamese meanings for independently matched headwords"},
        {"name": "OpenJLPT", "url": "https://github.com/evanclan/OpenJLPT",
         "license": LICENSE, "purpose": "Community JLPT levels, word readings, Kanji and grammar candidate IDs"},
        {"name": "EDRDG JMdict/KANJIDIC2", "url": "https://www.edrdg.org/", "license": LICENSE},
        {"name": "Jonathan Waller JLPT lists", "url": "https://www.tanos.co.uk/jlpt/", "license": "CC BY"}
    ],
    "notice": "Derived research data; source fields and translations require individual review. Do not bundle the report in IPA.",
}
HEADERS = {"User-Agent": "N2-Cua-Trung-Licensed-Research/1.0"}

def get(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=90) as f:
        return f.read()

def obj(url):
    return json.loads(get(url).decode("utf-8-sig"))

def normal(word):
    return unicodedata.normalize("NFKC", str(word or "")).strip()

def save(path, content):
    path.write_text(json.dumps(content, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")

levels = ("n3", "n2")
vocab = []
for level in levels:
    words = obj(f"{OPEN}/vocab/{level}.json")
    print(f"OpenJLPT {level}: {len(words)} Japanese words", flush=True)
    for w in words:
        if normal(w.get("word")) and normal(w.get("reading")):
            vocab.append(w)
targets = {normal(v["word"]) for v in vocab}
print("Indexing licensed Vietnamese meanings for", len(targets), "headword spellings", flush=True)
meaning_by_word = {}
seen_rows = 0
bad_rows = 0
# Read 30MB dictionary as a CSV stream, without keeping unrelated entries.
req = urllib.request.Request(DICT, headers=HEADERS)
with urllib.request.urlopen(req, timeout=120) as stream:
    reader = csv.reader(io.TextIOWrapper(stream, encoding="utf-8-sig", newline=""))
    for row in reader:
        seen_rows += 1
        if len(row) < 2:
            bad_rows += 1
            continue
        word = normal(row[0])
        vi = row[1].strip()
        if word not in targets or not vi or vi.startswith("EN ·"):
            continue
        if len(vi) > 650:
            vi = vi[:650]
        meaning_by_word.setdefault(word, vi)
print("Dictionary rows:", seen_rows, "malformed:", bad_rows,
      "exact headword matches:", len(meaning_by_word), flush=True)

candidates = []
missing = []
already = set()
for word in vocab:
    surface = normal(word["word"])
    reading = normal(word["reading"])
    ident = f"{surface}|{reading}"
    if ident in already: continue
    already.add(ident)
    vi = meaning_by_word.get(surface)
    item = {
        "id": "openjlpt-" + str(word["id"]),
        "word": surface,
        "reading": reading,
        "JLPTApproximation": word.get("level", "").upper(),
        "sourceEnglishGlosses": word.get("meanings", [])[:4],
        "VietnameseCandidate": vi or "",
        "meaningStatus": "source_matched_unverified" if vi else "missing_vietnamese_meaning",
        "canPublishInIPA": False,
    }
    if vi: candidates.append(item)
    else: missing.append(item)

kanji = obj(f"{OPEN}/kanji/n2.json")
kanji_candidates = []
for k in kanji:
    ch = normal(k.get("character"))
    if not ch:continue
    kanji_candidates.append({
        "char": ch,
        "on": k.get("onyomi", []),
        "kun": k.get("kunyomi", []),
        "sourceEnglishGlosses": k.get("meanings", []),
        "VietnameseCandidate": meaning_by_word.get(ch, ""),
        "meaningStatus": "source_matched_unverified" if meaning_by_word.get(ch) else "missing_vietnamese_meaning",
        "canPublishInIPA": False
    })

grammar = obj(f"{OPEN}/grammar/n2.json")
grammar_candidates = [{
    "pattern": x.get("pattern", ""),
    "sourceEnglishGloss": x.get("meaning", ""),
    "VietnameseCandidate": "",
    "grammarStatus": "needs_vietnamese_translation_and_review",
    "canPublishInIPA": False
} for x in grammar if x.get("pattern")]

summary = {
    "kind": "source_only_licensed_candidates",
    "levels": ["N3", "N2"],
    "BunchawayDictionaryRows": seen_rows,
    "vocabularyCandidatesVietnamese": len(candidates),
    "vocabularyMissingVietnamese": len(missing),
    "n2KanjiCandidates": len(kanji_candidates),
    "n2GrammarCandidates": len(grammar_candidates),
    "quality": "UNREVIEWED — no automatic publication or claim of 100% accuracy",
    "referenceSitesOnly": [
        "https://jlpt180.com/jlpt-n2/",
        "https://vnjp.org/",
        "https://www.nguphaptiengnhat.net/tu-vung-tieng-nhat-n2.html"
    ],
    "licenses": RIGHTS,
}
save(QA / "licensed-n2-vietnamese-candidates.json", {
    "metadata": RIGHTS, "vocab": candidates, "kanji": kanji_candidates, "grammar": grammar_candidates
})
save(QA / "licensed-n2-missing-vietnamese.json", {
    "metadata": RIGHTS, "vocab": missing
})
save(QA / "licensed-n2-vietnamese-summary.json", summary)
print(json.dumps({k: v for k,v in summary.items() if k != "licenses"},
                 ensure_ascii=False, indent=2), flush=True)
