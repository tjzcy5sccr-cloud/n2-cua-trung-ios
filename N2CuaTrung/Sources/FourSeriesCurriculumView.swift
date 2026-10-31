import Foundation
import SwiftUI

// Đây là lộ trình biên soạn độc lập. Tên các giáo trình chỉ mô tả hướng học,
// không có nội dung sách/audio thương mại hoặc giả định người dùng đã sở hữu sách.
private struct FourSeriesPlan: Decodable {
    let schemaVersion: Int
    let title: String
    let audience: String
    let targets: FourSeriesTargets
    let targetsNote: String
    let tracks: [FourSeriesTrack]
    let weeks: [FourSeriesWeek]

    static let shared: FourSeriesPlan? = {
        guard let url = Bundle.main.url(forResource: "n2-four-series-curriculum", withExtension: "json"),
              let bytes = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FourSeriesPlan.self, from: bytes)
    }()
}

private struct FourSeriesTargets: Decodable {
    let vocabulary: Int
    let kanji: Int
    let grammar: Int
    let readingSessions: Int
    let listeningSessions: Int
}

private struct FourSeriesTrack: Decodable, Identifiable {
    let id: String
    let name: String
    let focus: String
    let skills: [String]
    let copyright: String
}

private struct FourSeriesWeek: Decodable, Identifiable {
    var id: Int { number }
    let number: Int
    let dateRange: String
    let phase: String
    let theme: String
    let grammarFocus: String
    let targets: FourSeriesWeekTargets
    let days: [FourSeriesDay]
    let review: String
}

private struct FourSeriesWeekTargets: Decodable {
    let vocabulary: Int
    let kanji: Int
    let grammar: Int
}

private struct FourSeriesDay: Decodable, Identifiable {
    let id: String
    let day: String
    let primarySkill: String
    let task: String
}

/// Tích hợp chương trình 4 hướng học trong nhánh tính năng, không sửa nội dung
/// giáo trình thương mại hay báo tiến độ mục tiêu thành tiến độ đã học.
struct FourSeriesCurriculumView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var selectedWeek = 1
    @State private var completedDayIDs = Set<String>()
    private let completionKey = "N2.fourSeries.35Weeks.dailyChecks.v1"

    private var plan: FourSeriesPlan? { FourSeriesPlan.shared }
    private var week: FourSeriesWeek? {
        plan?.weeks.first(where: { $0.number == selectedWeek })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                heading
                if let plan {
                    targetPanel(plan)
                    trackPanel(plan)
                    LessonPanel {
                        SectionTitle("Lộ trình 35 tuần", subtitle: "N3 → N2 • 90 phút/ngày • 6 ngày/tuần")
                        Picker("Chọn tuần", selection: $selectedWeek) {
                            ForEach(plan.weeks) { item in
                                Text("Tuần \(item.number)").tag(item.number)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Palette.blue)
                        if let week {
                            Text(week.dateRange)
                                .font(.caption).foregroundColor(.secondary)
                            Text(week.phase)
                                .font(.caption.weight(.semibold)).foregroundColor(Palette.teal)
                            Text(week.theme)
                                .font(.title3.bold()).foregroundColor(Palette.navy)
                            Text("Ngữ pháp trọng tâm: \(week.grammarFocus).")
                                .font(.subheadline).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                targetChip("\(week.targets.vocabulary) từ", symbol: "character.book.closed")
                                targetChip("\(week.targets.kanji) chữ", symbol: "character.square")
                                targetChip("\(week.targets.grammar) mẫu", symbol: "text.book.closed")
                            }
                            Text("Đây là chỉ tiêu tuần, không phải số bài đã được kiểm duyệt hoặc có sẵn trong kho.")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    if let week {
                        dailyPlan(week)
                    }
                    skillShortcuts
                    Text("Bài học và bài luyện trong ứng dụng là dữ liệu riêng của dự án. Không phải bản chép hoặc bản điện tử của bất cứ bộ giáo trình thương mại nào.")
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                } else {
                    LessonPanel {
                        SectionTitle("Không mở được lộ trình")
                        Text("Thiếu n2-four-series-curriculum.json trong tài nguyên IPA. Kiểm tra project.yml và thử build lại sau khi duyệt hình.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Chương trình N2")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if (1...35).contains(store.week) { selectedWeek = store.week }
            completedDayIDs = Set(UserDefaults.standard.stringArray(forKey: completionKey) ?? [])
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("N2 CỦA TRUNG")
                .font(.caption.weight(.bold)).foregroundColor(.white.opacity(0.86))
            Text("4 hướng học\n1 lộ trình N2")
                .font(.system(size: 29, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text("Mimikara • Shin Kanzen • Sou Matome • Speed/Kanji Master")
                .font(.subheadline).foregroundColor(.white.opacity(0.90))
            Text("Mục tiêu: JLPT tháng 7/2027")
                .font(.caption.weight(.semibold)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(colors: [Palette.navy, Palette.blue],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22))
    }

    private func targetPanel(_ plan: FourSeriesPlan) -> some View {
        LessonPanel {
            SectionTitle("Mục tiêu kiến thức", subtitle: "Mốc tham khảo theo yêu cầu của người học")
            HStack(spacing: 8) {
                targetColumn("Từ vựng", target: plan.targets.vocabulary,
                             current: store.course.vocab.count)
                targetColumn("Kanji", target: plan.targets.kanji,
                             current: store.course.kanji.count)
                targetColumn("Ngữ pháp", target: plan.targets.grammar,
                             current: store.course.grammar.count)
            }
            Text(plan.targetsNote)
                .font(.caption).foregroundColor(.secondary)
            Text("Kho bài hiện có: \(store.course.readings.count) đọc hiểu, \(store.course.listening.count) nghe hiểu. Chỉ tiêu luyện: \(plan.targets.readingSessions) lượt đọc, \(plan.targets.listeningSessions) lượt nghe.")
                .font(.caption).foregroundColor(Palette.navy)
        }
    }

    private func targetColumn(_ label: String, target: Int, current: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text("\(target)")
                .font(.title3.bold()).foregroundColor(Palette.blue)
            Text("Kho: \(current)")
                .font(.caption2).foregroundColor(Palette.teal)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.pale, in: RoundedRectangle(cornerRadius: 12))
    }

    private func trackPanel(_ plan: FourSeriesPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Bốn hướng học", subtitle: "Tham khảo phương pháp, không sao chép nội dung sách")
            ForEach(plan.tracks) { track in
                LessonPanel {
                    HStack {
                        Text(track.name).font(.headline).foregroundColor(Palette.navy)
                        Spacer()
                        Image(systemName: icon(for: track.id))
                            .foregroundColor(Palette.blue)
                    }
                    Text(track.focus).font(.subheadline).foregroundColor(.secondary)
                    Text(track.skills.joined(separator: " • "))
                        .font(.caption.weight(.medium)).foregroundColor(Palette.teal)
                }
            }
        }
    }

    private func dailyPlan(_ week: FourSeriesWeek) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionTitle("Nhiệm vụ từng ngày", subtitle: "Đánh dấu sau khi hoàn thành – lưu cục bộ trên máy")
            ForEach(week.days) { day in
                LessonPanel {
                    Button {
                        toggle(day.id)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: completedDayIDs.contains(day.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(completedDayIDs.contains(day.id) ? Palette.teal : Palette.blue)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(day.day) · \(day.primarySkill)")
                                    .font(.subheadline.weight(.bold)).foregroundColor(Palette.navy)
                                Text(day.task)
                                    .font(.subheadline).foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.day): \(completedDayIDs.contains(day.id) ? "Đã hoàn thành" : "Chưa hoàn thành"). \(day.task)")
                }
            }
            LessonPanel {
                Text("Chủ nhật").font(.subheadline.bold()).foregroundColor(Palette.navy)
                Text(week.review).font(.subheadline).foregroundColor(.secondary)
            }
            Text("\(week.days.filter { completedDayIDs.contains($0.id) }.count)/6 ngày đã hoàn thành tuần \(week.number)")
                .font(.caption.weight(.semibold)).foregroundColor(Palette.teal)
        }
    }

    private var skillShortcuts: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Mở bài học trong app", subtitle: "Liên kết với kho hiện tại, không tải sách bên ngoài")
            NavigationLink { FlashcardDeckView() } label: {
                ActionTile(icon: "rectangle.on.rectangle", color: Palette.teal,
                           title: "Flashcard từ vựng", detail: "Học từ và ví dụ Nhật – Việt")
            }.buttonStyle(.plain)
            NavigationLink { KanjiSwipeDeckView() } label: {
                ActionTile(icon: "character.square", color: Palette.orange,
                           title: "Kanji", detail: "Chạm lật, vuốt bốn hướng, từ liên quan")
            }.buttonStyle(.plain)
            NavigationLink { GrammarFlashcardView() } label: {
                ActionTile(icon: "text.book.closed", color: Palette.blue,
                           title: "Ngữ pháp", detail: "Ý nghĩa và cách dùng")
            }.buttonStyle(.plain)
            NavigationLink { FreshPracticeSessionView(type: "Đọc hiểu") } label: {
                ActionTile(icon: "doc.text", color: Palette.blue,
                           title: "Đọc hiểu", detail: "Bài ngẫu nhiên, giải thích đáp án")
            }.buttonStyle(.plain)
            NavigationLink { FreshPracticeSessionView(type: "Nghe hiểu") } label: {
                ActionTile(icon: "headphones", color: Palette.teal,
                           title: "Nghe hiểu", detail: "Nghe giọng Nhật và luyện câu hỏi")
            }.buttonStyle(.plain)
            NavigationLink { ExamStartView() } label: {
                ActionTile(icon: "timer", color: Palette.orange,
                           title: "Luyện đề bấm giờ", detail: "Chọn đáp án và xem lỗi")
            }.buttonStyle(.plain)
        }
    }

    private func targetChip(_ value: String, symbol: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundColor(Palette.blue)
            .padding(.horizontal, 7).padding(.vertical, 8)
            .background(Palette.pale, in: RoundedRectangle(cornerRadius: 9))
    }

    private func icon(for id: String) -> String {
        switch id {
        case "mimikara": return "waveform"
        case "shin-kanzen": return "books.vertical"
        case "so-matome": return "calendar"
        default: return "stopwatch"
        }
    }

    private func toggle(_ id: String) {
        if completedDayIDs.contains(id) { completedDayIDs.remove(id) }
        else { completedDayIDs.insert(id) }
        UserDefaults.standard.set(completedDayIDs.sorted(), forKey: completionKey)
    }
}
