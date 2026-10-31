#!/usr/bin/env python3
"""Inspect reusable Vietnamese/Japanese lexicon structure without importing unreviewed meanings."""
import csv
import io
import urllib.request
from pathlib import Path
import json

URL="https://raw.githubusercontent.com/bunchaway/tu-dien-nhat-viet/main/final.csv"
ROOT=Path(__file__).resolve().parents[1]
request=urllib.request.Request(URL,headers={"User-Agent":"N2-Cua-Trung-Research/1.0"})
with urllib.request.urlopen(request,timeout=65) as response:
    sample=response.read(32768).decode("utf-8-sig",errors="replace")
reader=csv.reader(io.StringIO(sample))
rows=[]
for index,row in enumerate(reader):
    if index>6:break
    rows.append({"columns":len(row),"values":[v[:200] for v in row[:9]]})
info={"source":URL,"licenseClaim":"CC BY-SA 4.0 (upstream README)","sample":rows,"notForApp":True}
out=ROOT/"qa-reports/vietnamese-lexicon-source-format.json"
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(info,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(info,ensure_ascii=False,indent=2))
