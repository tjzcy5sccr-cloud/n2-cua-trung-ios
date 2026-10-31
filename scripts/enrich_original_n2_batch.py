#!/usr/bin/env python3
"""Add independently written JLPT N2 practice to the four N2 Cua Trung series.

No examples or textbook lists are transcribed. Entries below are originally
authored for the app; "editorial_reviewed" denotes internal language editing,
NOT publisher verification, JLPT endorsement, or a 100% correctness warranty.
The script is idempotent and preserves all existing IDs/progress records.
"""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/"content-packs"
SERIES=("mimikara","shin-kanzen","sou-matome","speed-master")

# word|reading|Vietnamese context meaning|original Japanese sentence|original Vietnamese translation
VOCAB={
"mimikara":"""
締め切り|しめきり|hạn cuối|申し込みの締め切りは来週です。|Hạn cuối đăng ký là tuần sau.
負担|ふたん|gánh nặng; sự chịu đựng|この仕事は一人では負担が大きすぎます。|Công việc này quá nặng nếu chỉ một người đảm nhiệm.
不足|ふそく|sự thiếu hụt|説明が不足しているため、もう一度確認します。|Vì phần giải thích chưa đầy đủ nên tôi sẽ kiểm tra lại.
指摘|してき|sự chỉ ra; góp ý về vấn đề|先生から発音の間違いを指摘されました。|Giáo viên đã chỉ ra lỗi phát âm của tôi.
事前|じぜん|trước đó; trước khi diễn ra|事前に必要な情報を調べておきます。|Tôi sẽ tìm hiểu trước những thông tin cần thiết.
役割|やくわり|vai trò|会議でそれぞれの役割を決めました。|Trong cuộc họp, chúng tôi đã phân chia vai trò cho từng người.
詳細|しょうさい|thông tin chi tiết|予定の詳細はメールで送ります。|Tôi sẽ gửi chi tiết lịch trình qua email.
条件|じょうけん|điều kiện|参加する条件を確認してください。|Vui lòng kiểm tra điều kiện tham gia.
表現|ひょうげん|cách diễn đạt; biểu đạt|この表現は会話でよく使われます。|Cách diễn đạt này thường được dùng trong hội thoại.
解決|かいけつ|giải quyết|問題を解決する方法を考えましょう。|Hãy nghĩ cách giải quyết vấn đề.
見直す|みなおす|xem lại; đánh giá lại|試験の前に間違えた問題を見直します。|Trước kỳ thi tôi sẽ xem lại những câu đã làm sai.
窓口|まどぐち|quầy tiếp nhận; đầu mối liên hệ|質問があれば受付窓口に相談してください。|Nếu có thắc mắc, vui lòng hỏi tại quầy tiếp nhận.
""",
"shin-kanzen":"""
不具合|ふぐあい|sự cố; trục trặc|アプリに不具合が見つかりました。|Đã phát hiện lỗi trong ứng dụng.
手続き|てつづき|thủ tục|住所を変更する手続きが必要です。|Cần làm thủ tục đổi địa chỉ.
優先順位|ゆうせんじゅんい|thứ tự ưu tiên|仕事の優先順位を決めましょう。|Hãy xác định thứ tự ưu tiên công việc.
注意事項|ちゅういじこう|những điều cần lưu ý|申し込む前に注意事項を読んでください。|Vui lòng đọc những điều cần lưu ý trước khi đăng ký.
合意|ごうい|sự đồng thuận; thỏa thuận|両社は新しい条件で合意しました。|Hai công ty đã đạt được thỏa thuận về điều kiện mới.
対象|たいしょう|đối tượng áp dụng|この割引は学生が対象です。|Chương trình giảm giá này áp dụng cho sinh viên.
実施|じっし|thực hiện; triển khai|来月から新しい制度を実施します。|Từ tháng sau chúng tôi sẽ triển khai chế độ mới.
検討|けんとう|xem xét; cân nhắc|その提案について検討します。|Chúng tôi sẽ xem xét đề xuất đó.
方針|ほうしん|phương hướng; chính sách|今後の方針を会議で決めます。|Chúng tôi sẽ quyết định phương hướng sắp tới trong cuộc họp.
規則|きそく|quy tắc; quy định|学校の規則を守りましょう。|Hãy tuân thủ nội quy nhà trường.
契約|けいやく|hợp đồng; ký kết|契約の内容をよく確認してください。|Vui lòng kiểm tra kỹ nội dung hợp đồng.
責任|せきにん|trách nhiệm|担当者には結果を説明する責任があります。|Người phụ trách có trách nhiệm giải thích kết quả.
""",
"sou-matome":"""
提出期限|ていしゅつきげん|hạn nộp|レポートの提出期限は月曜日です。|Hạn nộp báo cáo là thứ Hai.
振り返る|ふりかえる|nhìn lại; ôn lại|一週間の学習を振り返ります。|Tôi nhìn lại việc học trong một tuần.
調査|ちょうさ|khảo sát; điều tra|利用者の意見を調査しています。|Chúng tôi đang khảo sát ý kiến của người dùng.
経費|けいひ|chi phí hoạt động|出張にかかった経費をまとめました。|Tôi đã tổng hợp chi phí phát sinh trong chuyến công tác.
記録|きろく|ghi chép; bản ghi|毎日の勉強時間を記録します。|Tôi ghi lại thời gian học mỗi ngày.
進捗|しんちょく|tiến độ|作業の進捗を報告してください。|Vui lòng báo cáo tiến độ công việc.
依頼|いらい|yêu cầu; lời nhờ|翻訳の依頼を受けました。|Tôi đã nhận được yêu cầu dịch thuật.
項目|こうもく|hạng mục; mục|必要な項目に印を付けてください。|Hãy đánh dấu vào những mục cần thiết.
手順|てじゅん|trình tự; các bước thao tác|安全のため、手順どおりに作業してください。|Để bảo đảm an toàn, hãy làm việc theo đúng các bước.
作成|さくせい|tạo; soạn thảo|新しい資料を作成しました。|Tôi đã soạn tài liệu mới.
期限|きげん|thời hạn|期限までに返事をください。|Vui lòng trả lời trước hoặc đúng hạn.
整理|せいり|sắp xếp; hệ thống hóa|覚えた単語をテーマ別に整理します。|Tôi sắp xếp các từ đã học theo chủ đề.
""",
"speed-master":"""
通知|つうち|thông báo|試験の日程がメールで通知されました。|Lịch thi đã được thông báo qua email.
改善策|かいぜんさく|biện pháp cải thiện|失敗の原因を調べて改善策を考えます。|Tôi sẽ tìm nguyên nhân thất bại và nghĩ ra biện pháp cải thiện.
要約|ようやく|sự tóm tắt|文章の内容を三行で要約してください。|Hãy tóm tắt nội dung đoạn văn trong ba dòng.
周知|しゅうち|sự phổ biến; thông báo rộng rãi|変更点を全員に周知します。|Chúng tôi sẽ thông báo những điểm thay đổi cho tất cả mọi người.
予測|よそく|dự đoán|来月の売上を予測しています。|Chúng tôi đang dự đoán doanh thu tháng sau.
手配|てはい|sắp xếp; chuẩn bị|出張のためにホテルを手配しました。|Tôi đã đặt khách sạn cho chuyến công tác.
人員|じんいん|nhân sự; số người|新しい仕事には人員が足りません。|Công việc mới đang thiếu nhân sự.
議事録|ぎじろく|biên bản cuộc họp|会議が終わったら議事録を共有します。|Sau khi họp xong, tôi sẽ chia sẻ biên bản cuộc họp.
緊急|きんきゅう|khẩn cấp|緊急の場合はこの番号に連絡してください。|Trong trường hợp khẩn cấp hãy liên hệ số này.
公平|こうへい|công bằng|全員を公平に評価することが大切です。|Việc đánh giá mọi người công bằng là rất quan trọng.
収集|しゅうしゅう|thu thập|必要な情報を収集しています。|Chúng tôi đang thu thập thông tin cần thiết.
分析|ぶんせき|phân tích|調査の結果を分析します。|Tôi sẽ phân tích kết quả khảo sát.
"""
}

# pattern|Vietnamese meaning|usage explanation|original JP example|VI translation|week
GRAMMAR={
"mimikara":"""
〜に限らず|không chỉ; không giới hạn ở|Danh từ + に限らず; nói phạm vi không dừng ở đối tượng được nêu.|平日に限らず、週末も相談を受け付けています。|Chúng tôi nhận tư vấn cả cuối tuần, không chỉ các ngày trong tuần.|6
〜に加えて|ngoài ra; thêm vào đó|Danh từ + に加えて; bổ sung thành phần hoặc điều kiện khác.|基本料金に加えて、送料がかかります。|Ngoài phí cơ bản còn phải trả phí vận chuyển.|8
""",
"shin-kanzen":"""
〜に先立って|trước khi tiến hành|Danh từ hoặc động từ thể từ điển + に先立って; thực hiện việc chuẩn bị trước sự kiện chính.|面接に先立って、必要な書類を提出してください。|Trước buổi phỏng vấn, vui lòng nộp các giấy tờ cần thiết.|7
〜に反して|trái với; ngược lại|Danh từ + に反して; kết quả trái với dự đoán, mong đợi hay quy định.|予想に反して、参加者が増えました。|Trái với dự đoán, số người tham gia đã tăng.|9
〜において|tại; trong; ở phạm vi|Danh từ + において; cách diễn đạt trang trọng về địa điểm, thời gian hoặc phạm vi.|今回の会議において、新しい方針が決まりました。|Trong cuộc họp lần này, phương hướng mới đã được quyết định.|10
""",
"sou-matome":"""
〜ことから|do; căn cứ vào việc|Mệnh đề thường + ことから; giải thích nguyên nhân hoặc căn cứ suy luận.|道路がぬれていることから、昨夜雨が降ったと考えられます。|Dựa vào việc đường còn ướt, có thể cho rằng đêm qua đã mưa.|10
〜ことなく|mà không; không hề|Động từ thể từ điển + ことなく; biểu thị không làm việc A trong khi làm B.|彼女は一度も休むことなく、最後まで走りました。|Cô ấy chạy đến cuối mà không nghỉ lần nào.|11
〜を問わず|bất kể; không phân biệt|Danh từ + を問わず; điều kiện được nêu không ảnh hưởng đến phạm vi áp dụng.|経験の有無を問わず、応募できます。|Có thể ứng tuyển bất kể có kinh nghiệm hay không.|12
""",
"speed-master":"""
〜というより|đúng hơn là; thay vì nói|Cụm từ hoặc mệnh đề + というより; điều chỉnh lại cách diễn đạt cho chính xác hơn.|この作業は難しいというより、時間がかかります。|Công việc này không hẳn khó mà đúng hơn là tốn thời gian.|15
〜かと思うと|vừa mới... thì đã...|Động từ thể た + かと思うと; hai sự việc nối tiếp nhanh, thường là hiện tượng quan sát được.|電車が到着したかと思うと、すぐに乗客が降りてきました。|Tàu vừa đến thì hành khách đã xuống ngay.|16
"""
}

# char|On|Kun|Vietnamese Han meaning|related reviewed word in this series
KANJI={
"mimikara":"""
窓|ソウ|まど|song; cửa sổ|窓口
負|フ|まける、まかす、おう|phụ; gánh, chịu, thua|負担
詳|ショウ|くわしい|tường; chi tiết, rõ ràng|詳細
条|ジョウ|えだ|điều; điều khoản, nhánh|条件
""",
"shin-kanzen":"""
責|セキ|せめる|trách; trách nhiệm, khiển trách|責任
契|ケイ|ちぎる|khế; giao kèo, cam kết|契約
則|ソク|のっとる|tắc; quy tắc, noi theo|規則
優|ユウ|やさしい、すぐれる|ưu; xuất sắc, dịu dàng|優先順位
""",
"sou-matome":"""
項|コウ|—|hạng; hạng mục|項目
期|キ、ゴ|—|kỳ; kỳ hạn, thời kỳ|期限
査|サ|—|tra; kiểm tra, điều tra|調査
経|ケイ、キョウ|へる|kinh; trải qua, quản lý|経費
""",
"speed-master":"""
析|セキ|—|tích; phân tích, tách ra|分析
測|ソク|はかる|trắc; đo lường, dự đoán|予測
収|シュウ|おさめる、おさまる|thu; thu nhận, thu gom|収集
緊|キン|—|khẩn; gấp, chặt|緊急
"""
}

def parse_rows(source,expected):
    result=[]
    for line in source.strip().splitlines():
        parts=[p.strip() for p in line.split("|")]
        if len(parts)!=expected: raise ValueError(f"{len(parts)} fields, expected {expected}: {line}")
        result.append(parts)
    return result

def main():
    stats={}
    manifestpath=BASE/"manifest-series.json"
    manifest=json.loads(manifestpath.read_text(encoding="utf-8"))
    changed=False
    for name in SERIES:
        file=BASE/f"n2-series-{name}.json"
        pack=json.loads(file.read_text(encoding="utf-8"))
        assert pack["seriesId"]==name
        existing={section:{x["id"] for x in pack[section]} for section in ("vocab","grammar","kanji")}
        added={"vocab":0,"grammar":0,"kanji":0}
        for ix,(word,reading,meaning,example,translation) in enumerate(parse_rows(VOCAB[name],5),1):
            ident=f"trung-original-v-{name}-{ix:03d}"
            if ident in existing["vocab"]:continue
            # Inflected verbs (見直す→見直します, 振り返る→振り返ります) retain their written stem.
            if word not in example and (len(word) < 2 or word[:-1] not in example):
                raise ValueError(f"Need word or inflected stem in example: {word}")
            if not all((word,reading,meaning,example,translation)): raise ValueError("empty vocabulary data")
            pack["vocab"].append({
                "id":ident,"word":word,"reading":reading,"meaning":meaning,
                "example":example,"exampleVi":translation,
                "topic":"Từ vựng ứng dụng – tự biên soạn",
                "week":7+(ix-1)//2,
                "meaningStatus":"editorial_reviewed",
                "meaningSource":"Bài tập tiếng Nhật–Việt do dự án N2 của Trung biên soạn; đã rà nghĩa theo câu, chưa được thẩm định bởi nhà xuất bản",
                "exampleStatus":"editorial_reviewed"
            })
            added["vocab"]+=1
        for ix,(pattern,meaning,rule,example,translation,week) in enumerate(parse_rows(GRAMMAR[name],6),1):
            ident=f"trung-original-g-{name}-{ix:03d}"
            if ident in existing["grammar"]:continue
            if not all((pattern,meaning,rule,example,translation)): raise ValueError("empty grammar data")
            pack["grammar"].append({
                "id":ident,"pattern":pattern,"meaning":meaning,"rule":rule,
                "example":example,"translation":translation,
                "week":int(week),"samples":[],
                "grammarStatus":"editorial_reviewed",
                "translationStatus":"editorial_reviewed"
            })
            added["grammar"]+=1
        vocab_words={x["word"] for x in pack["vocab"]}
        for ix,(char,on,kun,meaning,word) in enumerate(parse_rows(KANJI[name],5),1):
            ident=f"trung-original-k-{name}-{ix:03d}"
            if ident in existing["kanji"]:continue
            if word not in vocab_words or char not in word:raise ValueError(f"Unknown Kanji compound: {char}, {word}")
            pack["kanji"].append({
                "id":ident,"char":char,"on":on,"kun":"" if kun=="—" else kun,
                "meaning":meaning,"word":word,"meaningStatus":"editorial_reviewed"
            })
            added["kanji"]+=1
        if sum(added.values()):
            changed=True
            pack["version"]+=1
            file.write_text(json.dumps(pack,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        stats[name]=added
        next(x for x in manifest["packs"] if x["id"]==pack["id"])["version"]=pack["version"]
    if changed:
        manifestpath.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    counts={k:sum(v[k] for v in stats.values()) for k in ("vocab","grammar","kanji")}
    assert counts in ({"vocab":48,"grammar":10,"kanji":16},{"vocab":0,"grammar":0,"kanji":0}),counts
    report={"result":"Original lessons expanded into four distinct packs","perSeries":stats,
            "newOriginalEntries":counts,"license":"Original sentences and translations authored for N2 Cua Trung; no text copied from textbooks",
            "reviewScope":"Internal language edit only; not textbook/publisher verified",
            "not100PercentComplete":True}
    out=ROOT/"qa-reports/original-n2-batch-01.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=="__main__":
    main()
