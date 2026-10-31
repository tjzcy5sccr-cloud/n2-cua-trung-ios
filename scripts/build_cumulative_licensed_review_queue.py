#!/usr/bin/env python3
"""Construct an auditable source-only cumulative JLPT N5-N2 research catalog.

Only open-licensed OpenJLPT and Bunchaway are queried, pinned to immutable commits.
No item is approved for IPA use by this script. Four named textbook series are
independent learning TRACKS, not contents reprinted from those books.
Goal caps (6000 words, 1100 Kanji, 150 grammar) are planning targets rather
than official JLPT study lists; any optional N1 entries are clearly flagged.
"""
import collections
import csv
import hashlib
import io
import json
import re
import unicodedata
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/"research/licensed-cumulative-queue"
OUTPUT.mkdir(parents=True,exist_ok=True)
O_SHA="0d1d3410bec90bd4098a7c72de820543cb4f707c"
B_SHA="6b1e9248c5382949115ccf1f5e8846d0fc85d6ad"
O="https://raw.githubusercontent.com/evanclan/OpenJLPT/"+O_SHA+"/data/json/"
B="https://raw.githubusercontent.com/bunchaway/tu-dien-nhat-viet/"+B_SHA+"/final.csv"
LEVELS=["n5","n4","n3","n2","n1"]
COURSE_LEVELS=set(LEVELS[:4])
SERIES=["mimikara","shin-kanzen","sou-matome","speed-master"]
MAX={"vocab":6000,"kanji":1100,"grammar":150}
LICENSE="CC BY-SA 4.0"
HEADERS={"User-Agent":"N2-Cua-Trung-Licensed-Cumulative-Corpus/1.0"}

def fetch(url):
    req=urllib.request.Request(url,headers=HEADERS)
    with urllib.request.urlopen(req,timeout=120) as f:
        return f.read()

def norm(s):
    return unicodedata.normalize("NFKC",str(s or "")).strip()

def stable(*values):
    return hashlib.sha256("|".join(str(s) for s in values).encode("utf-8")).hexdigest()[:14]

def stringify(v):
    if isinstance(v,list):return "; ".join(map(str,v[:5]))
    return str(v or "")

def save_json(path,content):
    path.write_text(json.dumps(content,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def save_lines(path,items):
    with path.open("w",encoding="utf-8") as f:
        for item in items:
            f.write(json.dumps(item,ensure_ascii=False,separators=(",",":"))+"\n")

print("Fetching pinned OpenJLPT N5–N1 lists and open Japanese–Vietnamese dictionary…",flush=True)
source={}
source_counts={}
for cat in ("vocab","kanji","grammar"):
    source[cat]=[]
    for level in LEVELS:
        payload=json.loads(fetch(f"{O}{cat}/{level}.json"))
        assert isinstance(payload,list) and payload,(cat,level)
        source_counts[f"{cat}_{level}"]=len(payload)
        source[cat].extend((level,item) for item in payload)
print("OpenJLPT downloaded:",source_counts,flush=True)
heads={norm(x.get("word")) for _,x in source["vocab"]}|{norm(x.get("character")) for _,x in source["kanji"]}
# The dictionary has Vietnamese translations but no pronunciation. A headword
# match is evidence for a candidate meaning, never verification for homographs.
meanings=collections.defaultdict(set)
dict_rows=0
csv_bytes=fetch(B)
assert len(csv_bytes)>100000
for row in csv.reader(io.StringIO(csv_bytes.decode("utf-8-sig"),newline="")):
    dict_rows+=1
    if len(row)<2:continue
    word=norm(row[0]);vi=row[1].strip()
    if word in heads and 1<len(vi)<450 and not re.search(r"https?://|<[^>]*>",vi,re.I):
        meanings[word].add(vi)
print("Dictionary parsed:",dict_rows,"rows; matched",len(meanings),"spellings",flush=True)
del csv_bytes
chosen={}
all_unique={}
for cat in ("vocab","kanji","grammar"):
    unique={}
    for level,entry in source[cat]:
        if cat=="vocab":
            spelling=norm(entry.get("word"))
            reading=norm(entry.get("reading"))
            key=spelling+"|"+reading
            if not spelling or not reading:continue
            data={
                "word":spelling,"reading":reading,
                "englishGloss":entry.get("meanings",[])[:4],
                "originalJapaneseExampleCandidates":[
                    x.get("ja","") for x in entry.get("examples",[])[:2]
                    if isinstance(x,dict) and x.get("ja")
                ],
            }
            alias=spelling
        elif cat=="kanji":
            spelling=norm(entry.get("character"))
            key=spelling
            if len(spelling)!=1:continue
            data={
                "char":spelling,
                "on":entry.get("onyomi",[]),
                "kun":entry.get("kunyomi",[]),
                "englishGloss":entry.get("meanings",[])[:5]
            }
            alias=spelling
        else:
            spelling=norm(entry.get("pattern"))
            key=spelling
            if not spelling:continue
            data={"pattern":spelling,"englishGloss":stringify(entry.get("meaning"))}
            alias=""
        if key in unique:continue
        meaning=list(sorted(meanings.get(alias,())))
        flags=["manual_Japanese_Vietnamese_review_required"]
        if len(meaning)>1:flags.append("ambiguous_dictionary_headword")
        if not meaning:flags.append("no_Vietnamese_dictionary_headword_match")
        if level=="n1":flags.append("N1_extension_not_required_for_N2")
        unique[key]={
            "id":f"research-{cat[0]}-{stable(cat,key)}",
            "sourceLevel":level.upper(),
            "isN2OrLowerFoundation":level in COURSE_LEVELS,
            "sourceLicense":LICENSE,
            "sourceRepository":"evanclan/OpenJLPT",
            "translationSuggestionSource":"bunchaway/tu-dien-nhat-viet" if meaning else None,
            "reviewStatus":"candidate_only_not_approved",
            "canPublishInIPA":False,
            "qualityFlags":flags,
            "vietnameseCandidate":meaning[0] if len(meaning)==1 else "",
            "vietnameseAlternativeCount":len(meaning),
            **data
        }
    arr=list(unique.values())
    # Core N5–N2 before any N1-extension item, deterministic by source order.
    arr.sort(key=lambda x:(LEVELS.index(x["sourceLevel"].lower()),x["id"]))
    all_unique[cat]=arr
    target=MAX[cat]
    chosen[cat]=arr[:target] if len(arr)>=target else arr
    print(cat,"unique licensed:",len(arr),"selected source-only candidates:",len(chosen[cat]),flush=True)

# Balanced, independent review queues. A record belongs to exactly one track,
# but the source remains licensed open content and is never represented as
# publisher-authored material from named Japanese textbooks.
for cat,items in chosen.items():
    for ix,item in enumerate(items):
        key=item.get("word") or item.get("char") or item.get("pattern")
        track=SERIES[int(stable(cat,key),16)%len(SERIES)]
        item["learningTrackHint"]=track
        item["curriculumWeek"]=min(35,1+(ix*35)//max(1,len(items)))
        item["reviewChecklist"]=[
            "Check kana reading against trusted Japanese dictionary",
            "Confirm all Vietnamese senses and usage with Japanese context",
            "Check provenance, licensing and example alignment",
            "Add independently reviewed natural Japanese/Vietnamese example",
            "Only then mark reviewed in separate app pack"
        ]
    save_lines(OUTPUT/f"{cat}-source-only.jsonl",items)

weeks=[]
for week in range(1,36):
    ids={c:[x["id"] for x in chosen[c] if x["curriculumWeek"]==week] for c in chosen}
    weeks.append({"week":week,"ids":ids,"counts":{k:len(v) for k,v in ids.items()}})
save_json(OUTPUT/"35-week-review-index.json",{"description":"Audit queue only. Not learning content shipped to iPhone.","weeks":weeks})

summary={
 "schemaVersion":1,
 "status":"SOURCE_ONLY_UNREVIEWED",
 "not100PercentComplete":True,
 "notOfficialJLPTList":True,
 "target":{"vocabulary":MAX["vocab"],"kanji":MAX["kanji"],"grammar":MAX["grammar"]},
 "fullSourceUnique":{cat:len(rows) for cat,rows in all_unique.items()},
 "selectedCandidateCounts":{cat:len(rows) for cat,rows in chosen.items()},
 "candidateByLevel":{cat:dict(collections.Counter(x["sourceLevel"] for x in rows))
                    for cat,rows in chosen.items()},
 "candidateByTrack":{cat:dict(collections.Counter(x["learningTrackHint"] for x in rows))
                    for cat,rows in chosen.items()},
 "VietnameseDictionarySingleHeadwordCandidates":{
   cat:sum(bool(x["vietnameseCandidate"]) for x in rows)
   for cat,rows in chosen.items()
 },
 "matchedWithNoReadingVerification":True,
 "externalExpertVerifiedCount":0,
 "license":LICENSE,
 "sources":[
    {"repository":"evanclan/OpenJLPT","commit":O_SHA,"license":LICENSE},
    {"repository":"bunchaway/tu-dien-nhat-viet","commit":B_SHA,"license":LICENSE}
 ],
 "reminder":"N5-N2 constitutes the cumulative foundation; any N1 entries fill only optional stretch goals and are explicitly labeled. Publication requires individual review, no textbook copies.",
 "upstreamCounts":source_counts,
 "dictionaryRows":dict_rows,
 "output":"Research queue only: intentionally not referenced in project.yml or copied into IPA."
}
save_json(OUTPUT/"summary.json",summary)
print(json.dumps({k:summary[k] for k in ("selectedCandidateCounts","candidateByLevel","VietnameseDictionarySingleHeadwordCandidates")},ensure_ascii=False,indent=2),flush=True)
