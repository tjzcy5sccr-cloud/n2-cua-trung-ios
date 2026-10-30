#!/usr/bin/env python3
"""Generate full offline Japanese furigana token atlas for all bundled N2 examples.
Requires: pip install 'fugashi[unidic-lite]'
The script only annotates Japanese words with dictionary-confirmed readings, reporting
unresolved kanji instead of inventing pronunciations.
"""
import argparse
import json
import re
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
COURSE_FILES = [
    BASE / 'N2CuaTrung/Resources/content.json',
    BASE / 'content-packs/n2-expansion-01.json',
    BASE / 'content-packs/openjlpt-n2-core.json',
    BASE / 'content-packs/vn26-original-practice-01.json',
    BASE / 'content-packs/n2-reading-listening-02.json',
]
GRAMMAR = BASE / 'N2CuaTrung/Resources/grammar-details.json'
OUT = BASE / 'N2CuaTrung/Resources/furigana-atlas.json'
QA = BASE / 'furigana-qa.json'
KANJI = re.compile(r'[\u3400-\u9fff\uF900-\uFAFF々〆]')
HIRAGANA = re.compile(r'[\u3041-\u309F]')
KATAKANA = re.compile(r'[\u30A1-\u30FF]')


def kata_to_hira(text: str) -> str:
    return ''.join(chr(ord(c)-96) if 0x30A1 <= ord(c) <= 0x30F6 else c for c in text)


def assemble_one(surface, read):
    """Preserve okurigana unannotated; put furigana above the kanji parts."""
    if not KANJI.search(surface):
        return [[surface, None]]
    if not read or read == '*':
        return [[surface, None]]
    reading = kata_to_hira(read)
    # Segment the word around kana; use each literal kana segment as an anchor.
    chunks = re.findall(r'[\u3041-\u30FFー]+|[^\u3041-\u30FFー]+', surface)
    if len(chunks) == 1:
        return [[surface, reading]]
    results = []
    i = 0
    for n, chunk in enumerate(chunks):
        if KANJI.search(chunk):
            if n+1 < len(chunks):
                anchor = kata_to_hira(chunks[n+1])
                where = reading.find(anchor, i)
                if where < i or not reading[i:where]:
                    return [[surface, reading]]
                results.append([chunk, reading[i:where]])
                i = where
            else:
                rem = reading[i:]
                if not rem:
                    return [[surface, reading]]
                results.append([chunk, rem])
                i = len(reading)
        else:
            literal = kata_to_hira(chunk)
            if not reading.startswith(literal, i):
                return [[surface, reading]]
            results.append([chunk, None])
            i += len(literal)
    if i != len(reading) or ''.join(p[0] for p in results) != surface:
        return [[surface, reading]]
    return results


def collect_strings():
    sentences = set()
    word_readings = {}

    def add(obj):
        if isinstance(obj, str) and KANJI.search(obj):
            sentences.add(obj)

    for path in COURSE_FILES:
        course = json.loads(path.read_text(encoding='utf-8'))
        for entry in course.get('vocab', []):
            add(entry.get('word'))
            add(entry.get('example'))
            word, reading = entry.get('word'), entry.get('reading')
            if word and reading and KANJI.search(word) and not KANJI.search(reading):
                word_readings[word] = kata_to_hira(reading)
        for entry in course.get('grammar', []):
            add(entry.get('pattern'))
            add(entry.get('example'))
            for sample in entry.get('samples') or []:
                add(sample.get('text'))
        for entry in course.get('kanji', []):
            add(entry.get('word'))
            # Single Kanji show On/Kun separately, so never guess a specific reading.
        for field in ('readings', 'listening'):
            for entry in course.get(field, []):
                for attr in ('text', 'script', 'question'):
                    add(entry.get(attr))
                for choice in entry.get('choices') or []:
                    add(choice)
    extras = json.loads(GRAMMAR.read_text(encoding='utf-8'))
    for v in extras.values():
        for sample in v.get('extra', []):
            add(sample.get('text'))
    return sorted(sentences), word_readings


def build():
    from fugashi import Tagger
    tagger = Tagger()
    sentences, word_readings = collect_strings()
    atlas = {}
    missing = []
    token_count = 0
    annotated_kanji = 0
    total_kanji = 0

    for text in sentences:
        chunks = []
        offset = 0
        if text in word_readings:
            chunks = assemble_one(text, word_readings[text])
        else:
            for token in tagger(text):
                surface = token.surface
                at = text.find(surface, offset)
                if at < offset:
                    raise ValueError(f'Cannot align tokenizer: {text!r} / {surface!r}')
                if at > offset:
                    chunks.append([text[offset:at], None])
                offset = at + len(surface)
                read = getattr(token.feature, 'kana', None)
                if surface in word_readings:
                    read = word_readings[surface]
                parts = assemble_one(surface, read)
                chunks.extend(parts)
                token_count += 1
            if offset < len(text):
                chunks.append([text[offset:], None])

        if ''.join(p[0] for p in chunks) != text:
            raise ValueError(f'Token output lost original characters: {text}')
        for surface, reading in chunks:
            n = len(KANJI.findall(surface))
            total_kanji += n
            if reading and HIRAGANA.search(reading):
                annotated_kanji += n
            elif n:
                missing.append({'text': text, 'unread': surface})
        atlas[text] = chunks

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'version': 2, 'entries': atlas}, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    report = {
        'sentences_with_kanji': len(sentences),
        'tokenized_words': token_count,
        'kanji_characters_in_sentences': total_kanji,
        'kanji_characters_with_ruby': annotated_kanji,
        'character_coverage_percent': 100.0 * annotated_kanji / total_kanji if total_kanji else 100.0,
        'unannotated_fragments': missing,
        'note': 'Automatic Japanese morphological dictionary readings require contextual review for names and multiple readings.'
    }
    QA.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k,v in report.items() if k != 'unannotated_fragments'}, ensure_ascii=False))
    if missing:
        print('First unresolved tokens:', json.dumps(missing[:30], ensure_ascii=False), file=sys.stderr)
    return len(missing)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--strict', action='store_true', help='Fail the build if any Kanji remains without a reading')
    flags = parser.parse_args()
    failures = build()
    if flags.strict and failures:
        raise SystemExit(f'Unannotated Kanji fragments: {failures}. See furigana-qa.json.')