#!/usr/bin/env python3
"""Translate N2 data to Vietnamese with auditable, open-source Marian MT models.

Input: OpenJLPT derived content-packs/openjlpt-n2-core.json.
Output: in-place JSON only after checks pass; original IDs/JP readings preserved.
Existing Vietnamese translation is never overwritten. Machine results require review.
"""
import argparse
import json
import os
import re
from collections import Counter
from pathlib import Path

DATA = Path('content-packs/openjlpt-n2-core.json')
MANIFEST = Path('content-packs/manifest.json')
QA_REPORT = Path('content-packs/N2_VI_TRANSLATION_QA.json')


def strip_en(value):
    return re.sub(r'^\s*EN\s*[·:]\s*', '', str(value or '')).strip()


def translated_vi(value):
    return bool(value and not value.startswith('EN ·') and not value.startswith('EN :'))


def has_vietnamese(value):
    # Vietnamese diacritics provide a useful check but are not compulsory.
    return bool(re.search('[àáạảãăắằẵẳặâấầẫẩậđèéẹẻẽêếềễểệìíịỉĩòóọỏõôốồỗổộơớờỡởợùúụủũưứừữửựỳýỵỷỹ]', value.lower()))


class MT:
    def __init__(self, model_id, threads=4):
        import torch
        from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
        torch.set_num_threads(threads)
        self.torch = torch
        self.tokenizer = AutoTokenizer.from_pretrained(model_id, use_fast=False)
        self.model = AutoModelForSeq2SeqLM.from_pretrained(model_id)
        self.model.eval()
        self.target_token = None
        if model_id.endswith('en-vi'):
            vocab = self.tokenizer.get_vocab()
            for name in ('>>vie<<', '>>vi<<'):
                if name in vocab:
                    self.target_token = name
                    break
        print('Loaded', model_id, 'target token', self.target_token, flush=True)

    def translate(self, values, batch_size=16):
        unique = list(dict.fromkeys(values))
        output = {}
        for start in range(0, len(unique), batch_size):
            segment = unique[start:start+batch_size]
            in_text = [((self.target_token + ' ') if self.target_token else '') + s for s in segment]
            encoded = self.tokenizer(in_text, return_tensors='pt', padding=True, truncation=True, max_length=180)
            with self.torch.inference_mode():
                decoded = self.model.generate(**encoded, num_beams=2, max_new_tokens=128)
            got = self.tokenizer.batch_decode(decoded, skip_special_tokens=True)
            for source, target in zip(segment, got):
                output[source] = target.strip()
            if start % 320 == 0 or start+batch_size >= len(unique):
                print(f'Translated {min(start+batch_size, len(unique))}/{len(unique)} from model', flush=True)
        return output


def rule_structure(raw):
    replacements = [
        ('Verb-dict', 'Động từ thể từ điển'),
        ('Verb-plain', 'Động từ thể thông thường'),
        ('Verb-te', 'Động từ thể て'),
        ('Verb-nai', 'Động từ thể ない'),
        ('Noun', 'Danh từ'),
        ('Adjective', 'Tính từ'),
        ('Verb', 'Động từ'),
        ('Formal', 'Trang trọng'),
        ('Casual', 'Thân mật'),
    ]
    for a, b in replacements:
        raw = re.sub(r'\b'+re.escape(a)+r'\b', b, raw)
    return raw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check-only', action='store_true', help='Do not download models or modify data')
    parser.add_argument('--threads', type=int, default=4)
    args = parser.parse_args()
    pack = json.loads(DATA.read_text(encoding='utf-8'))
    stats = Counter()
    en = []
    ja = []

    def en_add(v):
        s = strip_en(v)
        if s: en.append(s)

    for row in pack['vocab']:
        if not translated_vi(row['meaning']): en_add(row['meaning']); stats['vocabMeaning'] += 1
        if not row.get('exampleVi'): ja.append(row['example']); stats['vocabExample'] += 1

    for row in pack['grammar']:
        if not translated_vi(row['meaning']): en_add(row['meaning']); stats['grammarMeaning'] += 1
        if not translated_vi(row['translation']): en_add(row['translation']); stats['grammarExample'] += 1
        for ex in row.get('samples', []):
            if not translated_vi(ex['translation']): en_add(ex['translation']); stats['grammarExample'] += 1
        if '·' in row['rule'] and not row.get('ruleVi'):
            # The original formation with JP patterns is preserved; translate only English usage note.
            note = row['rule'].split('·',1)[1].strip()
            if note: en.append(note); stats['grammarRuleNote'] += 1

    for row in pack['kanji']:
        if not translated_vi(row['meaning']): en_add(row['meaning']); stats['kanjiMeaning'] += 1

    print('Pending fields:', dict(stats), 'Unique EN', len(set(en)), 'Unique JA', len(set(ja)), flush=True)
    if args.check_only: return

    # Translate by source language, preserving original Japanese examples and grammar structures.
    en_mt = MT('Helsinki-NLP/opus-mt-en-vi', args.threads)
    en_dict = en_mt.translate(en)
    del en_mt
    import gc
    gc.collect()
    ja_mt = MT('Helsinki-NLP/opus-mt-ja-vi', args.threads)
    ja_dict = ja_mt.translate(ja, batch_size=12)

    problems = []
    def vi_en(v, label):
        source = strip_en(v)
        target = en_dict.get(source, '').strip()
        if not target or target.lower() == source.lower() or target.startswith('>>'):
            problems.append(f'{label}: {source[:100]} -> {target[:100]}')
        return target or 'Chưa xác minh bản dịch'
    def vi_ja(v, label):
        target = ja_dict.get(v, '').strip()
        if not target or target == v:
            problems.append(f'{label}: {v[:100]} -> {target[:100]}')
        return target or 'Chưa xác minh bản dịch'

    for row in pack['vocab']:
        if not translated_vi(row['meaning']): row['meaning'] = vi_en(row['meaning'], row['id']+'.meaning')
        if not row.get('exampleVi'): row['exampleVi'] = vi_ja(row['example'], row['id']+'.exampleVi')
        if 'OpenJLPT' in row['topic']: row['topic'] = 'Từ vựng JLPT N2'
    for row in pack['grammar']:
        if not translated_vi(row['meaning']): row['meaning'] = vi_en(row['meaning'], row['id']+'.meaning')
        if not translated_vi(row['translation']): row['translation'] = vi_en(row['translation'], row['id']+'.translation')
        for ex in row.get('samples', []):
            if not translated_vi(ex['translation']): ex['translation'] = vi_en(ex['translation'], row['id']+'.sample')
        if '·' in row['rule']:
            formation, note = row['rule'].split('·', 1)
            row['rule'] = rule_structure(formation.strip()) + ' · ' + vi_en('EN · '+note.strip(), row['id']+'.rule')
        else:
            row['rule'] = rule_structure(row['rule'])
    for row in pack['kanji']:
        if not translated_vi(row['meaning']): row['meaning'] = vi_en(row['meaning'], row['id']+'.meaning')

    english_fields = []
    for v in pack['vocab']:
        if not v['meaning'] or not v.get('exampleVi') or v['meaning'].startswith('EN ·'):
            english_fields.append(v['id'])
    for g in pack['grammar']:
        if g['meaning'].startswith('EN ·') or g['translation'].startswith('EN ·') or any(e['translation'].startswith('EN ·') for e in g.get('samples',[])):
            english_fields.append(g['id'])
    for k in pack['kanji']:
        if k['meaning'].startswith('EN ·'): english_fields.append(k['id'])
    if english_fields: raise ValueError('Incomplete translation fields: '+str(english_fields[:30]))
    # v3 supersedes bundled v2, without changing stable card IDs or old SRS progress.
    pack['version'] = max(pack['version']+1,3)
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    remote = next(p for p in manifest['packs'] if p['id']==pack['id'])
    remote['version'] = pack['version']
    qa = {
        'coverage': {k: len(pack[k]) for k in ('vocab','grammar','kanji')},
        'fieldTranslationCoverage': 'all requested user-visible strings filled',
        'translationMethod': 'machine translation, not human reviewed',
        'modelEnglishVietnamese': 'Helsinki-NLP/opus-mt-en-vi (Apache-2.0)',
        'modelJapaneseVietnamese': 'Helsinki-NLP/opus-mt-ja-vi (Apache-2.0)',
        'warnings': problems,
        'note': 'Máy dịch có thể nhầm nghĩa/ngữ cảnh. Cần rà soát thủ công trước khi công bố bản dịch chính xác 100%.',
    }
    DATA.write_text(json.dumps(pack,ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    QA_REPORT.write_text(json.dumps(qa,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Complete coverage; flagged',len(problems),'needs review. v',pack['version'],flush=True)

if __name__=='__main__': main()