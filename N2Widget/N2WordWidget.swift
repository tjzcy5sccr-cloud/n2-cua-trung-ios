import SwiftUI
import WidgetKit
import ActivityKit

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
        // Có đủ kho bài học đóng gói, không giới hạn ở content.json 125 từ.
        var all: [Word] = []
        var existing = Set<String>()
        for filename in ["content", "n2-expansion-01", "openjlpt-n2-core"] {
            guard let path = Bundle.main.url(forResource: filename, withExtension: "json"),
                  let bytes = try? Data(contentsOf: path),
                  let list = try? JSONDecoder().decode(WordList.self, from: bytes) else { continue }
            for word in list.vocab where !existing.contains(word.word) {
                existing.insert(word.word)
                all.append(word)
            }
        }
        return all.isEmpty ? [fallback] : all
    }()

    func placeholder(in context: Context) -> WordEntry { WordEntry(date: Date(), word: Self.fallback) }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(WordEntry(date: Date(), word: Self.words.randomElement() ?? Self.fallback))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let now = Date()
        // Cho phép đổi từ khi app yêu cầu reload. Không cần App Groups/entitlements.
        let defaults = UserDefaults.standard
        let cycle = defaults.integer(forKey: "N2WordWidgetCycle") + 1
        defaults.set(cycle, forKey: "N2WordWidgetCycle")

        let count = Self.words.count
        let start = (Int.random(in: 0..<max(count, 1)) + cycle) % max(count, 1)
        // Dùng bước nguyên tố cùng nhau với số lượng từ để đi hết bộ mà không lặp sát nhau.
        let step = count > 1 ? count - 1 : 1
        let entries: [WordEntry] = (0..<97).map { offset in
            // Mỗi mục timeline cách 15 phút, nhưng hệ thống có thể hiển thị muộn.
            let index = (start + offset * step) % max(count, 1)
            return WordEntry(date: now.addingTimeInterval(TimeInterval(offset) * 900), word: Self.words[index])
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

private struct WordWidgetBody: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private let deepGreen = Color(red: 0.035, green: 0.23, blue: 0.14)
    private let brightGreen = Color(red: 0.12, green: 0.48, blue: 0.25)

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                lockScreenContent
            } else {
                homeScreenContent
            }
        }
    }

    private var lockScreenContent: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text("☘ N2").font(.caption2.bold())
                Spacer(minLength: 1)
                Text(entry.word.reading).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
            }
            Text(entry.word.word)
                .font(.system(size: 18, weight: .heavy))
                .minimumScaleFactor(0.67).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(entry.word.meaning)
                .font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        // Lock Screen accessory has a system-controlled transparent/vibrant background.
        .foregroundStyle(.primary)
        .shadow(color: Color.black.opacity(0.20), radius: 1, y: 0.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    private var homeScreenContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("N2 CỦA TRUNG")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
                Text("☘").font(.title3)
            }
            Spacer(minLength: 1)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.word.word)
                        .font(.system(size: family == .systemLarge ? 48 : (family == .systemMedium ? 37 : 32), weight: .heavy))
                        .foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.55)
                    Text(entry.word.reading)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.74, green: 1.0, blue: 0.78))
                        .lineLimit(1)
                    Text(entry.word.meaning)
                        .font(.system(size: family == .systemSmall ? 14 : 17, weight: .semibold))
                        .foregroundStyle(.white).lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 1)
            HStack {
                Text("MỖI LẦN XEM • MỘT CHÚT TIẾN BỘ")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.77))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(deepGreen)
        .modifier(BackgroundCompatibility(color: deepGreen))
    }
}

/// iOS 17+ yêu cầu đánh dấu đúng nền widget để không bị che bởi hệ thống.
private struct BackgroundCompatibility: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { color }
        } else {
            content.background(color)
        }
    }
}

struct N2WordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "N2TrungWordWidget", provider: WordProvider()) { entry in
            WordWidgetBody(entry: entry)
        }
        .configurationDisplayName("N2 của Trung • Từ vựng")
        .description("Widget ngang và lớn trên Màn hình chính, widget nhỏ trên Màn hình khóa. Đổi từ theo lịch iOS.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

@available(iOS 16.1, *)
struct N2WideLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            VStack(alignment: .center, spacing: 3) {
                Text("☘ N2 CỦA TRUNG")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
                Text(context.state.word)
                    .font(.system(size: 39, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                Text(context.state.reading)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.69, green: 1.0, blue: 0.75))
                    .lineLimit(1)
                Text(context.state.meaning)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .activityBackgroundTint(Color(red: 0.02, green: 0.21, blue: 0.12))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("☘ N2 của Trung").font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.word)
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.reading) • \(context.state.meaning)")
                        .font(.caption).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } compactLeading: {
                Text("☘ N2").font(.caption2)
            } compactTrailing: {
                Text(context.state.word).font(.caption2).lineLimit(1)
            } minimal: {
                Image(systemName: "leaf.fill")
            }
        }
    }
}

@main
struct N2Widgets: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        N2WordWidget()
        if #available(iOS 16.1, *) {
            N2WideLiveActivityWidget()
        }
    }
}