import SwiftUI
import WidgetKit

private struct Word: Decodable {
    let word: String
    let reading: String
    let meaning: String
}

private struct WordList: Decodable { let vocab: [Word] }

private struct WordEntry: TimelineEntry {
    let date: Date
    let word: Word
}

private struct WordProvider: TimelineProvider {
    private static let fallback = Word(word: "努力", reading: "どりょく", meaning: "nỗ lực")
    private static let words: [Word] = {
        guard let path = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: path),
              let content = try? JSONDecoder().decode(WordList.self, from: data),
              !content.vocab.isEmpty else { return [fallback] }
        return content.vocab
    }()

    func placeholder(in context: Context) -> WordEntry { WordEntry(date: Date(), word: Self.fallback) }
    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(entry(at: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let now = Date()
        // WidgetKit cho phép lập lịch theo giờ; iOS tự quyết định thời điểm thực tế.
        let entries = (0..<24).map { offset in
            entry(at: now.addingTimeInterval(TimeInterval(offset) * 3600))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
    private func entry(at date: Date) -> WordEntry {
        let index = Int(date.timeIntervalSince1970 / 3600) % Self.words.count
        return WordEntry(date: date, word: Self.words[index])
    }
}

private struct CloverGlyph: View {
    var body: some View {
        Image(systemName: "leaf.fill")
            .foregroundColor(.green)
            .font(.system(size: 15, weight: .bold))
    }
}

private struct WordWidgetBody: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 1) {
                Text("☘ N2 của Trung").font(.caption2.weight(.semibold)).lineLimit(1)
                HStack(spacing: 5) {
                    Text(entry.word.word).font(.headline.bold()).lineLimit(1).minimumScaleFactor(0.6)
                    Text(entry.word.reading).font(.caption2).lineLimit(1)
                }
                Text(entry.word.meaning)
                    .font(.caption2).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    CloverGlyph()
                    Text("N2 của Trung").font(.caption.bold()).foregroundStyle(.green)
                }
                Spacer(minLength: 0)
                Text(entry.word.word)
                    .font(.system(size: family == .systemSmall ? 28 : 35, weight: .bold))
                    .minimumScaleFactor(0.55).lineLimit(2)
                Text(entry.word.reading).font(.callout).foregroundStyle(.green).lineLimit(1)
                Text(entry.word.meaning).font(.caption).lineLimit(2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(red: 0.95, green: 1.0, blue: 0.94))
        }
    }
}

// Không dùng App Groups để tương thích tài khoản ký ứng dụng cá nhân miễn phí.
@main
struct N2WordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "N2TrungWordWidget", provider: WordProvider()) { entry in
            WordWidgetBody(entry: entry)
        }
        .configurationDisplayName("N2 của Trung • Từ vựng")
        .description("Một từ vựng Nhật mỗi lần xem • cập nhật theo lịch của iOS.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}