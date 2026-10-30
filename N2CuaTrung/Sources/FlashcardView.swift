import SwiftUI

struct FlashcardDeckView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var scope = 0
    @State private var cards: [Vocabulary] = []
    @State private var position = 0
    @State private var revealed = false
    @ObservedObject private var voice = JapaneseVoice.shared

    private var current: Vocabulary? { cards.indices.contains(position) ? cards[position] : nil }

    var body: some View {
        // Không đặt flashcard trong ScrollView: vuốt thẻ sẽ không kéo cả nền.
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                SectionTitle("Flashcard từ vựng", subtitle: "Chạm để lật • Vuốt lên/xuống để đổi từ ngẫu nhiên")
                Picker("Bộ thẻ", selection: $scope) {
                    Text("Cần ôn").tag(0)
                    Text("Đến tuần").tag(1)
                    Text("Tất cả").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: scope) { _ in reload() }
                if let card = current {
                    HStack {
                        Pill(text: "\(position + 1) / \(cards.count)", color: Palette.blue)
                        Spacer()
                        Pill(text: card.topic.hasPrefix("OpenJLPT") ? "Từ vựng N2" : card.topic, color: Palette.teal)
                    }
                    Button {
                        let revealAnswer = !revealed
                        withAnimation(.easeInOut(duration: 0.18)) { revealed = revealAnswer }
                        if revealAnswer {
                            // Hiragana tránh phát âm sai các từ Kanji đa âm.
                            voice.speak(card.reading.isEmpty ? card.word : card.reading)
                        } else {
                            voice.stop()
                        }
                    } label: {
                        VStack(spacing: 16) {
                            if !revealed {
                                Spacer(minLength: 10)
                                Text(card.word)
                                    .font(.system(size: 50, weight: .bold, design: .rounded))
                                    .minimumScaleFactor(0.5)
                                    .foregroundColor(Palette.navy)
                                Spacer(minLength: 10)
                                Label("Chạm để lật thẻ", systemImage: "hand.tap")
                                    .font(.subheadline).foregroundColor(.secondary)
                            } else {
                                Text(card.word)
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(Palette.navy)
                                Text(card.reading)
                                    .font(.title3.weight(.medium)).foregroundColor(Palette.blue)
                                Text(card.displayMeaning)
                                    .font(.title3.weight(.bold)).foregroundColor(Palette.teal)
                                Divider()
                                Text("Ví dụ có Hiragana")
                                    .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                                FuriganaText(text: card.example, mainWord: card.word, mainReading: card.reading)
                                Text(card.exampleVi ?? "Bản dịch tiếng Việt cho câu này đang được bổ sung.")
                                    .font(.subheadline)
                                    .foregroundColor(Palette.navy)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                Label("Chạm để xem lại mặt trước", systemImage: "arrow.uturn.backward")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 225)
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                        .contentShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.teal.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 34)
                            .onEnded { movement in
                                let dy = movement.translation.height
                                let dx = movement.translation.width
                                if abs(dy) > 48 && abs(dy) > abs(dx) * 1.25 {
                                    advanceRandom()
                                }
                            }
                    )
                    .accessibilityAction(named: "Từ ngẫu nhiên kế tiếp") { advanceRandom() }
                    .accessibilityLabel(revealed ? "\(card.word), \(card.reading), \(card.displayMeaning)" : "Thẻ Kanji \(card.word). Chạm để xem đáp án")
                    HStack(spacing: 10) {
                        MainButton(title: "Nghe từ", symbol: "speaker.wave.2.fill", color: Palette.blue) {
                            voice.speak(card.reading.isEmpty ? card.word : card.reading)
                        }
                        MainButton(title: "Nghe ví dụ", symbol: "play.fill", color: Palette.teal) {
                            voice.speak(card.example)
                        }
                        Button { voice.stop() } label: {
                            Image(systemName: "stop.fill").frame(width: 44, height: 46)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).accessibilityLabel("Dừng audio")
                    }
                    HStack(spacing: 10) {
                        MainButton(title: "Chưa nhớ", symbol: "arrow.counterclockwise", color: Palette.orange) {
                            mark(false, id: card.id)
                        }
                        MainButton(title: "Đã nhớ", symbol: "checkmark", color: Palette.teal) {
                            mark(true, id: card.id)
                        }
                    }
                    Text("Vuốt lên/xuống trên thẻ để đổi từ. Chạm để lật và nghe phát âm.")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    LessonPanel {
                        SectionTitle("Hoàn thành bộ thẻ")
                        Text("Bạn đã duyệt hết các thẻ của lượt này.")
                        MainButton(title: "Ôn lại ngẫu nhiên", symbol: "shuffle", color: Palette.teal) { reload() }
                        MainButton(title: "Xem toàn bộ", symbol: "books.vertical") {
                            scope = 2
                            reload()
                        }
                    }
                }
                if let error = voice.lastError { Text(error).font(.caption).foregroundColor(.red) }
            }.padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.pale)
        .navigationTitle("Flashcard")
        .onAppear { if cards.isEmpty { reload() } }
        .onDisappear { voice.stop() }
    }

    private func reload() {
        let base = store.course.vocab
        switch scope {
        case 0: cards = base.filter { $0.week <= store.week && store.isDue("v:\($0.id)") }.shuffled()
        case 1: cards = base.filter { $0.week <= store.week }.shuffled()
        default: cards = base.shuffled()
        }
        position = 0
        revealed = false
        voice.stop()
    }

    private func advanceRandom() {
        voice.stop()
        revealed = false
        if position + 1 < cards.count {
            position += 1
        } else {
            // Hết bộ thẻ: xáo trộn và bắt đầu lượt tiếp theo tự động.
            reload()
        }
    }

    private func mark(_ known: Bool, id: String) {
        store.review("v:\(id)", known: known)
        advanceRandom()
    }
}

struct GrammarFlashcardView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var content: [Grammar] = []
    @State private var position = 0
    @State private var revealed = false
    @ObservedObject private var voice = JapaneseVoice.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionTitle("Thẻ ngữ pháp", subtitle: "Các mẫu được xáo trộn ở mỗi lượt học")
                if content.indices.contains(position) {
                    let g = content[position]
                    Pill(text: "\(position + 1) / \(content.count)", color: Palette.blue)
                    Button { revealed.toggle() } label: {
                        VStack(spacing: 14) {
                            Text(g.pattern).font(.title.weight(.bold)).foregroundColor(Palette.navy)
                            if revealed {
                                Text(g.displayMeaning).font(.headline).foregroundColor(Palette.teal)
                                Text("Cách sử dụng: \(GrammarLibrary.structure(for: g))")
                                    .font(.subheadline).foregroundColor(Palette.navy)
                                ForEach(Array(GrammarLibrary.examples(for: g).enumerated()), id: \.offset) { i, example in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Ví dụ \(i + 1)").font(.caption.bold()).foregroundColor(Palette.blue)
                                        FuriganaText(text: example.text, highlightTerms: GrammarFocus.terms(from: g.pattern), size: 16)
                                        Text(example.translation).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                Spacer(minLength: 65)
                                Label("Chạm để xem cách dùng + 3 ví dụ", systemImage: "hand.tap")
                                    .font(.subheadline).foregroundColor(.secondary)
                                Spacer(minLength: 65)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 270)
                        .padding(20)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                    MainButton(title: "Nghe ví dụ", symbol: "speaker.wave.2.fill") {
                        voice.speak(GrammarLibrary.examples(for: g)[0].text)
                    }
                    HStack(spacing: 10) {
                        MainButton(title: "Chưa nhớ", symbol: "xmark", color: Palette.orange) { next(g.id, known: false) }
                        MainButton(title: "Đã nhớ", symbol: "checkmark", color: Palette.teal) { next(g.id, known: true) }
                    }
                } else {
                    LessonPanel {
                        SectionTitle("Hoàn tất lượt ôn")
                        MainButton(title: "Ôn lại ngẫu nhiên", symbol: "shuffle") { reload() }
                    }
                }
                if let error = voice.lastError { Text(error).font(.caption).foregroundColor(.red) }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Ngữ pháp")
        .onAppear { if content.isEmpty { reload() } }
        .onDisappear { voice.stop() }
    }

    private func reload() {
        content = store.course.grammar.filter { $0.week <= store.week }.shuffled()
        position = 0
        revealed = false
    }
    private func next(_ id: String, known: Bool) {
        store.review("g:\(id)", known: known)
        position += 1
        revealed = false
        voice.stop()
    }
}