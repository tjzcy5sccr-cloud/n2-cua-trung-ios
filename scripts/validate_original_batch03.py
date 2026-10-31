#!/usr/bin/env python3
"""Regression test for 100 independently authored Japanese/Vietnamese batch-03 records.

This verifies data presence, stable identities, translations, Japanese sentence
containment and correct answer indices and cleaned blank Kun readings. It does NOT establish dictionary-level
or expert Japanese-language correctness; those audits remain separate.
"""
import json
import re
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT/"research/original-batch-03/lessons.json").read_text(encoding="utf-8"))
assert source["schemaVersion"]==1
series=("mimikara","shin-kanzen","sou-matome","speed-master")
kinds=("vocab","grammar","kanji","readings","listening")
abbrev={"vocab":"v","grammar":"g","kanji":"k","readings":"r","listening":"l"}
count=Counter()
seen_words=set()
seen_patterns=set()
seen_chars=set()
jp_exam=set()
for name in series:
    pack=json.loads((ROOT/f"content-packs/n2-series-{name}.json").read_text(encoding="utf-8"))
    assert pack["seriesId"]==name and pack["version"]>=6
    assert all(k.get("kun") != "—" for k in pack["kanji"] if k["id"].startswith("trung-original-b03-")),("Unnormalized new Kun",name)
    src=source["series"][name]
    assert (len(src["vocab"]),len(src["grammar"]),len(src["kanji"]),len(src["readings"]),len(src["listening"]))==(16,3,4,1,1)
    for kind in kinds:
        indexed={x["id"]:x for x in pack[kind]}
        for ix,raw in enumerate(src[kind],1):
            key=f"trung-original-b03-{abbrev[kind]}-{name}-{ix:03d}"
            assert key in indexed,(name,kind,ix)
            p=indexed[key]
            if kind=="vocab":
                word,reading,meaning,jp,vi=raw
                assert all(p[field]==expected for field,expected in (
                    ("word",word),("reading",reading),("meaning",meaning),
                    ("example",jp),("exampleVi",vi)))
                assert p["meaningStatus"]=="editorial_reviewed"
                assert p["exampleStatus"]=="editorial_reviewed"
                assert word in jp or word[:-1] in jp,(word,jp)
                assert word not in seen_words,word
                assert re.search(r"[ぁ-んァ-ン一-龯]",jp)
                assert re.search(r"[a-zA-ZÀ-ỹ]",vi)
                assert len(vi)>=12 and len(reading)>=2
                seen_words.add(word)
            elif kind=="grammar":
                pattern,meaning,rule,jp,vi,week=raw
                assert all(p[field]==expected for field,expected in (
                    ("pattern",pattern),("meaning",meaning),("rule",rule),
                    ("example",jp),("translation",vi),("week",int(week))))
                assert p["grammarStatus"]==p["translationStatus"]=="editorial_reviewed"
                assert pattern not in seen_patterns,pattern
                seen_patterns.add(pattern)
            elif kind=="kanji":
                char,on,kun,meaning,compound=raw
                assert all(p[field]==expected for field,expected in (
                    ("char",char),("on",on),("kun", "" if kun=="—" else kun),
                    ("meaning",meaning),("word",compound)))
                assert p["meaningStatus"]=="editorial_reviewed"
                assert char in compound
                assert compound in {x["word"] for x in pack["vocab"]}
                assert char not in seen_chars,char
                seen_chars.add(char)
            else:
                assert all(p[k]==v for k,v in raw.items()),(name,kind,key)
                assert len(p["choices"])==4 and len(set(p["choices"]))==4
                assert 0<=p["answer"]<4
                assert p["explanation"] and p["question"]
                orig=p["text"] if kind=="readings" else p["script"]
                tr=p["textVi"] if kind=="readings" else p["scriptVi"]
                assert len(orig)>=95 and len(tr)>=90
                assert orig not in jp_exam
                jp_exam.add(orig)
                assert "EN ·" not in tr and "TODO" not in tr
            count[kind]+=1
assert dict(count)=={"vocab":64,"grammar":12,"kanji":16,"readings":4,"listening":4},count
manifest=json.loads((ROOT/"content-packs/manifest-series.json").read_text(encoding="utf-8"))
assert {x["id"]:x["version"] for x in manifest["packs"]}=={
    f"n2-series-{name}":6 for name in series}
print("PASS batch03: 100 original learning items, stable IDs, Japanese/Vietnamese text, compounds, full-passage translations, answers and manifest v6.")
print("NOTE: internal QA does not substitute for human source-level lexicographic verification.")
