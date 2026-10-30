import SwiftUI

/// Bố cục thuần SwiftUI: cách đọc nằm ngay phía trên từ Kanji đã có phiên âm xác nhận.
/// Không tự đoán cách đọc của Kanji đa âm; các từ chưa có phiên âm vẫn hiện chữ gốc.
struct FuriganaText: View {
    let text: String
    var mainWord: String = ""
    var mainReading: String = ""
    var size: CGFloat = 18

    var body: some View {
        RubyFlow(spacing: 1, lineSpacing: 8) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                VStack(spacing: 0) {
                    Text(part.reading ?? " ")
                        .font(.system(size: max(10, size * 0.54)))
                        .foregroundColor(part.reading == nil ? .clear : Palette.teal)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(part.text)
                        .font(.system(size: size, weight: .medium))
                        .foregroundColor(Palette.navy)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(part.reading.map { "\(part.text)、\($0)" } ?? part.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var parts: [RubyPart] {
        var dictionary = RubyLexicon.words
        if !mainWord.isEmpty && !mainReading.isEmpty { dictionary[mainWord] = mainReading }
        let tokens = dictionary.keys.filter { !$0.isEmpty }.sorted {
            if $0.count == $1.count { return $0 < $1 }
            return $0.count > $1.count
        }
        var rest = text[...]
        var segments: [RubyPart] = []
        while !rest.isEmpty {
            if let key = tokens.first(where: { rest.hasPrefix($0) }) {
                segments.append(RubyPart(text: key, reading: dictionary[key]))
                rest.removeFirst(key.count)
            } else {
                let character = String(rest.removeFirst())
                // Gộp Hiragana/Katakana và ký tự Latin liền nhau để không bị ngắt quá nhỏ.
                if let last = segments.last, last.reading == nil, !character.containsKanji {
                    segments[segments.count - 1].text += character
                } else {
                    segments.append(RubyPart(text: character, reading: nil))
                }
            }
        }
        return segments
    }
}

private struct RubyPart {
    var text: String
    let reading: String?
}

private extension String {
    var containsKanji: Bool {
        unicodeScalars.contains { (0x4E00...0x9FFF).contains(Int($0.value)) }
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