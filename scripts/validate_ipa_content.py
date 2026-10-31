#!/usr/bin/env python3
"""Verify that the actual IPA contains all five full source-pack datasets.

Counting GitHub source is insufficient; previous IPA lost 75–80% of study data.
Run this on the newly packaged .ipa and fail release on any missing fields.
"""
import json
from pathlib import Path
from collections import Counter
from zipfile import ZipFile

ROOT=Path(__file__).resolve().parents[1]
IPA=ROOT/"N2_cua_Trung_unsigned.ipa"
FILES={
    "content.json": ROOT/"N2CuaTrung/Resources/content.json",
    "n2-expansion-01.json": ROOT/"content-packs/n2-expansion-01.json",
    "openjlpt-n2-core.json": ROOT/"content-packs/openjlpt-n2-core.json",
    "vn26-original-practice-01.json": ROOT/"content-packs/vn26-original-practice-01.json",
    "n2-reading-listening-02.json": ROOT/"content-packs/n2-reading-listening-02.json",
    "grammar-details.json": ROOT/"N2CuaTrung/Resources/grammar-details.json",
}
EXPECTED={"vocab":2002,"grammar":180,"kanji":471,"readings":74,"listening":70}
def main():
    if not IPA.is_file():raise SystemExit("IPA not found")
    sums=Counter()
    with ZipFile(IPA) as archive:
        for filename,source in FILES.items():
            matches=[n for n in archive.namelist()
                if n.startswith("Payload/N2CuaTrung.app/")
                and n.split("/")[-1]==filename
                and n.count("/")==2]
            assert len(matches)==1,(filename,matches)
            actual=archive.read(matches[0])
            raw=source.read_bytes()
            actual_json=json.loads(actual)
            source_json=json.loads(raw)
            # JSON normalization ensures full per-entry data and review metadata retained.
            assert actual_json==source_json, f"IPA file differs from source: {filename}"
            if filename=="grammar-details.json":
                assert len(actual_json)>=50
                continue
            for key in EXPECTED:
                sums[key]+=len(actual_json.get(key,[]))
            for key in ("vocab","grammar","kanji"):
                assert all("id" in x for x in actual_json.get(key,[]))
            print("Verified IPA:",filename,{k:len(actual_json.get(k,[])) for k in EXPECTED},flush=True)
    assert dict(sums)==EXPECTED,f"IPA lost learning content: {dict(sums)} expected {EXPECTED}"
    print("PASS: IPA FULL N2 DATASET",dict(sums),flush=True)

if __name__=="__main__":
    main()
