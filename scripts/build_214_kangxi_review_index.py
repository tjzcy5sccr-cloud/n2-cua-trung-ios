#!/usr/bin/env python3
"""Source-only 214 Kangxi radical index, Unicode order, no invented VN meanings.

Unicode Kangxi Radical characters U+2F00 through U+2FD5 correspond to
214 radicals. NFKC maps the compatibility radical to its base ideograph.
Vietnamese Hán-Việt names must be checked independently before app usage.
"""
import json
import unicodedata
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"research/licensed-cumulative-queue/214-radicals-source-only.json"
items=[]
for number,codepoint in enumerate(range(0x2F00,0x2FD6),1):
    radical=chr(codepoint)
    base=unicodedata.normalize("NFKC",radical)
    assert radical!=base and len(base)==1,(number,radical,base)
    items.append({
        "number":number,
        "kangxiRadicalSymbol":radical,
        "baseIdeograph":base,
        "unicodeName":unicodedata.name(radical),
        "hanVietMeaning":None,
        "vietnameseMeaning":None,
        "reviewStatus":"pending_manual_han_viet_review",
        "canPublishInIPA":False
    })
assert len(items)==214 and len({v["baseIdeograph"] for v in items})==214
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_text(json.dumps({
    "count":214,
    "source":"Unicode Kangxi Radicals U+2F00–U+2FD5, NFKC mapping",
    "description":"Complete numbered Unicode source index, NOT a verified 214 Vietnamese Hán–Việt meaning list",
    "notReviewed":True,
    "entries":items
},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("PASS: 214 Unicode Kangxi radicals indexed without guessing Vietnamese meanings.")
