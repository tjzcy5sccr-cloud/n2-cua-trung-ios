#!/usr/bin/env python3
"""Promote ONLY individually reviewed open-data candidates into four N2 app packs.

No automatic translation, textbook scraping, or fake review flags. Reviewer must
supply explicit Japanese/Vietnamese context, evidence links and kana checking.
Default is --check; --apply must be explicitly supplied by a human.
"""
import argparse
import datetime
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
Q=ROOT/"research/licensed-cumulative-queue"
PACK=ROOT/"content-packs"
DECISIONS=Q/"editorial-decisions.jsonl"
KINDS={"vocab","kanji","grammar"}
SERIES={"mimikara","shin-kanzen","sou-matome","speed-master"}

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def save(path,value):
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def valid_text(value):
    return (isinstance(value,str) and len(value.strip())>=2
            and not value.strip().startswith(("EN ·","Chưa","TODO","TBD")))

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--apply",action="store_true",help="Update pack versions after manual review")
    parser.add_argument("--decisions",type=Path,default=DECISIONS)
    args=parser.parse_args()
    if not args.decisions.is_file():
        print("No editorial decisions file; 0 source-only candidates can be published.")
        return
    decisions=[json.loads(line) for line in args.decisions.read_text(encoding="utf-8").splitlines() if line.strip()]
    assert len({r["sourceId"] for r in decisions})==len(decisions),"Duplicate editorial decisions"
    source={}
    for kind in KINDS:
        for line in (Q/f"{kind}-source-only.jsonl").read_text(encoding="utf-8").splitlines():
            if line.strip():
                item=json.loads(line)
                source[item["id"]]=(kind,item)
    files={name:PACK/f"n2-series-{name}.json" for name in SERIES}
    packs={name:read_json(path) for name,path in files.items()}
    manifest=read_json(PACK/"manifest-series.json")
    old_keys={}
    for p in packs.values():
        for kind in KINDS:
            for row in p[kind]:
                key=((row.get("word"),row.get("reading")) if kind=="vocab"
                     else row.get("char") if kind=="kanji" else row.get("pattern"))
                old_keys.setdefault(kind,set()).add(key)
    additions={name:{kind:0 for kind in KINDS} for name in SERIES}
    for decision in decisions:
        ident=decision["sourceId"]
        assert ident in source,("Unknown source ID",ident)
        kind,item=source[ident]
        assert not item.get("canPublishInIPA")
        assert item["sourceLevel"]!="N1","N1 stretch item requires separate explicit enrichment scope"
        name=decision.get("series")
        assert name in SERIES and 1<=decision.get("week",0)<=35,(ident,name)
        assert decision.get("reviewStatus")=="editorial_reviewed"
        assert decision.get("kanaChecked") is True
        assert decision.get("contextChecked") is True
        assert valid_text(decision.get("reviewer"))
        date=datetime.date.fromisoformat(decision["reviewedOn"])
        assert date<=datetime.date.today()
        evidence=decision.get("sourceReferences")
        assert isinstance(evidence,list) and len(evidence)>=2 and all(
            isinstance(x,str) and x.startswith("https://") for x in evidence)
        assert valid_text(decision.get("meaningVi"))
        if kind=="vocab":
            assert all(valid_text(decision.get(k)) for k in ("exampleJa","exampleVi"))
            word=item["word"]
            jp=decision["exampleJa"]
            assert word in jp or (len(word)>1 and word[:-1] in jp),(ident,"not in example")
            key=(word,item["reading"])
            value=dict(id="trung-licensed-"+ident,word=word,reading=item["reading"],
                       meaning=decision["meaningVi"].strip(),
                       example=jp.strip(),exampleVi=decision["exampleVi"].strip(),
                       topic="N2 đã biên tập theo ngữ cảnh",week=decision["week"],
                       meaningStatus="editorial_reviewed",exampleStatus="editorial_reviewed",
                       meaningSource="; ".join(evidence))
        elif kind=="kanji":
            assert valid_text(decision.get("compoundWord"))
            assert item["char"] in decision["compoundWord"]
            key=item["char"]
            value=dict(id="trung-licensed-"+ident,char=item["char"],
                       on="、".join(item.get("on",[])),kun="、".join(item.get("kun",[])),
                       meaning=decision["meaningVi"].strip(),
                       word=decision["compoundWord"].strip(),
                       meaningStatus="editorial_reviewed")
        else:
            assert all(valid_text(decision.get(k)) for k in ("usageRuleVi","exampleJa","exampleVi"))
            key=item["pattern"]
            value=dict(id="trung-licensed-"+ident,pattern=item["pattern"],
                       meaning=decision["meaningVi"].strip(),
                       rule=decision["usageRuleVi"].strip(),
                       example=decision["exampleJa"].strip(),
                       translation=decision["exampleVi"].strip(),
                       week=decision["week"],samples=[],
                       grammarStatus="editorial_reviewed",translationStatus="editorial_reviewed")
        if key in old_keys[kind]:
            print("Already has item; do not duplicate:",kind,key)
            continue
        packs[name][kind].append(value)
        old_keys[kind].add(key)
        additions[name][kind]+=1
    total=sum(sum(v.values()) for v in additions.values())
    print(json.dumps({"newReviewedItems":total,"bySeries":additions,
                      "mode":"apply" if args.apply else "dry-run"},
                      ensure_ascii=False,indent=2))
    if not args.apply or not total:return
    for name,p in packs.items():
        if sum(additions[name].values()):
            p["version"]+=1
            save(files[name],p)
            next(x for x in manifest["packs"] if x["id"]==p["id"])["version"]=p["version"]
    save(PACK/"manifest-series.json",manifest)
    print("Committed work still requires QA tests; no IPA build has been triggered.")

if __name__=="__main__":
    main()
