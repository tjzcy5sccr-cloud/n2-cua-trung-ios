import SwiftUI

struct PracticeHubView: View {
    @EnvironmentObject private var store: StudyStore
    var body: some View {
        ScrollView {
            VStack(spacing: 13) {
                SectionTitle("Luyện JLPT N2", subtitle: "Chọn kỹ năng muốn luyện – hoạt động offline")
                NavigationLink { GrammarListView() } label: {
                    ActionTile(icon: "textformat.abc", color: Palette.blue,
                               title: "Ngữ pháp", detail: "\(store.course.grammar.count) mẫu • Giải thích & ví dụ")
                }
                NavigationLink { GrammarFlashcardView() } label: {
                    ActionTile(icon: "rectangle.on.rectangle", color: Palette.teal,
                               title: "Flashcard ngữ pháp", detail: "Tự nhớ và ôn cách quãng")
                }
                NavigationLink { KanjiListView() } label: {
                    ActionTile(icon: "character.square", color: Palette.orange,
                               title: "Kanji", detail: "\(store.course.kanji.count) chữ • On, Kun, từ ghép")
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
                    QuestionSessionView(questions: QuestionBank.kanji(store.course).shuffled(),
                                        type: "Kanji")
                } label: {
                    ActionTile(icon: "character.cursor.ibeam", color: Palette.orange,
                               title: "Trắc nghiệm Kanji", detail: "Tập nhận biết mặt chữ")
                }
                NavigationLink {
                    QuestionSessionView(questions: QuestionBank.reading(store.course).shuffled(), type: "Đọc hiểu")
                } label: {
                    ActionTile(icon: "doc.text", color: Palette.blue,
                               title: "Đọc hiểu", detail: "\(store.course.readings.count) đoạn và bài tập")
                }
                NavigationLink {
                    QuestionSessionView(questions: QuestionBank.listening(store.course).shuffled(), type: "Nghe hiểu")
                } label: {
                    ActionTile(icon: "headphones", color: Palette.teal,
                               title: "Nghe hiểu", detail: "\(store.course.listening.count) hội thoại với giọng iOS")
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
                    Text(item.meaning).font(.subheadline).foregroundColor(.secondary)
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LessonPanel {
                    Pill(text: "Tuần \(item.week)", color: Palette.blue)
                    Text(item.pattern).font(.largeTitle.bold()).foregroundColor(Palette.navy)
                    SectionTitle("Ý nghĩa")
                    Text(item.meaning).foregroundColor(Palette.teal).font(.title3.weight(.semibold))
                    SectionTitle("Cấu trúc sử dụng")
                    Text(GrammarLibrary.structure(for: item))
                        .font(.headline).foregroundColor(Palette.blue)
                    SectionTitle("Dùng trong trường hợp nào?")
                    Text(item.rule).font(.body)
                }
                ForEach(Array(GrammarLibrary.examples(for: item).enumerated()), id: \.offset) { index, example in
                    LessonPanel {
                        HStack {
                            SectionTitle("Ví dụ \(index + 1) / 3")
                            Button { voice.speak(example.text) } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.title3).padding(10)
                                    .background(Palette.teal.opacity(0.12), in: Circle())
                            }
                            .accessibilityLabel("Nghe ví dụ \(index + 1)")
                        }
                        FuriganaText(text: example.text)
                        Text(example.translation).font(.body).foregroundColor(.secondary)
                    }
                }
                if let error = voice.lastError {
                    Text(error).font(.caption).foregroundColor(.red)
                }
                HStack(spacing: 12) {
                    MainButton(title: "Chưa thuộc", symbol: "arrow.counterclockwise", color: Palette.orange) {
                        store.review("g:\(item.id)", known: false)
                    }
                    MainButton(title: "Đã thuộc", symbol: "checkmark", color: Palette.teal) {
                        store.review("g:\(item.id)", known: true)
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
                        Text(item.meaning).font(.headline)
                        Text("On: \(item.on) • Kun: \(item.kun)")
                            .font(.caption).foregroundColor(.secondary)
                        Text("Ví dụ: \(item.word)").font(.caption).foregroundColor(Palette.blue)
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
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LessonPanel {
                    Text(item.char)
                        .font(.system(size: 100))
                        .foregroundColor(Palette.navy)
                        .frame(maxWidth: .infinity)
                    SectionTitle("Nghĩa", subtitle: item.meaning)
                    SectionTitle("Âm On", subtitle: item.on)
                    SectionTitle("Âm Kun", subtitle: item.kun)
                    SectionTitle("Từ ghép")
                    FuriganaText(text: item.word)
                    MainButton(title: "Nghe từ ghép", symbol: "speaker.wave.2") {
                        voice.speak(item.word)
                    }
                }
                HStack(spacing: 12) {
                    MainButton(title: "Chưa nhớ", symbol: "xmark", color: Palette.orange) {
                        store.review("k:\(item.id)", known: false)
                    }
                    MainButton(title: "Đã nhớ", symbol: "checkmark", color: Palette.teal) {
                        store.review("k:\(item.id)", known: true)
                    }
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Chi tiết Kanji")
        .onDisappear { voice.stop() }
    }
}