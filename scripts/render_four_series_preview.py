#!/usr/bin/env python3
"""Build a clearly labeled *layout mockup* from the actual 4-series JSON syllabus.

This is not an iOS simulator screenshot or a replacement for device testing.
"""
import json
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
src = ROOT / "N2CuaTrung/Resources/n2-four-series-curriculum.json"
plan = json.loads(src.read_text(encoding="utf-8"))
week = plan["weeks"][0]
out = ROOT / "qa-reports/four-series-prebuild-preview.png"
out.parent.mkdir(parents=True, exist_ok=True)
W,H=1510,1050
image = Image.new("RGB", (W,H), "#EAF0FB")
d=ImageDraw.Draw(image)
dark="#192946";blue="#355AB5";green="#159281";gray="#657188";white="#FFFFFF";orange="#E7833B"
fontfiles=["/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc","/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc","/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
def ff(size,bold=False):
    for item in ([fontfiles[1],fontfiles[0],fontfiles[2]] if bold else [fontfiles[0],fontfiles[1],fontfiles[2]]):
        if Path(item).exists():
            try:return ImageFont.truetype(item,size)
            except OSError:pass
    return ImageFont.load_default()
f12=ff(12);f15=ff(15);f18=ff(18);f20=ff(20,True);f24=ff(24,True);f30=ff(30,True);f40=ff(40,True)
def text(t,x,y,f,c=dark):
    d.text((x,y),t,font=f,fill=c)
def width(t,f):
    box=d.textbbox((0,0),t,font=f);return box[2]-box[0]
def multiline(value,x,y,f,c,limit,spacing=26):
    line="";count=0
    for ch in value:
        if width(line+ch,f)>limit:
            text(line,x,y+count*spacing,f,c);count+=1;line=""
        line+=ch
    if line:text(line,x,y+count*spacing,f,c);count+=1
    return count
def box(x1,y1,x2,y2,fill,r=20,stroke=None):
    d.rounded_rectangle((x1,y1,x2,y2),radius=r,fill=fill,outline=stroke,width=2 if stroke else 1)
def phone(x):
    box(x,190,x+450,975,white,39,"#CAD5E8")
    box(x+160,201,x+289,225,dark,13)
    text("9:41",x+32,214,f15)
    text("‹",x+32,248,f30,blue)
    text("Chương trình N2",x+113,252,f20,dark)

text("N2 CỦA TRUNG • CHƯƠNG TRÌNH 4 HƯỚNG HỌC",70,55,f30,dark)
text("HÌNH MINH HỌA TỪ JSON + MÃ SWIFTUI — KHÔNG PHẢI ẢNH CHỤP IPHONE",72,107,f18,"#B83B47")
text("Commit: "+os.environ.get("GITHUB_SHA","branch preview")[:14]+" • Cần duyệt hình trước khi tạo IPA",73,140,f15,blue)
x1=230;x2=830
phone(x1); phone(x2)

# screen 1: overview
box(x1+25,296,x1+425,456,blue,21)
text("JLPT N2 • 2027",x1+44,312,f15,white)
text("4 hướng học",x1+44,337,f30,white)
text("1 lộ trình N2",x1+44,376,f30,white)
text("Mimikara • Shin Kanzen • Sou Matome",x1+44,426,f12,white)
text("MỤC TIÊU KIẾN THỨC",x1+28,475,f18,dark)
for j,(label,value) in enumerate([("Từ vựng",6000),("Kanji",1100),("Ngữ pháp",150)]):
    col=x1+25+j*136
    box(col,515,col+126,625,"#F0F5FD",12)
    text(label,col+9,532,f15,gray)
    text(f"{value:,}",col+9,565,f24,blue)
text("Mục tiêu ≠ số bài đã có trong kho",x1+30,643,f15,gray)
text("BỐN HƯỚNG HỌC",x1+27,679,f18,dark)
for j,track in enumerate(plan["tracks"]):
    y=715+j*50
    box(x1+25,y,x1+425,y+43,"#F1F7FC",12)
    text(track["name"],x1+39,y+10,f15,dark)

# screen 2: week 1
box(x2+25,297,x2+425,424,blue,20)
text("TUẦN 01 / 35",x2+43,315,f15,white)
text(week["theme"],x2+43,344,f20,white)
text(week["dateRange"],x2+43,381,f15,white)
text("Chỉ tiêu tuần",x2+30,448,f18,dark)
for j,(name,value) in enumerate([("Từ",week["targets"]["vocabulary"]),("Kanji",week["targets"]["kanji"]),("Mẫu",week["targets"]["grammar"])]):
    col=x2+25+j*136
    box(col,482,col+126,543,"#F1F6FE",12)
    text(f"{value} {name}",col+14,500,f18,blue)
text("NHIỆM VỤ TRONG TUẦN",x2+27,570,f18,dark)
for j,day in enumerate(week["days"]):
    y=605+j*48
    box(x2+26,y,x2+424,y+43,white,10,"#D6E0EC")
    d.ellipse((x2+39,y+13,x2+55,y+29),outline=green,width=2)
    text(day["day"]+" · "+day["primarySkill"],x2+69,y+12,f15,dark)
text("Chủ nhật: ôn nhẹ / nghỉ",x2+30,912,f15,gray)

box(70,1002,1440,1036,white,12)
text("Nguồn học: phương pháp tham khảo 4 bộ sách; bài luyện và lộ trình mới do dự án tự biên soạn.",86,1008,f15,dark)
image.save(out,optimize=True)
print("Created",out,"with",len(plan["weeks"]),"weeks and",sum(len(w["days"]) for w in plan["weeks"]),"daily entries")
