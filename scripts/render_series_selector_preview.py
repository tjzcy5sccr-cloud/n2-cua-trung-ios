#!/usr/bin/env python3
"""Visual approval mockup for multi-series selection in the existing N2 iOS app.

This is a code-grounded mockup, NOT a device screenshot or claim that Swift compiled.
"""
import json
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"qa-reports/series-selector-preview.png"
OUT.parent.mkdir(exist_ok=True,parents=True)
packs={}
keys=["mimikara","shin-kanzen","sou-matome","speed-master"]
for key in keys:
    packs[key]=json.loads((ROOT/f"content-packs/n2-series-{key}.json").read_text(encoding="utf-8"))
labels={"all":"Tổng hợp N2","mimikara":"Mimikara Oboeru","shin-kanzen":"Shin Kanzen Master","sou-matome":"Nihongo Sou Matome","speed-master":"Speed / Kanji Master"}
descs={"all":"Toàn bộ kho học hiện có","mimikara":"Từ vựng và nghe trong ngữ cảnh","shin-kanzen":"Phân tích ngữ pháp và Kanji","sou-matome":"Học theo ngày và tuần","speed-master":"Kanji và phản xạ nhanh"}
source=json.loads((ROOT/"N2CuaTrung/Resources/content.json").read_text(encoding="utf-8"))
total={key:sum(len(v[k]) for k in ("vocab","grammar","kanji","readings","listening")) for key,v in packs.items()}
colors={"bg":"#EDF3FA","blue":"#3458B8","navy":"#192A4F","teal":"#128E80","border":"#D3E1F2","white":"#FFFFFF","grey":"#66748B"}
W,H=1550,1130
im=Image.new("RGB",(W,H),colors["bg"]);d=ImageDraw.Draw(im)
def font(n,bold=False):
    dirs=["/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc" if bold else "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc","/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
    for p in dirs:
        try:
            if Path(p).exists():return ImageFont.truetype(p,n)
        except Exception:pass
    return ImageFont.load_default()
f14=font(14);f16=font(16);f19=font(19);f21=font(21,True);f25=font(25,True);f32=font(32,True)
def t(v,x,y,f,c="navy"):
    d.text((x,y),str(v),font=f,fill=colors.get(c,c))
def box(x1,y1,x2,y2,fill="white",radius=18,stroke=None):
    d.rounded_rectangle((x1,y1,x2,y2),radius=radius,fill=colors.get(fill,fill),outline=colors.get(stroke,stroke) if stroke else None,width=2 if stroke else 1)
def width(v,f):return d.textbbox((0,0),v,font=f)[2]
def wrap(value,f,maxw):
    words=value.split(" ");rows=[];line=""
    for word in words:
        phrase=(line+" "+word).strip()
        if line and width(phrase,f)>maxw:rows.append(line);line=word
        else:line=phrase
    if line:rows.append(line)
    return rows
def phone(x,selected):
    y=193
    box(x,y,x+540,y+867,"white",40,"border")
    box(x+194,y+10,x+340,y+34,"navy",18)
    t("9:41",x+34,y+23,f16)
    t("Chọn bộ học N2",x+150,y+69,f21)
    t("Bộ dữ liệu học",x+24,y+126,f25)
    t("Đổi nội dung mà không cài app mới",x+24,y+168,f16,"grey")
    box(x+21,y+211,x+519,y+281,"#F3F8FD",14)
    t("ĐANG HỌC",x+40,y+219,f14,"grey")
    t(labels[selected],x+40,y+244,f21,"teal")
    opts=["all"]+keys
    row_y=y+299
    for i,key in enumerate(opts):
        top=row_y+i*96
        active=key==selected
        box(x+22,top,x+518,top+84,"#E6F6F1" if active else "white",15,"teal" if active else "border")
        d.ellipse((x+36,top+23,x+62,top+49),outline=colors["teal"] if active else colors["grey"],width=3)
        if active:d.ellipse((x+44,top+31,x+54,top+41),fill=colors["teal"])
        t(labels[key],x+79,top+12,f21,"navy")
        t(descs[key],x+79,top+44,f14,"grey")
        if key!="all":count=f"{total[key]} mục"
        else:count="Tất cả"
        t(count,x+392,top+50,f14,"blue")
    t("Mỗi bộ có JSON riêng • Lưu tiến độ",x+26,y+805,f16,"grey")
    # 2 rows for count table, separate from phone
    tx=x+15
    if selected!="all":
        pack=packs[selected]
        t("Dữ liệu khi chọn "+labels[selected]+":",tx,y+883,f16,"navy")
        t(f"{len(pack['vocab'])} từ  •  {len(pack['grammar'])} ngữ pháp  •  {len(pack['kanji'])} Kanji  •  {len(pack['readings'])} đọc  •  {len(pack['listening'])} nghe",tx,y+916,f19,"blue")
    else:
        t("Tổng hợp: giữ nguyên mọi gói học cũ",tx,y+883,f16,"navy")
        t("Không xóa từ, Kanji, ví dụ hay tiến độ",tx,y+916,f19,"blue")
t("N2 CỦA TRUNG — CHỌN BỘ HỌC TRONG IPA CŨ",86,43,f32)
t("ẢNH MINH HỌA TỪ MÃ NGUỒN • KHÔNG PHẢI ẢNH CHỤP ỨNG DỤNG",87,100,f19,"#AC3540")
t("Commit: "+os.environ.get("GITHUB_SHA","mã nguồn hiện tại")[:16]+" • Chưa build IPA",87,139,f16,"blue")
phone(158,"all")
phone(853,"shin-kanzen")
box(93,1102,1460,1129,"white",11)
t("Các tên sách chỉ mô tả hướng học. Mỗi gói là nội dung riêng do N2 của Trung tuyển chọn; không phải dữ liệu chính thức của nhà xuất bản.",102,1107,f14)
im.save(OUT,optimize=True)
print("PREVIEW:",OUT)
