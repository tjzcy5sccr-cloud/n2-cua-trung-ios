import SwiftUI

struct FlashcardDeckView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var scope = 0
    @State private var cards: [Vocabulary] = []
    @State private var position = 0
    @State private var revealed = false
    @State private var autoPlay = false
    @State private var intervalSeconds = 5
    @State private var elapsed = 0
    @ObservedObject private var voice = JapaneseVoice.shared
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: Vocabulary? {
        cards.indices.contains(position) ? cards[position] : nil
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 9) {
                SectionTitle("Flashcard từ vựng", subtitle: "Chạm để lật • Vuốt ngang hoặc dọc để đổi từ")
                Picker("Bộ thẻ", selection: $scope) {
                    Text("Cần ôn").tag(0)
                    Text("Đến tuần").tag(1)
                    Text("Tất cả").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: scope) { _ in reload() }

                if let card = current {
                    HStack(spacing: 8) {
                        Pill(text: "\(position + 1) / \(cards.count)", color: Palette.blue)
                        Spacer(minLength: 4)
                        if autoPlay {
                            Pill(text: revealed ? "Tạm dừng" : "Tự chạy Kanji", color: Palette.teal)
                        } else {
                            Text(card.topic).font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                    cardSurface(card, height: min(320, max(205, geometry.size.height * 0.42)))
                    HStack(spacing: 8) {
                        actionButton(
                            autoPlay ? "Dừng tự chạy" : "Tự chạy",
                            symbol: autoPlay ? "pause.fill" : "play.fill",
                            color: autoPlay ? Palette.orange : Palette.teal
                        ) { toggleAuto() }
                        actionButton("Từ tiếp theo", symbol: "forward.end.fill", color: Palette.blue) {
                            advanceRandom()
                        }
                    }
                    HStack(spacing: 8) {
                        Text("Đổi Kanji mỗi").font(.caption).foregroundColor(.secondary)
                        Picker("Thời gian chuyển tự động", selection: $intervalSeconds) {
                            Text("3 giây").tag(3)
                            Text("5 giây").tag(5)
                            Text("8 giây").tag(8)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: intervalSeconds) { _ in elapsed = 0 }
                    }
                    HStack(spacing: 8) {
                        actionButton("Nghe từ", symbol: "speaker.wave.2.fill", color: Palette.blue) {
                            voice.speak(card.reading.isEmpty ? card.word : card.reading)
                        }
                        actionButton("Nghe ví dụ", symbol: "waveform", color: Palette.teal) {
                            voice.speak(card.example)
                        }
                    }
                    HStack(spacing: 8) {
                        actionButton("Chưa thuộc", symbol: "arrow.counterclockwise", color: Palette.orange) {
                            mark(false, id: card.id)
                        }
                        actionButton("Đã thuộc", symbol: "checkmark", color: Palette.teal) {
                            mark(true, id: card.id)
                        }
                    }
                    Text("Tự chạy đổi Kanji; chạm thẻ để lật qua lại và tạm dừng khi xem nghĩa.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    LessonPanel {
                        SectionTitle("Đã hoàn thành lượt ôn")
                        MainButton(title: "Ôn lại ngẫu nhiên", symbol: "shuffle") { reload() }
                        MainButton(title: "Xem toàn bộ", symbol: "books.vertical") {
                            scope = 2
                            reload()
                        }
                    }
                }
                if let error = voice.lastError {
                    Text(error).font(.caption2).foregroundColor(.red)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Palette.pale)
        .navigationTitle("Flashcard")
        .onReceive(ticker) { _ in
            guard autoPlay, !revealed, !cards.isEmpty else { return }
            elapsed += 1
            if elapsed >= intervalSeconds { advanceRandom() }
        }
        .onAppear { if cards.isEmpty { reload() } }
        .onDisappear {
            autoPlay = false
            voice.stop()
        }
    }

    private func actionButton(_ title: String, symbol: String, color: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 7)
                .foregroundColor(.white)
                .background(color, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// Nút chạm nằm TRONG vùng cuộn: ScrollView chỉ xử lý vuốt, Button xử lý chạm.
    /// Không gắn TapGesture lên ScrollView cha vì iOS có thể bỏ qua sự kiện.
    private func cardSurface(_ card: Vocabulary, height: CGFloat) -> some View {
        ZStack {
            if revealed {
                ScrollView(.vertical) {
                    Button {
                        flip(card)
                    } label: {
                        VStack(spacing: 10) {
                            Text(card.word)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Palette.navy)
                            Text(card.reading)
                                .font(.title3.weight(.medium))
                                .foregroundColor(Palette.blue)
                            Text(card.displayMeaning)
                                .font(.title3.weight(.bold))
                                .foregroundColor(Palette.teal)
                                .multilineTextAlignment(.center)
                            Divider()
                            FuriganaText(text: card.example,
                                         mainWord: card.word, mainReading: card.reading, size: 17)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(card.displayExampleTranslation)
                                .font(.subheadline)
                                .foregroundColor(Palette.navy)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(1, height - 30))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mặt sau. Chạm để quay về mặt trước.")
                }
            } else {
                Button {
                    flip(card)
                } label: {
                    VStack(spacing: 12) {
                        Spacer(minLength: 10)
                        Text(card.word)
                            .font(.system(size: 50, weight: .bold, design: .rounded))
                            .foregroundColor(Palette.navy)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                        Spacer(minLength: 10)
                        Label("Chạm để lật", systemImage: "hand.tap")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mặt trước. Chạm để xem nghĩa.")

            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.horizontal, 15)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.teal.opacity(0.18)))
        // Một cử chỉ cho cả hai mặt. Không chiếm sự kiện chạm hoặc cuộn.
        .simultaneousGesture(
            DragGesture(minimumDistance: 28).onEnded { movement in
                let dx = movement.translation.width
                let dy = movement.translation.height
                let horizontal = abs(dx) >= 58 && abs(dx) > abs(dy) * 1.15
                let vertical = abs(dy) >= 92 && abs(dy) > abs(dx) * 1.15
                if horizontal || vertical { advanceRandom() }
            }
        )
        .accessibilityAction(named: "Thẻ tiếp theo") { advanceRandom() }
    }

    private func flip(_ card: Vocabulary) {
        if revealed {
            showFront()
        } else {
            showBack(card)
        }
    }

    private func showBack(_ card: Vocabulary) {
        guard !revealed else { return }
        withAnimation(.easeInOut(duration: 0.15)) { revealed = true }
        elapsed = 0
        voice.speak(card.reading.isEmpty ? card.word : card.reading)
    }

    private func showFront() {
        guard revealed else { return }
        withAnimation(.easeInOut(duration: 0.15)) { revealed = false }
        elapsed = 0
        voice.stop()
    }

    private func toggleAuto() {
        autoPlay.toggle()
        elapsed = 0
        if autoPlay {
            revealed = false
            voice.stop()
        }
    }

    private func reload() {
        let all = store.course.vocab
        switch scope {
        case 0: cards = all.filter { $0.week <= store.week && store.isDue("v:\($0.id)") }.shuffled()
        case 1: cards = all.filter { $0.week <= store.week }.shuffled()
        default: cards = all.shuffled()
        }
        position = 0
        revealed = false
        elapsed = 0
        voice.stop()
    }

    private func advanceRandom() {
        voice.stop()
        revealed = false
        elapsed = 0
        if position + 1 < cards.count {
            position += 1
        } else {
            reload()
        }
        // Phát âm thẻ MỚI, không dùng card đã bị SwiftUI giữ trong gesture cũ.
        if let next = current {
            voice.speak(next.reading.isEmpty ? next.word : next.reading)
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
    @State private var reviewMessage: String?
    @State private var isSavingReview = false
    @ObservedObject private var voice = JapaneseVoice.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionTitle("Thẻ ngữ pháp", subtitle: "Các mẫu được xáo trộn ở mỗi lượt học")
                if content.indices.contains(position) {
                    let g = content[position]
                    Pill(text: "\(position + 1) / \(content.count)", color: Palette.blue)
                    ScrollView {
                        Button {
                            flipGrammar()
                        } label: {
                            VStack(spacing: 14) {
                                Text(g.pattern)
                                    .font(.title.weight(.bold))
                                    .foregroundColor(Palette.navy)
                                if revealed {
                                    Text(g.displayMeaning).font(.headline).foregroundColor(Palette.teal)
                                    Text("Cách sử dụng: \(GrammarLibrary.structure(for: g))")
                                        .font(.subheadline).foregroundColor(Palette.navy)
                                    ForEach(Array(GrammarLibrary.examples(for: g).enumerated()), id: \.offset) { i, example in
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("Ví dụ \(i + 1)").font(.caption.bold()).foregroundColor(Palette.blue)
                                            FuriganaText(text: example.text,
                                                         highlightTerms: GrammarFocus.terms(from: g.pattern), size: 16)
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
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 326)
                            .padding(12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(revealed ? "Mặt sau ngữ pháp. Chạm xem mặt trước." :
                                                      "Mặt trước ngữ pháp. Chạm xem lời giải.")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 350)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    MainButton(title: "Nghe ví dụ", symbol: "speaker.wave.2.fill") {
                        voice.speak(GrammarLibrary.examples(for: g)[0].text)
                    }
                    if let reviewMessage {
                        Label(reviewMessage, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Palette.teal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 10) {
                        MainButton(title: "Chưa thuộc", symbol: "arrow.counterclockwise", color: Palette.orange) { next(g.id, known: false) }
                            .disabled(isSavingReview)
                        MainButton(title: "Đã thuộc", symbol: "checkmark", color: Palette.teal) { next(g.id, known: true) }
                            .disabled(isSavingReview)
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

    private func flipGrammar() {
        withAnimation(.easeInOut(duration: 0.15)) {
            revealed.toggle()
        }
        if !revealed { voice.stop() }
    }

    private func reload() {
        content = store.course.grammar.filter { $0.week <= store.week }.shuffled()
        position = 0
        revealed = false
        reviewMessage = nil
        isSavingReview = false
    }
    private func next(_ id: String, known: Bool) {
        guard !isSavingReview else { return }
        isSavingReview = true
        store.review("g:\(id)", known: known)
        reviewMessage = known ? "Đã lưu: đã thuộc • Chuyển mẫu tiếp theo" : "Đã lưu: cần ôn lại • Chuyển mẫu tiếp theo"
        voice.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeInOut(duration: 0.15)) {
                if position + 1 < content.count {
                    position += 1
                    revealed = false
                    reviewMessage = nil
                    isSavingReview = false
                } else {
                    reload()
                }
            }
        }
    }
}