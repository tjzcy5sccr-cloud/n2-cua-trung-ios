import SwiftUI

/// Furigana tiếng Nhật được phân tích theo ngữ cảnh và đóng gói offline trước khi biên dịch.
struct FuriganaText: View {
    let text: String
    var mainWord: String = ""
    var mainReading: String = ""
    var highlightTerms: [String] = []
    var size: CGFloat = 18

    var body: some View {
        RubyFlow(spacing: 1, lineSpacing: 8) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                VStack(spacing: 0) {
                    Text(part.showReading ? (part.reading ?? " ") : " ")
                        .font(.system(size: max(10, size * 0.54)))
                        .foregroundColor(!part.showReading ? .clear : (part.highlighted ? .red : Palette.teal))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(part.text)
                        .font(.system(size: size, weight: .medium))
                        .foregroundColor(part.highlighted ? .red : Palette.navy)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(part.showReading ? "\(part.text)、\(part.reading ?? "")" : part.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var parts: [RubyPart] {
        var segments: [RubyPart]
        // Ưu tiên atlas theo từng câu để xử lý Kanji đa âm chính xác hơn so với tra chữ đơn.
        if text == mainWord, !mainReading.isEmpty {
            segments = [RubyPart(text: text, reading: mainReading)]
        } else if let stored = RubyAtlas.entries[text] {
            segments = stored.compactMap { pair in
                guard let surface = pair.first ?? nil, !surface.isEmpty else { return nil }
                return RubyPart(text: surface, reading: pair.count > 1 ? pair[1] : nil)
            }
        } else {
            // Văn bản ngoài kho bài học vẫn có thể tận dụng từ điển cơ bản cũ.
            var dictionary = RubyLexicon.words
            if !mainWord.isEmpty && !mainReading.isEmpty { dictionary[mainWord] = mainReading }
            let tokens = dictionary.keys.sorted { $0.count > $1.count }
            var rest = text[...]
            segments = []
            while !rest.isEmpty {
                if let key = tokens.first(where: { rest.hasPrefix($0) }) {
                    segments.append(RubyPart(text: key, reading: dictionary[key]))
                    rest.removeFirst(key.count)
                } else {
                    let ch = String(rest.removeFirst())
                    if let previous = segments.last, previous.reading == nil, !ch.containsKanji {
                        segments[segments.count - 1].text += ch
                    } else {
                        segments.append(RubyPart(text: ch, reading: nil))
                    }
                }
            }
        }

        // Chỉ tô đỏ đúng đoạn trùng từ vựng hoặc cụm ngữ pháp đang học.
        let terms = ([mainWord] + highlightTerms).filter { !$0.isEmpty }
        var targets: [Range<String.Index>] = []
        for term in terms {
            var search = text.startIndex..<text.endIndex
            while let found = text.range(of: term, range: search) {
                targets.append(found)
                if found.upperBound == text.endIndex { break }
                search = found.upperBound..<text.endIndex
            }
        }
        var offset = text.startIndex
        for i in segments.indices {
            segments[i].showReading = segments[i].reading != nil &&
                segments[i].text.unicodeScalars.contains { N2RubyTargets.kanji.contains($0) }
            guard let end = text.index(offset, offsetBy: segments[i].text.count, limitedBy: text.endIndex) else { break }
            segments[i].highlighted = targets.contains { $0.overlaps(offset..<end) }
            offset = end
        }
        return segments
    }
}


/// Các dạng của từ đang học có thể xuất hiện trong ví dụ: chia động từ,
/// tính từ -い hoặc cách viết Kanji/kana khác nhau. Chỉ tô khi thật sự
/// tìm thấy bề mặt trong câu, không tự khẳng định ngữ nghĩa của cả câu.
enum VocabularyExampleFocus {
    private static let alternativeSpellings: [String: [String]] = [
        "アイデア": ["アイディア"], "曖昧": ["あいまい"], "扇ぐ": ["あおぐ"],
        "明き": ["空き"], "呆れる": ["あきれる"], "飽くまで": ["あくまで"],
        "憧れる": ["あこがれる"], "暖める": ["温める"],
        "当たり前": ["あたりまえ"], "溢れる": ["あふれる"],
        "編物": ["編み物"], "有難い": ["ありがたい"],
        "彼此": ["かれこれ"], "慌ただしい": ["あわただしい"],
        "慌てる": ["あわてる"], "粗筋": ["あらすじ"],
        "炙る": ["あぶる"], "暖まる": ["温まる"],
        "余る": ["あまる"], "言い付ける": ["言いつける"],
        "いってまいります": ["行ってまいります"],
        "何時の間にか": ["いつの間にか"], "佚": ["逸"]
    ]

    static func variants(word: String, reading: String, example: String) -> [String] {
        guard !word.isEmpty, !example.isEmpty else { return [] }
        var bases = [word]
        bases.append(contentsOf: alternativeSpellings[word] ?? [])
        if reading.count >= 2 && !bases.contains(reading) { bases.append(reading) }

        var candidates = Set<String>()
        for base in bases {
            if example.contains(base) { candidates.insert(base) }
            guard base.count >= 2, let final = base.last else { continue }
            let stem = String(base.dropLast())
            let suffixes: [String]
            switch final {
            case "い":
                suffixes = ["く", "かった", "くて", "ければ", "さ", "そう"]
            case "う", "つ", "る":
                suffixes = final == "る"
                    ? ["た", "て", "ない", "ます", "れば", "よう",
                       "った", "って", "らない", "ります", "られる",
                       "られた", "られて", "られない"]
                    : ["った", "って", "わない", "います", "えば", "おう"]
            case "く": suffixes = ["いた", "いて", "かない", "きます", "けば"]
            case "ぐ": suffixes = ["いだ", "いで", "がない", "ぎます", "げば"]
            case "す": suffixes = ["した", "して", "さない", "します", "せば", "された", "されて"]
            case "ぬ", "ぶ", "む":
                suffixes = ["んだ", "んで", "ない", "ます"]
            default: suffixes = []
            }
            for ending in suffixes {
                let candidate = stem + ending
                if example.contains(candidate) { candidates.insert(candidate) }
            }
            // Các câu ví dụ có thể thêm trợ động từ vào phần gốc.
            // Không tô đỏ chỉ một Kanji rời rạc khi chưa xác định được từ.
        }
        // Ưu tiên chuỗi dài để không tô đỏ tràn sang từ khác.
        return candidates.sorted { $0.count > $1.count }
    }
}

private enum RubyAtlas {
    private struct Atlas: Decodable {
        let entries: [String: [[String?]]]
    }
    static let entries: [String: [[String?]]] = {
        guard let url = Bundle.main.url(forResource: "furigana-atlas", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let atlas = try? JSONDecoder().decode(Atlas.self, from: data) else {
            return [:]
        }
        return atlas.entries
    }()
}

private struct RubyPart {
    var text: String
    var reading: String?
    var highlighted = false
    var showReading = false
}

private extension String {
    var containsKanji: Bool {
        unicodeScalars.contains {
            (0x3400...0x9FFF).contains(Int($0.value)) ||
            (0xF900...0xFAFF).contains(Int($0.value))
        }
    }
}

struct RubyFlow: Layout {
    var spacing: CGFloat = 1
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, location) in result.locations.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + location.x, y: bounds.minY + location.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, locations: [CGPoint]) {
        let width = max(1, proposal.width ?? 340)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var locations: [CGPoint] = []
        var maxX: CGFloat = 0
        for subview in subviews {
            let s = subview.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            locations.append(CGPoint(x: x, y: y))
            x += s.width + spacing
            maxX = max(maxX, x)
            rowHeight = max(rowHeight, s.height)
        }
        return (CGSize(width: min(width, maxX), height: y + rowHeight), locations)
    }
}

enum RubyLexicon {
    static let words: [String: String] = [
        "日本":"にほん", "日本語":"にほんご", "毎日":"まいにち", "今日":"きょう", "明日":"あした",
        "昨日":"きのう", "今週":"こんしゅう", "来週":"らいしゅう", "先週":"せんしゅう", "来月":"らいげつ",
        "去年":"きょねん", "今年":"ことし", "仕事":"しごと", "会社":"かいしゃ", "会社員":"かいしゃいん",
        "学校":"がっこう", "学生":"がくせい", "先生":"せんせい", "友達":"ともだち", "友人":"ゆうじん",
        "家族":"かぞく", "子供":"こども", "子ども":"こども", "大人":"おとな", "兄弟":"きょうだい",
        "勉強":"べんきょう", "練習":"れんしゅう", "試験":"しけん", "合格":"ごうかく", "漢字":"かんじ",
        "新聞":"しんぶん", "問題":"もんだい", "答え":"こたえ", "質問":"しつもん", "意味":"いみ",
        "方法":"ほうほう", "結果":"けっか", "理由":"りゆう", "予定":"よてい", "計画":"けいかく",
        "説明":"せつめい", "資料":"しりょう", "規則":"きそく", "重要":"じゅうよう", "必要":"ひつよう",
        "時間":"じかん", "生活":"せいかつ", "健康":"けんこう", "安全":"あんぜん", "便利":"べんり",
        "電車":"でんしゃ", "駅":"えき", "会議":"かいぎ", "映画":"えいが", "写真":"しゃしん",
        "旅行":"りょこう", "京都":"きょうと", "海外":"かいがい", "国内":"こくない", "外国":"がいこく",
        "文化":"ぶんか", "歴史":"れきし", "研究":"けんきゅう", "教育":"きょういく", "社会":"しゃかい",
        "人口":"じんこう", "経済":"けいざい", "景気":"けいき", "雇用":"こよう", "環境":"かんきょう",
        "気温":"きおん", "天気":"てんき", "大雨":"おおあめ", "雪":"ゆき", "大雪":"おおゆき",
        "年齢":"ねんれい", "経験":"けいけん", "努力":"どりょく", "自信":"じしん", "感謝":"かんしゃ",
        "準備":"じゅんび", "出発":"しゅっぱつ", "到着":"とうちゃく", "成功":"せいこう", "失敗":"しっぱい",
        "終了":"しゅうりょう", "開始":"かいし", "中止":"ちゅうし", "変更":"へんこう", "決定":"けってい",
        "一度":"いちど", "何度":"なんど", "全部":"ぜんぶ", "本当":"ほんとう", "情報":"じょうほう",
        "最近":"さいきん", "以前":"いぜん", "現在":"げんざい", "将来":"しょうらい", "状況":"じょうきょう",
        "新しい":"あたらしい", "難しい":"むずかしい", "簡単":"かんたん", "高い":"たかい", "安い":"やすい",
        "忙しい":"いそがしい", "楽しい":"たのしい", "早い":"はやい", "遅い":"おそい", "暑い":"あつい",
        "寒い":"さむい", "明るい":"あかるい", "美味しい":"おいしい", "人気":"にんき", "電話":"でんわ",
        "朝":"あさ", "昼":"ひる", "夜":"よる", "食事":"しょくじ", "買い物":"かいもの",
        "料理":"りょうり", "運動":"うんどう", "集中":"しゅうちゅう", "反対":"はんたい", "場合":"ばあい",
        "男性":"だんせい", "女性":"じょせい", "観光客":"かんこうきゃく", "売上":"うりあげ", "費用":"ひよう",
        "客":"きゃく", "店":"みせ", "物価":"ぶっか", "効果":"こうか", "改善":"かいぜん",
        "影響":"えいきょう", "調査":"ちょうさ", "会話":"かいわ", "自習":"じしゅう", "授業":"じゅぎょう"
    ]
}

/// Chỉ nhận diện các cụm ngữ pháp có từ hai ký tự trở lên, tránh tô đỏ nhầm trợ từ.
enum GrammarFocus {
    static func terms(from pattern: String) -> [String] {
        let standardized = pattern
            .replacingOccurrences(of: "～", with: "〜")
            .replacingOccurrences(of: "／", with: "/")
            .replacingOccurrences(of: "（", with: "")
            .replacingOccurrences(of: "）", with: "")
        var terms: [String] = []
        for alternative in standardized.components(separatedBy: "/") {
            for portion in alternative.components(separatedBy: "〜") {
                let term = portion.trimmingCharacters(in: .whitespacesAndNewlines)
                if term.count >= 2 && term.unicodeScalars.contains(where: { $0.value > 127 })
                    && !terms.contains(term) {
                    terms.append(term)
                }
            }
        }
        return terms.sorted { $0.count > $1.count }
    }
}

/// N2/difficult kanji theo kho OpenJLPT, không phải danh sách JLPT chính thức.
private enum N2RubyTargets {
    static let kanji = Set("党協総区領県設府査委軍団各島革村勢再営防補副算述線農州武象域額欧賞辺被低復移個門課脳極含蔵量型針専谷史階管兵接細丸湾録省旧橋岸周材戸央券編捜竹超並療森介根歴将幅般講林装諸劇河航鉄児禁印逆換久短油暴輪占植清倍均億圧芸署伸停爆陸玉波狙帯延羽固則乱普測豊厚齢囲卒略順岩練軽了庁城患層版令角損裏仏績築貨混昇池血温季星永著誌庫刊像香坂底布寺宇巨震希触依籍汚枚複郵仲栄札板骨届巻燃跡包駐弱紹雇替預焼簡章臓贈照薄群秒奥詰双孝刺純翌快片敬悩泉皮漁荒貯硬埋柱祭袋筆訓浴童宝封胸砂塩賢腕兆床毛緑尊祝柔殿濃液衣肩零幼荷泊黄寿甘臣浅掃雲掘捨軟沈凍乳恋紅郊腰炭踊冊勇械菜珍卵湖喫干虫刷湯溶鉱涙匹孫鋭枝塗軒毒叫拝氷乾棒祈拾粉糸綿汗銅湿瓶咲召缶隻脂蒸肌耕鈍泥隅灯辛磨麦姓筒鼻粒詞胃畳机膚濯塔沸灰菓帽枯釜涼舟貝符憎皿肯燥畜瓦挟曇滴爪枕丼斬餅芯伺匂麓稽蹴蓋拭煎嗅塞宛巾捻桁潰箋羨肘遜遡隙".unicodeScalars)
}
