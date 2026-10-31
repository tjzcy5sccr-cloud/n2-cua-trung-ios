#!/usr/bin/env python3
"""Idempotently import batch02 original JLPT N2 study material into four named tracks.

Names Mimikara, Shin Kanzen, Sou Matome, Speed/Kanji Master indicate learning
approaches, NOT copies of books or official publisher datasets.
The lesson JSON is original Japanese/Vietnamese content held by N2 Cua Trung.
Review tags indicate internal editorial work, not external expert certification.
"""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/"content-packs"
SRC=ROOT/"research/original-batch-02/lessons.json"
APPROVED="editorial_reviewed"
NAMES=["mimikara","shin-kanzen","sou-matome","speed-master"]
KINDS=("vocab","grammar","kanji","readings","listening")
PREFIX={"vocab":"v","grammar":"g","kanji":"k","readings":"r","listening":"l"}

def load(path):
    return json.loads(path.read_text(encoding="utf-8"))

def write(path,data):
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def main():
    data=load(SRC)
    assert data["schemaVersion"]==1 and set(data["series"])==set(NAMES)
    manifest_path=BASE/"manifest-series.json"
    manifest=load(manifest_path)
    existing={}
    for name in NAMES:
        path=BASE/f"n2-series-{name}.json"
        existing[name]=(path,load(path))
    seen_words={x["word"] for _,pack in existing.values() for x in pack["vocab"]}
    seen_grammar={x["pattern"] for _,pack in existing.values() for x in pack["grammar"]}
    seen_kanji={x["char"] for _,pack in existing.values() for x in pack["kanji"]}
    seen_ids={kind:{x["id"] for _,pack in existing.values() for x in pack[kind]}
              for kind in KINDS}
    totals={kind:0 for kind in KINDS}
    by_series={}
    changed=False
    for name in NAMES:
        path,pack=existing[name]
        lessons=data["series"][name]
        assert len(lessons["vocab"])==16 and len(lessons["grammar"])==3
        assert len(lessons["kanji"])==4
        assert len(lessons["readings"])==1 and len(lessons["listening"])==1
        added={kind:0 for kind in KINDS}
        for kind in KINDS:
            for seq,values in enumerate(lessons[kind],1):
                ident=f"trung-original-b02-{PREFIX[kind]}-{name}-{seq:03d}"
                if ident in seen_ids[kind]:
                    # Running this importer more than once must be harmless.
                    assert any(x["id"]==ident for x in pack[kind]),("Conflict",ident)
                    continue
                if kind=="vocab":
                    word,reading,meaning,jp,vi=values
                    assert all((word,reading,meaning,jp,vi)),("Empty vocab",name,word)
                    assert word not in seen_words,("Duplicated word",name,word)
                    # Inflected predicates need a stem instead of exact dictionary form.
                    assert word in jp or (len(word)>1 and word[:-1] in jp),("Unrelated example",word,jp)
                    value=dict(id=ident,word=word,reading=reading,meaning=meaning,
                               example=jp,exampleVi=vi,topic="Học liệu N2 tự biên soạn · "+name,
                               week=10+(seq-1)//2,meaningStatus=APPROVED,
                               meaningSource="Biên tập Nhật–Việt nội bộ; không phải dữ liệu sách",
                               exampleStatus=APPROVED)
                    seen_words.add(word)
                elif kind=="grammar":
                    pattern,meaning,rule,jp,vi,week=values
                    assert all((pattern,meaning,rule,jp,vi)),("Empty grammar",name)
                    assert pattern not in seen_grammar,("Duplicate grammar",pattern)
                    assert 1<=int(week)<=35
                    value=dict(id=ident,pattern=pattern,meaning=meaning,rule=rule,
                               example=jp,translation=vi,week=int(week),samples=[],
                               grammarStatus=APPROVED,translationStatus=APPROVED)
                    seen_grammar.add(pattern)
                elif kind=="kanji":
                    char,on,kun,meaning,related=values
                    assert len(char)==1 and related in seen_words and char in related,(char,related)
                    assert char not in seen_kanji,("Duplicated Kanji",char)
                    value=dict(id=ident,char=char,on=on,kun=kun,meaning=meaning,
                               word=related,meaningStatus=APPROVED)
                    seen_kanji.add(char)
                else:
                    assert isinstance(values,dict) and all(
                        values.get(k) for k in ("title","question","choices","explanation"))
                    assert len(values["choices"])==4
                    assert len(set(values["choices"]))==4,("Duplicate answer options",name)
                    assert 0<=values["answer"]<4
                    key="textVi" if kind=="readings" else "scriptVi"
                    assert values.get(key),("Missing full Vietnamese translation",name,kind)
                    assert len(values.get("text","") or values.get("script",""))>=75
                    value=dict(values,id=ident)
                pack[kind].append(value)
                seen_ids[kind].add(ident)
                totals[kind]+=1
                added[kind]+=1
        if any(added.values()):
            pack["version"]+=1
            write(path,pack)
            changed=True
        by_series[name]={"added":added,"version":pack["version"],
                         "total":{k:len(pack[k]) for k in KINDS}}
        record=next(x for x in manifest["packs"] if x["id"]==pack["id"])
        record["version"]=pack["version"]
    assert totals in (
        {"vocab":64,"grammar":12,"kanji":16,"readings":4,"listening":4},
        {kind:0 for kind in KINDS}),totals
    if changed:write(manifest_path,manifest)
    report={
        "batch":"n2-original-batch-02",
        "copyright":"Original example sentences, Vietnamese translations, reading passages and listening dialogues",
        "textbookCopy":False,
        "review":"Internal editorial review only, external dictionary verification pending",
        "notComplete100Percent":True,
        "added":totals,"series":by_series
    }
    output=ROOT/"qa-reports/n2-original-batch-02.json"
    output.parent.mkdir(exist_ok=True)
    write(output,report)
    print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=="__main__":
    main()
