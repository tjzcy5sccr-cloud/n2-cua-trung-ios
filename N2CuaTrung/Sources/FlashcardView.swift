import SwiftUI

struct FlashcardDeckView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var scope = 0
    @State private var cards: [Vocabulary] = []
    @State private var position = 0
    @State private var revealed = false
    @StateObject private var voice = JapaneseVoice.shared

    private var current: Vocabulary? {
        cards.indices.contains(position) ? cards[position] : nil
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 17) {
                SectionTitle("Flashcard từ vựng", subtitle: "Đọc Kanji, tự đoán rồi lật thẻ")
                Picker("Bộ thẻ", selection: $scope) {
                    Text("Cần ôn").tag(0)
                    Text("Đến tuần này").tag(1)
                    Text("Toàn bộ").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: scope) { _ in reload() }

                if let card = current {
                    HStack {
                        Pill(text: "\(position + 1)/\(cards.count)", color: Palette.blue)
                        Spacer()
                        Pill(text: card.topic, color: Palette.teal)
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { revealed.toggle() }
                    } label: {
                        VStack(spacing: 18) {
                            Text(card.word)
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundColor(Palette.navy)
                            Text(card.reading).font(.title3).foregroundColor(Palette.blue)
                            Divider().padding(.horizontal, 16)
                            if revealed {
                                Text(card.meaning)
                                    .font(.title3.weight(.bold)).foregroundColor(Palette.teal)
                                Text(card.example)
                                    .font(.body).foregroundColor(Palette.navy).multilineTextAlignment(.center)
                                HStack {
                                    Image(systemName: "speaker.wave.2")
                                    Text("Nhấn nút nghe bên dưới")
                                }.font(.caption).foregroundColor(.secondary)
                            } else {
                                Text("Chạm để xem nghĩa và ví dụ")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 285)
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.blue.opacity(0.10)))
                    }.buttonStyle(.plain)
                    HStack(spacing: 12) {
                        Button {
                            voice.speak("\(card.word)。\(card.example)")
                        } label: {
                            Label("Nghe", systemImage: "speaker.wave.2.fill")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                        Button {
                            voice.stop()
                        } label: {
                            Label("Dừng", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                    }
                    HStack(spacing: 12) {
                        MainButton(title: "Chưa nhớ", symbol: "arrow.counterclockwise", color: Palette.orange) {
                            mark(false, id: card.id)
                        }
                        MainButton(title: "Đã nhớ", symbol: "checkmark", color: Palette.teal) {
                            mark(true, id: card.id)
                        }
                    }
                    Text("Đánh dấu sau khi tự trả lời. Dữ liệu lưu trên iPhone.")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    LessonPanel {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle).foregroundColor(Palette.teal)
                        SectionTitle("Đã học xong bộ thẻ")
                        Text("Bạn có thể chọn bộ khác hoặc ôn lại vào ngày mai.")
                        MainButton(title: "Xem tất cả từ", symbol: "books.vertical") {
                            scope = 2
                            reload()
                        }
                    }
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Flashcard")
        .onAppear { if cards.isEmpty { reload() } }
        .onDisappear { voice.stop() }
    }

    private func reload() {
        let base = store.course.vocab
        if scope == 0 {
            cards = base.filter { $0.week <= store.week && store.isDue("v:\($0.id)") }.shuffled()
        } else if scope == 1 {
            cards = base.filter { $0.week <= store.week }.shuffled()
        } else {
            cards = base.shuffled()
        }
        position = 0
        revealed = false
    }

    private func mark(_ known: Bool, id: String) {
        store.review("v:\(id)", known: known)
        voice.stop()
        position += 1
        revealed = false
    }
}

struct GrammarFlashcardView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var position = 0
    @State private var showMeaning = false
    private var content: [Grammar] { store.course.grammar.filter { $0.week <= store.week } }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if content.indices.contains(position) {
                    let g = content[position]
                    Pill(text: "\(position + 1) / \(content.count)", color: Palette.blue)
                    Button { showMeaning.toggle() } label: {
                        VStack(spacing: 16) {
                            Text(g.pattern).font(.title.weight(.bold))
                            Text(g.example).font(.title3)
                            if showMeaning {
                                Divider()
                                Text(g.meaning).font(.headline).foregroundColor(Palette.teal)
                                Text(g.rule).font(.subheadline)
                                Text(g.translation).font(.subheadline).foregroundColor(.secondary)
                            } else {
                                Text("Chạm để xem nghĩa và cách dùng")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(Palette.navy)
                        .frame(maxWidth: .infinity, minHeight: 280)
                        .padding(24)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                    HStack(spacing: 12) {
                        MainButton(title: "Chưa nhớ", symbol: "xmark", color: Palette.orange) {
                            next(g.id, known: false)
                        }
                        MainButton(title: "Đã nhớ", symbol: "checkmark", color: Palette.teal) {
                            next(g.id, known: true)
                        }
                    }
                } else {
                    LessonPanel {
                        SectionTitle("Hoàn tất ngữ pháp")
                        Text("Bạn đã duyệt hết các thẻ ngữ pháp đang mở.")
                        MainButton(title: "Học lại", symbol: "arrow.clockwise") {
                            position = 0
                            showMeaning = false
                        }
                    }
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Thẻ ngữ pháp")
    }
    private func next(_ id: String, known: Bool) {
        store.review("g:\(id)", known: known)
        position += 1
        showMeaning = false
    }
}
