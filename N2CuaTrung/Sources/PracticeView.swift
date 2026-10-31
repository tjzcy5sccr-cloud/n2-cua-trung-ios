
/// Tạo đề tại thời điểm màn hình thực sự xuất hiện, thay vì khi NavigationLink dựng trước.
/// Khi rời rồi vào lại, một bộ câu hỏi mới được chọn và trộn cả câu hỏi lẫn đáp án.
struct FreshPracticeSessionView: View {
    let type: String
    @EnvironmentObject private var store: StudyStore
    @State private var questions: [ExamQuestion] = []
    @State private var sessionIdentity = UUID()

    var body: some View {
        Group {
            if questions.isEmpty {
                ProgressView("Đang xáo trộn bài luyện…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                QuestionSessionView(questions: questions, type: type)
                    .id(sessionIdentity)
            }
        }
        .onAppear { generateNewSession() }
    }

    private func generateNewSession() {
        let next: [ExamQuestion]
        switch type {
        case "Đọc hiểu":
            next = QuestionBank.reading(store.course)
        case "Nghe hiểu":
            next = QuestionBank.listening(store.course)
        case "Kanji":
            next = Array(QuestionBank.kanji(store.course).shuffled().prefix(12))
        default:
            next = []
        }
        questions = next.shuffled()
        sessionIdentity = UUID()
    }
}

import SwiftUI

struct PracticeHubView: View {
    @EnvironmentObject private var store: StudyStore
    var body: some View {
        ScrollView {
            VStack(spacing: 13) {
                NavigationLink { LearningSeriesPickerView() } label: {
                    ActionTile(icon: "square.stack.3d.up.fill", color: Palette.blue,
                               title: "Đang học: \(store.selectedSeries.name)",
                               detail: "Chạm để đổi bộ dữ liệu cho mọi kỹ năng")
                }.buttonStyle(.plain)
                SectionTitle("Luyện JLPT N2", subtitle: "Chọn kỹ năng muốn luyện – hoạt động offline")
                NavigationLink { GrammarListView() } label: {
                    ActionTile(icon: "textformat.abc", color: Palette.blue,
                               title: "Ngữ pháp", detail: "\(store.course.grammar.count) mẫu • Giải thích & ví dụ")
                }
                NavigationLink { GrammarFlashcardView() } label: {
                    ActionTile(icon: "rectangle.on.rectangle", color: Palette.teal,
                               title: "Flashcard ngữ pháp", detail: "Tự nhớ và ôn cách quãng")
                }
                NavigationLink { KanjiSwipeDeckView() } label: {
                    ActionTile(icon: "character.square", color: Palette.orange,
                               title: "Kanji", detail: "\(store.course.kanji.count) chữ • Vuốt để học, chạm để lật")
                }
                NavigationLink { KangxiRadicalsView() } label: {
                    ActionTile(icon: "text.book.closed", color: Palette.blue,
                               title: "214 bộ thủ", detail: "Âm Hán–Việt, nghĩa và số thứ tự bộ thủ")
                }
                NavigationLink {
                    QuestionSessionView(questions: QuestionBank.vocabulary(store.course, week: store.week).shuffled(),
                                        type: "Từ vựng")
                } label: {
                    ActionTile(icon: "character.book.closed", color: Palette.blue,
                               title: "Trắc nghiệm từ vựng", detail: "Từ N3 lên N2 theo tuần")
                }
                NavigationLink {
                    QuestionSessionView(questions: QuestionBank.grammar(store.course, week: store.week).shuffled(),
                                        type: "Ngữ pháp")
                } label: {
                    ActionTile(icon: "list.bullet.rectangle", color: Palette.teal,
                               title: "Trắc nghiệm ngữ pháp", detail: "Hỏi nghĩa và ví dụ minh họa")
                }
                NavigationLink {
                    FreshPracticeSessionView(type: "Kanji")
                } label: {
                    ActionTile(icon: "character.cursor.ibeam", color: Palette.orange,
                               title: "Trắc nghiệm Kanji", detail: "Tập nhận biết mặt chữ")
                }
                NavigationLink {
                    FreshPracticeSessionView(type: "Đọc hiểu")
                } label: {
                    ActionTile(icon: "doc.text", color: Palette.blue,
                               title: "Đọc hiểu", detail: "\(store.course.readings.count) bài • 12 câu ngẫu nhiên mỗi lượt")
                }
                NavigationLink {
                    FreshPracticeSessionView(type: "Nghe hiểu")
                } label: {
                    ActionTile(icon: "headphones", color: Palette.teal,
                               title: "Nghe hiểu", detail: "\(store.course.listening.count) bài • 12 câu ngẫu nhiên mỗi lượt")
                }
                NavigationLink { ExamStartView() } label: {
                    ActionTile(icon: "stopwatch", color: Palette.orange,
                               title: "Thi thử 20 câu", detail: "Có thời gian, chấm điểm, chữa câu sai")
                }
                NavigationLink { VoiceSettingsView() } label: {
                    ActionTile(icon: "waveform", color: Palette.teal,
                               title: "Chọn giọng đọc tự nhiên", detail: "Giọng Premium/Enhanced và nghe thử offline")
                }
                Text("Bài nghe sử dụng giọng Nhật của iOS, không phải audio JLPT chính thức. Cần có giọng ja-JP trên máy để phát offline ổn định.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Kỹ năng")
    }
}

struct GrammarListView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var search = ""
    private var filtered: [Grammar] {
        store.course.grammar.filter { g in
            search.isEmpty || [g.pattern, g.meaning, g.rule, g.example].joined(separator: " ")
                .localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        List(filtered) { item in
            NavigationLink {
                GrammarDetailView(item: item)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.pattern).font(.headline).foregroundColor(Palette.navy)
                    Text(item.displayMeaning).font(.subheadline).foregroundColor(.secondary)
                    Text("Tuần \(item.week)").font(.caption).foregroundColor(Palette.blue)
                }.padding(.vertical, 5)
            }
        }
        .searchable(text: $search, prompt: "Tìm mẫu ngữ pháp hoặc nghĩa")
        .navigationTitle("Ngữ pháp N2")
    }
}

struct GrammarDetailView: View {
    let item: Grammar
    @EnvironmentObject private var store: StudyStore
    @StateObject private var voice = JapaneseVoice.shared
    @State private var reviewFeedback: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LessonPanel {
                    Pill(text: "Tuần \(item.week)", color: Palette.blue)
                    Text(item.pattern).font(.largeTitle.bold()).foregroundColor(Palette.navy)
                    SectionTitle("Ý nghĩa")
                    Text(item.displayMeaning).foregroundColor(Palette.teal).font(.title3.weight(.semibold))
                    SectionTitle("Cấu trúc sử dụng")
                    Text(GrammarLibrary.structure(for: item))
                        .font(.headline).foregroundColor(Palette.blue)
                    SectionTitle("Dùng trong trường hợp nào?")
                    Text(item.displayRule).font(.body)
                }
                ForEach(Array(GrammarLibrary.examples(for: item).enumerated()), id: \.offset) { index, example in
                    LessonPanel {
                        HStack {
                            SectionTitle("Ví dụ \(index + 1)")
                            Button { voice.speak(example.text) } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.title3).padding(10)
                                    .background(Palette.teal.opacity(0.12), in: Circle())
                            }
                            .accessibilityLabel("Nghe ví dụ \(index + 1)")
                        }
                        FuriganaText(text: example.text, highlightTerms: GrammarFocus.terms(from: item.pattern))
                        Text(example.translation).font(.body).foregroundColor(.secondary)
                    }
                }
                if let error = voice.lastError {
                    Text(error).font(.caption).foregroundColor(.red)
                }
                if let reviewFeedback {
                    Label(reviewFeedback, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Palette.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityAddTraits(.updatesFrequently)
                }
                HStack(spacing: 12) {
                    MainButton(title: "Chưa thuộc", symbol: "arrow.counterclockwise", color: Palette.orange) {
                        store.review("g:\(item.id)", known: false)
                        reviewFeedback = "Đã lưu: chưa thuộc. Mẫu này sẽ được nhắc ôn lại."
                    }
                    MainButton(title: "Đã thuộc", symbol: "checkmark", color: Palette.teal) {
                        store.review("g:\(item.id)", known: true)
                        reviewFeedback = "Đã lưu: đã thuộc. Tiến độ ôn tập được cập nhật."
                    }
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Chi tiết ngữ pháp")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { voice.stop() }
    }
}

struct KanjiListView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var search = ""
    private var filtered: [Kanji] {
        store.course.kanji.filter { item in
            search.isEmpty || [item.char, item.meaning, item.on, item.kun, item.word]
                .joined(separator: " ").localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        List(filtered) { item in
            NavigationLink { KanjiDetailView(item: item) } label: {
                HStack(spacing: 16) {
                    Text(item.char)
                        .font(.system(size: 36, weight: .medium))
                        .frame(width: 50, height: 55)
                        .foregroundColor(Palette.navy)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayMeaning).font(.headline)
                        Text("On: \(item.on) • Kun: \(item.kun)")
                            .font(.caption).foregroundColor(.secondary)
                        // Chỉ hiển thị chữ Kanji đã duyệt; từ ghép chưa được duyệt
                        // nằm trong JSON nguồn và không xuất hiện ở danh sách học.
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Tìm Kanji, âm đọc, nghĩa")
        .navigationTitle("Kanji")
    }
}

struct KanjiDetailView: View {
    let item: Kanji
    @EnvironmentObject private var store: StudyStore
    @StateObject private var voice = JapaneseVoice.shared
    @State private var reviewFeedback: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LessonPanel {
                    Text(item.char)
                        .font(.system(size: 96, weight: .bold))
                        .foregroundColor(Palette.navy)
                        .frame(maxWidth: .infinity)
                    KanjiVocabularyView(item: item, vocabulary: store.course.vocab)
                    if let approved = store.course.vocab.first(where: {
                        candidate in
                        let compounds = item.word
                            .components(separatedBy: CharacterSet(charactersIn: "、,，/"))
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        return candidate.isApprovedForStudy && compounds.contains(candidate.word)
                    }) {
                        MainButton(title: "Nghe từ ghép", symbol: "speaker.wave.2") {
                            voice.speak(approved.word)
                        }
                    }
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Chi tiết Kanji")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if let reviewFeedback {
                    Label(reviewFeedback, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 10) {
                    MainButton(title: "Chưa thuộc", symbol: "arrow.counterclockwise",
                               color: Palette.orange) {
                        save(known: false)
                    }
                    MainButton(title: "Đã thuộc", symbol: "checkmark", color: Palette.teal) {
                        save(known: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .onDisappear { voice.stop() }
    }

    private func save(known: Bool) {
        store.review("k:\(item.id)", known: known)
        reviewFeedback = known ? "Đã lưu: Đã thuộc." : "Đã lưu: Chưa thuộc, sẽ ôn lại."
    }
}
