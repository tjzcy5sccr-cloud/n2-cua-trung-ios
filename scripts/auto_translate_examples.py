#!/usr/bin/env python3
"""Dịch ví dụ Nhật -> Việt dựa trên câu gốc và nghĩa trọng tâm của mục học.

Không dịch bằng cách nối nghĩa từng Kanji. Mô hình Marian OPUS ja-vi (Apache-2.0)
dịch cả câu; nghĩa chính được dùng để soát các ứng viên và lưu đối chiếu.
Nghĩa không khớp được đánh dấu để duyệt, không tự sửa nội dung câu hay tự nhận đúng.
Giữ bản dịch đã biên tập; tuyệt đối không đổi ID học tập.
"""
import argparse
import collections
import copy
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "content-packs/openjlpt-n2-core.json"
MANIFEST = ROOT / "content-packs/manifest.json"
QA = ROOT / "content-packs/N2_VI_TRANSLATION_QA.json"
MODEL = "Helsinki-NLP/opus-mt-ja-vi"
ENGINE = "Helsinki-NLP/opus-mt-ja-vi, Apache-2.0"
STATUS_AUTO = "machine_translated_unreviewed"
STATUS_HUMAN = {"editorial_reviewed", "source_verified", "independently_verified"}
INVALID = ("_BAR_", "*******", "Và đây là một ví dụ khác")

def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def normalized(text):
    return unicodedata.normalize("NFC", text or "").casefold().strip()

def main_sense(meaning):
    """First gloss normally represents the core sense; ignore parenthetical detail."""
    sense = re.split(r"[;\n，、/]|(?<!\w),\s", meaning or "", maxsplit=1)[0]
    return re.sub(r"\([^)]*\)", "", sense).strip()[:110]

def sense_tokens(meaning):
    """Weak warning heuristic, not linguistic proof of correct translation."""
    sense = main_sense(meaning)
    tokens = re.findall(r"[a-zA-ZÀ-ỹ]+", normalized(sense))
    stop = {"có","cái","một","người","sự","của","và","là","các","cho",
            "với","này","đó","được","bị","trong","ra","làm","đến","theo",
            "về","từ","trên","như","mà","để","rất","nhiều"}
    return [w for w in tokens if len(w) >= 3 and w not in stop]

def sense_relation(meaning, vietnamese):
    words = sense_tokens(meaning)
    if not words: return "cannot_assess"
    output = normalized(vietnamese)
    return "gloss_token_overlap" if any(w in output for w in words[:5]) else "needs_context_review"

def candidate_ok(japanese, result):
    if not isinstance(result, str): return False
    s = result.strip()
    if not 3 <= len(s) <= 600 or any(fragment in s for fragment in INVALID):
        return False
    latin = len(re.findall(r"[A-Za-zÀ-ỹ]", s))
    japanese_count = len(re.findall(r"[\u3040-\u30ff\u3400-\u9fff]", s))
    if japanese_count > max(4, latin // 3): return False
    return bool(re.search(r"[A-Za-zÀ-ỹ]", s))

def targets(pack):
    """Core vocab not human reviewed and extra grammar examples awaiting review."""
    for vocab in pack.get("vocab", []):
        if vocab.get("exampleStatus") in STATUS_HUMAN: continue
        yield {
            "entry": vocab, "field": "exampleVi", "status": "exampleStatus",
            "japanese": vocab["example"], "kind": "vocab",
            "key": vocab["id"], "word": vocab["word"],
            "reading": vocab["reading"], "meaning": vocab["meaning"]
        }
    for grammar in pack.get("grammar", []):
        # Main examples were revised by an editor: do not replace them.
        for i, sample in enumerate(grammar.get("samples", [])):
            if sample.get("translationStatus") in STATUS_HUMAN: continue
            yield {
                "entry": sample, "field": "translation", "status": "translationStatus",
                "japanese": sample["text"], "kind": "grammar_extra",
                "key": grammar["id"] + ":" + str(i), "word": grammar["pattern"],
                "reading": "", "meaning": grammar["meaning"]
            }

class MarianTranslator:
    def __init__(self):
        import torch
        from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
        self.torch = torch
        torch.set_num_threads(min(torch.get_num_threads(), 3))
        self.tokenizer = AutoTokenizer.from_pretrained(MODEL)
        self.model = AutoModelForSeq2SeqLM.from_pretrained(MODEL).eval().to("cpu")

    def translate(self, texts, batch_size=8):
        translations = []
        for i in range(0, len(texts), batch_size):
            current = texts[i:i + batch_size]
            encoded = self.tokenizer(
                current, return_tensors="pt", padding=True,
                truncation=True, max_length=180)
            with self.torch.inference_mode():
                output = self.model.generate(
                    **encoded, max_new_tokens=190, num_beams=4,
                    no_repeat_ngram_size=3, early_stopping=True)
            translations.extend(self.tokenizer.batch_decode(
                output, skip_special_tokens=True))
            print("Translated:", min(i + len(current), len(texts)), "/", len(texts), flush=True)
        return translations

def apply_translation(pack, translator, limit=0):
    jobs = list(targets(pack))
    if limit: jobs = jobs[:limit]
    print("Items to translate:",len(jobs),flush=True)
    unique = list(dict.fromkeys(job["japanese"] for job in jobs))
    generated = translator.translate(unique) if unique else []
    trans = dict(zip(unique, generated))
    stats = collections.Counter()
    problems = []
    for job in jobs:
        entry = job["entry"]
        vi = trans.get(job["japanese"], "").strip()
        if not candidate_ok(job["japanese"], vi):
            stats["failed_or_unusable"] += 1
            problems.append({"id": job["key"], "problem": "translation_empty_or_invalid"})
            continue
        status = sense_relation(job["meaning"], vi)
        entry[job["field"]] = vi
        entry[job["status"]] = STATUS_AUTO
        entry["exampleTranslationModel" if job["kind"] == "vocab" else "translationModel"] = ENGINE
        entry["exampleTranslationGloss" if job["kind"] == "vocab" else "translationGloss"] = main_sense(job["meaning"])
        entry["exampleSenseCheck" if job["kind"] == "vocab" else "translationSenseCheck"] = status
        stats["machine_translated_unreviewed"] += 1
        stats[status] += 1
        if status == "needs_context_review" and len(problems) < 80:
            problems.append({"id": job["key"], "word": job["word"],
                             "meaning": main_sense(job["meaning"]),
                             "japanese": job["japanese"], "translation": vi,
                             "problem": status})
    return dict(stats), problems

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply",action="store_true")
    parser.add_argument("--max-items",type=int,default=0)
    args = parser.parse_args()
    pack = load_json(CORE)
    pending = list(targets(pack))
    print("Original pack version:",pack["version"])
    print("Translation candidates:", len(pending))
    print("Example:",[(x["kind"],x["word"],x["meaning"],x["japanese"])
                      for x in pending[:3]])
    if not args.apply:
        print("DRY RUN (no model or file updates).")
        return
    translator = MarianTranslator()
    stats, issues = apply_translation(pack, translator, limit=args.max_items)
    if not stats.get("machine_translated_unreviewed",0):
        print("No successful translations, no changes made.")
        return
    pack["version"] += 1
    manifest = load_json(MANIFEST)
    match = next(x for x in manifest["packs"] if x["id"] == pack["id"])
    assert match["version"] == pack["version"] - 1, "Pack and manifest out of sync"
    match["version"] = pack["version"]
    qa = load_json(QA)
    qa["packVersion"] = pack["version"]
    vocab_counts = collections.Counter(v.get("exampleStatus") for v in pack["vocab"])
    extras = [s for g in pack.get("grammar",[]) for s in g.get("samples",[])]
    extra_counts = collections.Counter(s.get("translationStatus") for s in extras)
    qa["exampleAutoTranslation"] = {
        "model": ENGINE,
        "method": "whole-sentence Marian JA→VI + core Vietnamese gloss sense-overlap warning",
        "revisedExamplesPreserved": True,
        "disclaimer": "Dịch máy là bản tham khảo. Kiểm tra trùng từ nghĩa chính là heuristic, KHÔNG chứng minh câu đúng.",
        "run": stats,
        "vocabularyStatuses": dict(vocab_counts),
        "extraGrammarStatuses": dict(extra_counts),
        "examplesNeedingReview": issues
    }
    qa["sentenceReview"] = {
        "vocabTotal":len(pack["vocab"]),
        "vocabExamplesEditoriallyTranslated":vocab_counts["editorial_reviewed"],
        "vocabExamplesAutoTranslated":vocab_counts[STATUS_AUTO],
        "vocabExamplesPending":len(pack["vocab"]) - vocab_counts["editorial_reviewed"] - vocab_counts[STATUS_AUTO],
        "grammarMainTranslated":sum(g.get("translationStatus") == "editorial_reviewed" for g in pack["grammar"]),
        "grammarExtraAutoTranslated":extra_counts[STATUS_AUTO],
        "grammarExtraPending":len(extras) - extra_counts[STATUS_AUTO] - extra_counts["editorial_reviewed"],
        "claim":"Dịch máy có nghĩa gốc làm mốc rà soát. Không được coi là 100% khớp nghĩa."
    }
    write_json(CORE,pack)
    write_json(MANIFEST,manifest)
    write_json(QA,qa)
    print("Published locally: version",pack["version"], json.dumps(stats,ensure_ascii=False),flush=True)

if __name__ == "__main__":
    main()
