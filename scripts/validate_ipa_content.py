#!/usr/bin/env python3
"""Verify the signed-off IPA contains the complete APPROVED bundle, no pending entries.

Source-only research content is intentionally NOT shipped. Cross-check all nine
JSON datasets after the build-time pruning and every new batch-01 item.
"""
import json
from pathlib import Path
from collections import Counter
from zipfile import ZipFile

ROOT=Path(__file__).resolve().parents[1]
IPA=ROOT/"N2_cua_Trung_unsigned.ipa"
BASE=ROOT/"content-packs"
FILES={
 "content.json":ROOT/"N2CuaTrung/Resources/content.json",
 **{f"{name}.json":BASE/f"{name}.json" for name in (
  "n2-expansion-01","openjlpt-n2-core","vn26-original-practice-01",
  "n2-reading-listening-02","n2-series-mimikara","n2-series-shin-kanzen",
  "n2-series-sou-matome","n2-series-speed-master")},
 "grammar-details.json":ROOT/"N2CuaTrung/Resources/grammar-details.json",
}
APPROVED={"editorial_reviewed","source_verified","independently_verified"}
CATS=("vocab","grammar","kanji","readings","listening")

def main():
    assert IPA.is_file(), "unsigned IPA not found"
    totals=Counter()
    original_approved=set()
    with ZipFile(IPA) as archive:
        names=archive.namelist()
        for filename,path in FILES.items():
            matches=[n for n in names if n.startswith("Payload/N2CuaTrung.app/")
                     and n.split("/")[-1]==filename and n.count("/")==2]
            assert len(matches)==1,(filename,matches)
            ipa_obj=json.loads(archive.read(matches[0]))
            local_obj=json.loads(path.read_text(encoding="utf-8"))
            assert ipa_obj==local_obj,(filename,"IPA not equal to approved build resource")
            if filename=="grammar-details.json":
                assert ipa_obj=={}, "Unreviewed grammar extras leaked into IPA"
                continue
            for cat in CATS:
                entries=ipa_obj.get(cat,[])
                totals[cat]+=len(entries)
                if cat in ("vocab","grammar","kanji"):
                    status="grammarStatus" if cat=="grammar" else "meaningStatus"
                    assert all(x.get(status) in APPROVED for x in entries),(filename,cat)
                    if cat=="vocab":
                        assert all(x.get("exampleStatus") in APPROVED or
                                   (not x.get("example") and not x.get("exampleVi")) for x in entries)
                    if cat=="grammar":
                        assert all(x.get("translationStatus") in APPROVED or
                                   (not x.get("example") and not x.get("translation")) for x in entries)
                for item in entries:
                    if item["id"].startswith("trung-original-"):
                        original_approved.add(item["id"])
            print("Verified bundle:",filename,{k:len(ipa_obj.get(k,[])) for k in CATS})
    assert len(original_approved)==74,("new original entries missing",len(original_approved))
    assert totals["vocab"]>=100 and totals["kanji"]>=30 and totals["grammar"]>=40,totals
    print("PASS: IPA approved-only data verified, with 74 unique original new lesson items.",dict(totals))

if __name__=="__main__":
    main()
