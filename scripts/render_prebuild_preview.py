#!/usr/bin/env python3
"""Source-grounded layout mockup shown BEFORE approving any iOS IPA build.

Not an actual iPhone simulator screenshot; the image is explicitly marked
as a layout mockup. The source code, not this PNG, remains authoritative.
"""
import json
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa-reports/prebuild-preview.png"
META = ROOT / "qa-reports/prebuild-preview.json"
OUT.parent.mkdir(parents=True, exist_ok=True)
PALE = "#F2F7FF"
NAVY = "#172647"
BLUE = "#355CBA"
TEAL = "#099488"
ORANGE = "#F78A3D"
RED = "#D92C3E"
GRAY = "#66728A"
WHITE = "#FFFFFF"
BG = "#E8EFF9"
WIDTH, HEIGHT = 1748, 1325

def font(size, bold=False):
    fonts = [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc" if bold else "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" if bold else "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for p in fonts:
        try:
            if Path(p).exists(): return ImageFont.truetype(p,size)
        except Exception: pass
    return ImageFont.load_default()

F11, F14, F17, F19 = (font(x) for x in [11,14,17,19])
F22, F28, F36 = (font(x,True) for x in [22,28,36])
F45, F69 = (font(x,True) for x in [45,69])
F16B=font(16,True)

def tw(d,t,f): return d.textbbox((0,0),t,font=f)[2]
def center(d,t,y,f,color,x,w): d.text((x+(w-tw(d,t,f))/2,y),t,fill=color,font=f)
def wrap(d,text,f,max_width):
    result=[];line=""
    for c in text:
        if c=="\n":
            result.append(line);line="";continue
        if tw(d,line+c,f)>max_width and line:
            result.append(line);line=c
        else:line+=c
    if line:result.append(line)
    return result
def lines(d,t,x,y,f,c,w,step=28,max_lines=5,centered=False):
    for line in wrap(d,t,f,w)[:max_lines]:
        dx=x+(w-tw(d,line,f))/2 if centered else x
        d.text((dx,y),line,font=f,fill=c);y+=step
    return y
def pill(d,box,t,fg,bg,font_obj=F14):
    d.rounded_rectangle(box,radius=12,fill=bg)
    x0,y0,x1,y1=box
    center(d,t,y0+7,font_obj,fg,x0,x1-x0)
def button(d,x,y,w,label,color):
    d.rounded_rectangle((x,y,x+w,y+48),radius=12,fill=color)
    center(d,label,y+11,F17,WHITE,x,w)

def data():
    p=ROOT/"content-packs/openjlpt-n2-core.json"
    if not p.exists():return ("相変わらず","あいかわらず","vẫn như trước, không thay đổi",
        "君は相変わらず健康そうに見える。","Trông bạn vẫn khỏe mạnh như mọi khi.",
        "安","an, yên ổn","〜に際して","khi, nhân dịp")
    d=json.loads(p.read_text(encoding="utf-8"))
    vetted={"editorial_reviewed","source_verified","independently_verified"}
    v=next((v for v in d.get("vocab",[]) if v.get("meaningStatus") in vetted
            and v.get("exampleStatus") in vetted and v["word"] in v.get("example","")),None)
    if v is None:v=next(v for v in d["vocab"] if v.get("meaningStatus") in vetted)
    k=next((k for k in d.get("kanji",[]) if k.get("meaningStatus") in vetted),None)
    g=next((g for g in d.get("grammar",[]) if g.get("grammarStatus") in vetted),None)
    return (v["word"],v.get("reading",""),v.get("meaning",""),
            v.get("example",""),v.get("exampleVi",""),k["char"] if k else "安",
            k.get("meaning","") if k else "yên ổn",g.get("pattern","〜に際して") if g else "〜に際して",
            g.get("meaning","khi, nhân dịp") if g else "khi, nhân dịp")

image=Image.new("RGB",(WIDTH,HEIGHT),BG);d=ImageDraw.Draw(image)
word,reading,meaning,example,example_vi,kanji,kanji_vi,grammar,grammar_vi=data()
d.text((62,30),"N2 của Trung  •  Xem trước giao diện",font=F36,fill=NAVY)
d.text((65,83),"MINH HỌA BỐ CỤC TỪ MÃ NGUỒN  •  KHÔNG PHẢI ẢNH CHỤP ỨNG DỤNG THỰC TẾ",font=F17,fill=RED)
sha=os.environ.get("GITHUB_SHA","")
d.text((65,117),"Commit xem trước: "+(sha[:12] if sha else "Phiên bản nguồn hiện tại")+
       "  |  Phải duyệt hình trước khi build IPA",font=F16B,fill=BLUE)
cards=[("FLASHCARD • MẶT TRƯỚC","vocab-front"),("FLASHCARD • MẶT SAU","vocab-back"),
       ("KANJI • MẶT SAU","kanji"),("NGỮ PHÁP • MẶT SAU","grammar")]
for idx,(caption,typ) in enumerate(cards):
    x=38+idx*430;y=168;w=400;h=790
    d.rounded_rectangle((x+4,y+8,x+w+4,y+h+8),radius=31,fill="#D5DEEC")
    d.rounded_rectangle((x,y,x+w,y+h),radius=31,fill=PALE,outline="#CAD7E8",width=2)
    d.rounded_rectangle((x+130,y+10,x+270,y+37),radius=12,fill=NAVY)
    center(d,"9:41",y+17,F14,NAVY,x+10,70)
    d.text((x+28,y+64),caption,font=F19,fill=NAVY)
    d.text((x+28,y+96),"Chạm để lật  •  Vuốt 4 hướng",font=F14,fill=GRAY)
    if typ.startswith("vocab"):
        pill(d,(x+24,y+135,x+106,y+167),"1 / N2",BLUE,"#E4EBFE")
        if typ=="vocab-front":
            d.rounded_rectangle((x+20,y+196,x+w-20,y+482),radius=22,fill=WHITE,outline="#DBE9F0",width=2)
            center(d,word,y+270,F36,NAVY,x+25,w-50)
            center(d,"Chạm để lật",y+438,F14,GRAY,x+25,w-50)
        else:
            d.rounded_rectangle((x+20,y+196,x+w-20,y+482),radius=22,fill=WHITE,outline="#DBE9F0",width=2)
            center(d,word,y+211,F28,NAVY,x+25,w-50)
            center(d,reading,y+250,F17,BLUE,x+25,w-50)
            lines(d,meaning,x+35,y+288,F17,TEAL,w-70,23,2,True)
            d.line((x+40,y+346,x+w-40,y+346),fill="#DEE4EF",width=2)
            # Mặt sau: câu Nhật và nghĩa Việt cùng một mép trái; từ đang học màu đỏ.
            cursor=x+40; yy=y+359
            highlight_pos=example.find(word) if word else -1
            for n,ch in enumerate(example):
                cw=tw(d,ch,F17)
                if cursor+cw > x+w-40:
                    cursor=x+40; yy+=25
                if yy > y+402: break
                ink=RED if highlight_pos>=0 and highlight_pos<=n<highlight_pos+len(word) else NAVY
                d.text((cursor,yy),ch,font=F17,fill=ink)
                cursor+=cw
            lines(d,example_vi,x+40,y+420,F14,GRAY,w-80,19,2,False)
        button(d,x+22,y+536,170,"Tự chạy",TEAL);button(d,x+208,y+536,170,"Từ tiếp theo",BLUE)
        button(d,x+22,y+597,170,"Nghe từ",BLUE);button(d,x+208,y+597,170,"Nghe ví dụ",TEAL)
        button(d,x+22,y+658,170,"Chưa thuộc",ORANGE);button(d,x+208,y+658,170,"Đã thuộc",TEAL)
    elif typ=="kanji":
        d.rounded_rectangle((x+20,y+135,x+w-20,y+421),radius=22,fill=WHITE,outline="#F6DCC7",width=2)
        center(d,kanji,y+166,F69,NAVY,x+25,w-50)
        lines(d,kanji_vi,x+38,y+264,F19,TEAL,w-76,27,2,True)
        center(d,"Âm On / Kun  •  214 bộ thủ",y+358,F14,GRAY,x+25,w-50)
        button(d,x+22,y+495,356,"Luyện Kanji",BLUE)
        button(d,x+22,y+566,170,"Nghe từ ghép",BLUE);button(d,x+208,y+566,170,"Dừng âm thanh",NAVY)
        button(d,x+22,y+636,170,"Chưa thuộc",ORANGE);button(d,x+208,y+636,170,"Đã thuộc",TEAL)
    else:
        d.rounded_rectangle((x+20,y+135,x+w-20,y+421),radius=22,fill=WHITE,outline="#D4E2F8",width=2)
        lines(d,grammar,x+36,y+187,F28,NAVY,w-72,36,3,True)
        lines(d,grammar_vi,x+36,y+277,F19,TEAL,w-72,30,3,True)
        center(d,"Vuốt 4 hướng để đổi mẫu",y+375,F14,GRAY,x+25,w-50)
        button(d,x+22,y+495,356,"Xem đầy đủ ví dụ",BLUE)
        button(d,x+22,y+566,356,"Nghe ví dụ",BLUE)
        button(d,x+22,y+636,170,"Chưa thuộc",ORANGE);button(d,x+208,y+636,170,"Đã thuộc",TEAL)
    center(d,caption,y+h+22,F16B,NAVY,x,w)
# Dải xem trước cho widget Medium dài ngang và Live Activity trên màn hình khóa.
d.text((64,1010),"WIDGET NGANG MEDIUM  •  LIVE ACTIVITY 3 GIÂY (KHI MỞ APP)",font=F22,fill=NAVY)
x1,y1,x2,y2=64,1055,800,1240
d.rounded_rectangle((x1,y1,x2,y2),radius=25,fill="#093B23")
d.text((x1+22,y1+15),"☘ N2 CỦA TRUNG",font=F17,fill=WHITE)
d.text((x1+22,y1+61),word,font=F36,fill=WHITE)
d.text((x1+22,y1+116),reading,font=F19,fill="#B2F7BC")
d.line((x1+365,y1+55,x1+365,y2-25),fill="#689A7F",width=2)
lines(d,meaning,x1+394,y1+71,F22,WHITE,315,32,3,False)
d.text((x1+22,y2-29),"WidgetKit: iOS quy định chu kỳ cập nhật • không phải 3 giây",font=F14,fill="#B2F7BC")
x1,y1,x2,y2=845,1055,1685,1240
d.rounded_rectangle((x1,y1,x2,y2),radius=26,fill=WHITE,outline="#D0DCEA",width=2)
d.text((x1+25,y1+15),"LIVE ACTIVITY MÀN HÌNH KHÓA",font=F17,fill=NAVY)
d.text((x1+25,y1+51),"Tự động đổi từ",font=F19,fill=NAVY)
for idx,(label,fill) in enumerate([("Tắt","#DFE5EF"),("3 giây",TEAL),("30 giây","#DFE5EF"),("60 giây","#DFE5EF")]):
    px=x1+24+idx*195
    pill(d,(px,y1+89,px+178,y1+128),label,WHITE if idx==1 else NAVY,fill,F17)
d.text((x1+25,y2-30),"3 giây chỉ là thử nghiệm khi app mở; iOS có thể giới hạn khi khóa màn hình.",font=F14,fill=GRAY)
d.rounded_rectangle((56,1270,WIDTH-56,1313),radius=15,fill="#FFFFFF")
center(d,"HÌNH MÔ PHỎNG TỪ MÃ NGUỒN • DUYỆT TRƯỚC KHI BUILD IPA",1279,F16B,BLUE,56,WIDTH-112)
image.save(OUT,optimize=True)
META.write_text(json.dumps({"commit":sha,"kind":"source_based_layout_mockup",
    "notSimulatorScreenshot":True,"screens":["vocabulary-front","vocabulary-back","kanji","grammar","medium-widget","live-activity"],
    "previewImage":"qa-reports/prebuild-preview.png"},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("PREVIEW CREATED:",OUT,WIDTH,"x",HEIGHT)
