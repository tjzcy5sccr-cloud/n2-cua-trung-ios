#!/usr/bin/env python3
"""Kiểm kê TẤT CẢ gói học JLPT N2; KHÔNG tự nhận là kiểm chứng nghĩa.

Ghi tệp qa-reports/n2-content-audit.json gồm trạng thái bản dịch từng câu, đủ để
chuyên gia rà soát từng mục với từ điển tiếng Nhật ở Việt Nam.
"""
import collections
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "qa-reports" / "n2-content-audit.json"
SOURCES = [
    ("bundled", ROOT / "N2CuaTrung/Resources/content.json"),
    ("openjlpt-n2-core", ROOT / "content-packs/openjlpt-n2-core.json"),
    ("n2-expansion-01", ROOT / "content-packs/n2-expansion-01.json"),
    ("vn26-original-practice-01", ROOT / "content-packs/vn26-original-practice-01.json"),
    ("n2-reading-listening-02", ROOT / "content-packs/n2-reading-listening-02.json"),
]
BAD_FRAGMENTS = ("_BAR_", "******", "Gova a i", "m Bobbiet", "Và đây là một ví dụ khác")
rows = []
stats = collections.Counter()
def add(pack, section, key, japanese, translation, status, reason, title=""):
    if not japanese:
        return
    translation = translation or ""
    actual = status or "legacy_not_individually_audited"
    if not translation.strip() or any(x in translation for x in BAD_FRAGMENTS):
        actual = "missing_or_corrupt"
    if actual == "editorial_reviewed":
        stats["editorial_reviewed"] += 1
    elif actual in ("source_verified", "independently_verified"):
        stats["source_verified"] += 1
    else:
        stats["pending_individual_verification"] += 1
    rows.append(dict(pack=pack, section=section, id=key, title=title, japanese=japanese,
                     translation=translation, status=actual, notes=reason))
for label, file in SOURCES:
    content = json.loads(file.read_text(encoding="utf-8"))
    for v in content.get("vocab", []):
        add(label, "vocab.meaning", v["id"], v.get("word"), v.get("meaning"),
            v.get("meaningStatus"), "Khớp chữ Nhật, kana và ngữ cảnh với Mazii/Jdict",v.get("reading",""))
        add(label, "vocab.example", v["id"], v.get("example"), v.get("exampleVi"),
            v.get("exampleStatus"), "Dịch toàn câu; tránh dịch từng Kanji",v.get("word",""))
    for g in content.get("grammar", []):
        add(label, "grammar.meaning",g["id"],g.get("pattern"),g.get("meaning"),
            g.get("grammarStatus"),"Cấu trúc + điều kiện + sắc thái",g.get("pattern",""))
        add(label, "grammar.primary_example",g["id"],g.get("example"),g.get("translation"),
            g.get("translationStatus"),"Đối chiếu nội dung câu chính",g.get("pattern",""))
        for i,s in enumerate(g.get("samples",[])):
            add(label,"grammar.extra_example",f'{g["id"]}:{i}',s.get("text"),s.get("translation"),
                s.get("translationStatus"),"Đối chiếu câu phụ ngữ pháp",g.get("pattern",""))
    for k in content.get("kanji", []):
        add(label,"kanji.meaning",k["id"],k.get("char"),k.get("meaning"),
            k.get("meaningStatus"),"Phân biệt nghĩa chữ và bộ thủ; xác minh âm Hán–Việt")
    for category in ("readings", "listening"):
        for item in content.get(category, []):
            add(label,category+".explanation",item["id"],item.get("text") or item.get("script"),
                item.get("explanation"),item.get("translationStatus"),
                "Kiểm đáp án đúng, giải thích và bản dịch đoạn; không xem lời giải là bản dịch toàn đoạn",item.get("title",""))
# Các ví dụ phụ trong grammar-details gốc lưu ở tệp riêng.
details = ROOT / "N2CuaTrung/Resources/grammar-details.json"
if details.exists():
    data = json.loads(details.read_text(encoding="utf-8"))
    for key,val in data.items():
        for i,ex in enumerate(val.get("extra",[])):
            add("bundled-grammar-details","grammar.extra_example",f"{key}:{i}",
                ex.get("text"),ex.get("translation"),ex.get("translationStatus"),
                "Duyệt ví dụ phụ trong bộ ngữ pháp gốc",key)
REPORT.parent.mkdir(parents=True,exist_ok=True)
REPORT.write_text(json.dumps({
  "purpose":"Danh sách cần kiểm duyệt, không phải chứng nhận 100% chính xác",
  "prioritySources":["https://mazii.net/vi-VN","https://jdict.net/","https://kanji.vn/","https://jlptvietnam.com"],
  "summary":dict(stats),"entries":rows
},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("FULL COURSE AUDIT:",len(rows),"fields.",dict(stats))
print("Report:",REPORT)
