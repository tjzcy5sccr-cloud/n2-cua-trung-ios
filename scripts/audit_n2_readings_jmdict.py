#!/usr/bin/env python3
"""Audit N2 Japanese written form + kana against independent JMdict evidence.

This is NOT proof of Vietnamese semantic accuracy. JMdict is used only to
validate reading-to-spelling pairs and flag ambiguous readings/senses.
Sources: JMdict/EDRDG via jkindrix/japanese-language-data, CC BY-SA 4.0.
Output: review queue with each candidate's Japanese reading and English senses,
allowing later editorial checking against Vietnamese learning dictionaries.
"""
import collections
import datetime
import json
import unicodedata
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "content-packs/openjlpt-n2-core.json"
OUT = ROOT / "content-packs/N2_JMDICT_READING_AUDIT.json"
SOURCE = "https://raw.githubusercontent.com/jkindrix/japanese-language-data/main/data/core/words.json"

def normal(text):
    return unicodedata.normalize("NFC", text or "").strip()

def load_reference():
    print("Reading independent JMdict metadata for spelling/kana cross-check...", flush=True)
    req = urllib.request.Request(SOURCE, headers={"User-Agent": "N2-Trung-JMdict-Audit/1.0"})
    with urllib.request.urlopen(req, timeout=180) as response:
        size = response.headers.get("Content-Length")
        print("JMdict source bytes:", size, flush=True)
        return json.load(response)

def indexed_entries(rows):
    index = collections.defaultdict(list)
    for row in rows:
        kanji_spellings = [normal(x["text"]) for x in row.get("kanji", [])]
        for k in kanji_spellings:
            index[k].append(row)
        for kana in row.get("kana", []):
            index[normal(kana["text"])].append(row)
    return index

def matching_forms(row, word, reading):
    kanji = {normal(x["text"]) for x in row.get("kanji", [])}
    for item in row.get("kana", []):
        text = normal(item["text"])
        applies = item.get("appliesToKanji", ["*"])
        if text == reading and (
            (word in kanji and ("*" in applies or word in applies)) or
            (word == reading and (not kanji or not applies or "*" in applies))
        ):
            return True
    return False

def example_senses(row, word, reading):
    senses = []
    for sense in row.get("sense", []):
        permitted_kanji = sense.get("appliesToKanji", [])
        permitted_kana = sense.get("appliesToKana", [])
        if permitted_kanji and word not in permitted_kanji: continue
        if permitted_kana and reading not in permitted_kana: continue
        english = [g["text"] for g in sense.get("gloss", []) if g.get("lang") == "eng"]
        if english:
            senses.append({"en": english[:4], "pos": sense.get("partOfSpeech", [])[:4]})
    return senses[:7]

def main():
    pack = json.loads(PACK.read_text(encoding="utf-8"))
    ref = load_reference()
    rows = ref["words"]
    idx = indexed_entries(rows)
    counts = collections.Counter()
    review = []
    for vocab in pack["vocab"]:
        word, reading = normal(vocab["word"]), normal(vocab["reading"])
        candidates = idx.get(word, [])
        matched = {e["id"]: e for e in candidates if matching_forms(e, word, reading)}
        if not candidates:
            label = "no_spelling_match_in_common_JMdict"
        elif not matched:
            label = "reading_does_not_match_JMdict"
        elif len(matched) > 1:
            label = "multiple_possible_dictionary_entries"
        else:
            label = "writing_and_kana_confirmed"
        counts[label] += 1
        if vocab.get("meaningStatus") == "dictionary_matched_unverified":
            counts["sourced_vietnamese_candidates"] += 1
        ids = list(matched)[:8]
        row = next(iter(matched.values()), None)
        review.append({
            "id":vocab["id"], "japanese":word, "kana":reading,
            "readingEvidence":label,
            "jmdictEntryIDs":ids,
            "meaningStatus":vocab.get("meaningStatus", "bundled"),
            "jmdictEnglishSenses":example_senses(row, word, reading) if row else [],
            "note":"Japanese reading check only; compare Vietnamese sense with Mazii/Jdict independently.",
        })
    payload = {
        "reportVersion":1,
        "generatedUTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "packVersion":pack["version"],
        "scope":"All vocabulary in OpenJLPT N2 pack",
        "source":{
            "reference":"JMdict/EDRDG, via jkindrix/japanese-language-data common subset",
            "url":SOURCE,
            "license":"CC BY-SA 4.0",
            "warning":"Only common-entry subset; missing spelling does not mean word is wrong.",
        },
        "counts":dict(counts),
        "semanticValidation": "NOT PERFORMED. Kana confirmation is not Vietnamese semantic validation.",
        "reviewQueue":review,
    }
    OUT.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("JMdict audit counts:",json.dumps(counts,ensure_ascii=False))
    print("Flagged for review:",[
        (e["japanese"],e["kana"],e["readingEvidence"])
        for e in review if e["readingEvidence"] != "writing_and_kana_confirmed"
    ][:25],flush=True)
    print("Published:",str(OUT.relative_to(ROOT)),flush=True)

if __name__=="__main__": main()
