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
    @State private var isDraggingCard = false
    @State private var showFullExample = false
    @ObservedObject private var voice = JapaneseVoice.shared
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: Vocabulary? {
        cards.indices.contains(position) ? cards[position] : nil
    }

    var body: some View {
        GeometryReader { _ in
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
                            Pill(text: revealed ? "Tạm dừng" : "Tự chạy từ", color: Palette.teal)
                        } else {
                            Text(card.topic).font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                    cardSurface(card, height: 286)
                    // Giữ một hàng có chiều cao cố định dù đang ở mặt trước hay sau.
                    Button {
                        if revealed && card.hasApprovedExample { showFullExample = true }
                    } label: {
                        Label("Xem đầy đủ câu ví dụ", systemImage: "text.book.closed")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .opacity(revealed && card.hasApprovedExample ? 1 : 0)
                    .disabled(!revealed || !card.hasApprovedExample)
                    .accessibilityHidden(!revealed || !card.hasApprovedExample)
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
                        Text("Đổi từ mỗi").font(.caption).foregroundColor(.secondary)
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
                            if let sentence = card.approvedExampleJapanese { voice.speak(sentence) }
                        }
                        .disabled(!card.hasApprovedExample)
                        .opacity(card.hasApprovedExample ? 1 : 0.38)
                    }
                    HStack(spacing: 8) {
                        actionButton("Chưa thuộc", symbol: "arrow.counterclockwise", color: Palette.orange) {
                            mark(false, id: card.id)
                        }
                        actionButton("Đã thuộc", symbol: "checkmark", color: Palette.teal) {
                            mark(true, id: card.id)
                        }
                    }
                    Text("Tự chạy đổi từ; chạm thẻ để lật qua lại và tạm dừng khi xem nghĩa.")
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
                Text(voice.lastError ?? " ")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 16, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Palette.pale)
        .navigationTitle("Flashcard")
        .onReceive(ticker) { _ in
            guard autoPlay, !revealed, !cards.isEmpty, !isDraggingCard else { return }
            elapsed += 1
            if elapsed >= intervalSeconds { advanceRandom() }
        }
        .sheet(isPresented: $showFullExample) {
            if let card = current {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(card.word).font(.largeTitle.bold()).foregroundColor(Palette.navy)
                            Text(card.reading).font(.title3).foregroundColor(Palette.blue)
                            Text(card.displayMeaning).font(.headline).foregroundColor(Palette.teal)
                            Divider()
                            if let sentence = card.approvedExampleJapanese {
                                FuriganaText(
                                    text: sentence,
                                    mainWord: card.word,
                                    mainReading: card.reading,
                                    highlightTerms: VocabularyExampleFocus.variants(
                                        word: card.word, reading: card.reading, example: sentence),
                                    size: 19
                                )
                                Text(card.displayExampleTranslation).font(.body)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                    .navigationTitle("Chi tiết ví dụ")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Đóng") { showFullExample = false }
                        }
                    }
                }
            }
        }
        .onAppear { if cards.isEmpty { reload() } }
        .onChange(of: store.contentRevision) { _ in reload() }
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

    /// Toàn bộ thẻ là một vùng gesture duy nhất, không chứa ScrollView.
    /// Vuốt trái/lên: tiếp theo; phải/xuống: trước. Chạm: lật thẻ.
    private func cardSurface(_ card: Vocabulary, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(.white)
            VStack(spacing: 10) {
                if revealed {
                    Text(card.word)
                        .font(.system(size: 31, weight: .bold))
                        .foregroundColor(Palette.navy)
                    Text(card.reading)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.blue)
                    Text(card.displayMeaning)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.teal)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)
                    Divider()
                    if let sentence = card.approvedExampleJapanese {
                        // Câu Nhật và bản dịch có chung mép trái, không bị lệch hàng.
                        VStack(alignment: .leading, spacing: 8) {
                            FuriganaText(
                                text: sentence,
                                mainWord: card.word,
                                mainReading: card.reading,
                                highlightTerms: VocabularyExampleFocus.variants(
                                    word: card.word, reading: card.reading, example: sentence),
                                size: 15
                            )
                            .frame(maxWidth: .infinity, maxHeight: 78, alignment: .leading)
                            .clipped()
                            Text(card.displayExampleTranslation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                    Text("Chạm để xem mặt trước")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Spacer(minLength: 12)
                    Text(card.word)
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.navy)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                    Spacer(minLength: 12)
                    Label("Chạm để lật • Vuốt 4 hướng để đổi", systemImage: "hand.tap")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
        }
        .frame(height: height)
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.teal.opacity(0.18)))
        // Duy nhất một cử chỉ cho cả chạm lật và vuốt 4 hướng.
        // DragGesture(minimumDistance: 0) không cần TapGesture, tránh xung đột recognizer.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let dx = drag.translation.width
                    let dy = drag.translation.height
                    if max(abs(dx), abs(dy)) > 12 {
                        if !isDraggingCard {
                            isDraggingCard = true
                            voice.stop()
                        }
                        // Vuốt chỉ nhận hướng, không làm khung di chuyển.
                    }
                }
                .onEnded { drag in
                    let dx = drag.translation.width
                    let dy = drag.translation.height
                    let distance = max(abs(dx), abs(dy))
                    if distance <= 12 {
                        flip(card)
                    } else if abs(dx) > abs(dy) && abs(dx) >= 45 {
                        changeCard(by: dx < 0 ? 1 : -1)
                    } else if abs(dy) >= 45 {
                        changeCard(by: dy < 0 ? 1 : -1)
                    }
                    isDraggingCard = false
                }
        )
        // Kéo theo tay ngay lập tức; chỉ dùng spring khi nhả thẻ.
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(revealed ? "Mặt sau \(card.word), chạm để xem mặt trước." :
                                    "Mặt trước \(card.word), chạm để xem nghĩa.")
        .accessibilityAction(named: "Lật thẻ") { flip(card) }
        .accessibilityAction(named: "Từ tiếp theo") { changeCard(by: 1) }
        .accessibilityAction(named: "Từ trước") { changeCard(by: -1) }
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
        revealed = true
        elapsed = 0
        voice.speak(card.reading.isEmpty ? card.word : card.reading)
    }

    private func showFront() {
        guard revealed else { return }
        revealed = false
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
        case 0: cards = all.filter { $0.week <= store.studyWeekLimit && store.isDue("v:\($0.id)") }.shuffled()
        case 1: cards = all.filter { $0.week <= store.studyWeekLimit }.shuffled()
        default: cards = all.shuffled()
        }
        position = 0
        revealed = false
        elapsed = 0
        isDraggingCard = false
        voice.stop()
    }

    private func advanceRandom() {
        changeCard(by: 1)
    }

    private func changeCard(by step: Int) {
        guard !cards.isEmpty else { return }
        // Chọn từ MỚI trước khi thay đổi @State, không lấy từ closure của thẻ cũ.
        let nextIndex = (position + step + cards.count) % cards.count
        let next = cards[nextIndex]
        voice.stop()
        // Chỉ thay nội dung: khung và các nút giữ nguyên tọa độ.
        position = nextIndex
        revealed = false
        elapsed = 0
        voice.speak(next.reading.isEmpty ? next.word : next.reading)
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
    @State private var showFullGrammar = false
    @ObservedObject private var voice = JapaneseVoice.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionTitle("Thẻ ngữ pháp", subtitle: "Các mẫu được xáo trộn ở mỗi lượt học")
                if content.indices.contains(position) {
                    let g = content[position]
                    Pill(text: "\(position + 1) / \(content.count)", color: Palette.blue)
                    grammarCard(g)
                    // Cố định hàng điều khiển chi tiết dù thẻ đang ở mặt nào.
                    Button {
                        if revealed { showFullGrammar = true }
                    } label: {
                        Label("Xem cách dùng và ví dụ", systemImage: "text.book.closed")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .opacity(revealed ? 1 : 0)
                    .disabled(!revealed)
                    .accessibilityHidden(!revealed)
                    MainButton(title: "Nghe ví dụ", symbol: "speaker.wave.2.fill") {
                        if let approved = GrammarLibrary.examples(for: g).first {
                            voice.speak(approved.text)
                        }
                    }
                    .disabled(GrammarLibrary.examples(for: g).isEmpty)
                    .opacity(GrammarLibrary.examples(for: g).isEmpty ? 0.38 : 1)
                    Text(reviewMessage ?? " ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.teal)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .leading)
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
                Text(voice.lastError ?? " ")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 17, maxHeight: 17, alignment: .leading)
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Ngữ pháp")
        .sheet(isPresented: $showFullGrammar) {
            if content.indices.contains(position) {
                let item = content[position]
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(item.pattern).font(.title2.bold()).foregroundColor(Palette.navy)
                            Text(item.displayMeaning).font(.headline).foregroundColor(Palette.teal)
                            Text("Cách sử dụng: \(GrammarLibrary.structure(for: item))")
                                .font(.body).foregroundColor(Palette.navy)
                            ForEach(Array(GrammarLibrary.examples(for: item).enumerated()), id: \.offset) { index, example in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Ví dụ \(index + 1)")
                                        .font(.subheadline.bold()).foregroundColor(Palette.blue)
                                    FuriganaText(text: example.text,
                                                 highlightTerms: GrammarFocus.terms(from: item.pattern),
                                                 size: 17)
                                    Text(example.translation).font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Divider()
                            }
                        }
                        .padding(20)
                    }
                    .navigationTitle("Chi tiết ngữ pháp")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Đóng") { showFullGrammar = false }
                        }
                    }
                }
            }
        }
        .onAppear { if content.isEmpty { reload() } }
        .onChange(of: store.contentRevision) { _ in reload() }
        .onDisappear { voice.stop() }
    }


    /// Thẻ luôn có chiều cao cố định, không ScrollView lồng nhau và không dùng .offset.
    private func grammarCard(_ g: Grammar) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(.white)
            VStack(spacing: 14) {
                Text(g.pattern)
                    .font(.title2.bold())
                    .foregroundColor(Palette.navy)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                if revealed {
                    Text(g.displayMeaning)
                        .font(.headline)
                        .foregroundColor(Palette.teal)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                    Text(GrammarLibrary.structure(for: g))
                        .font(.subheadline)
                        .foregroundColor(Palette.navy)
                        .lineLimit(5)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.center)
                } else {
                    Spacer(minLength: 48)
                    Label("Chạm để xem nghĩa và cách dùng", systemImage: "hand.tap")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
                Text("Vuốt 4 hướng để đổi mẫu")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(18)
        }
        .frame(height: 286)
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.blue.opacity(0.18)))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { drag in
                    let dx = drag.translation.width
                    let dy = drag.translation.height
                    if max(abs(dx), abs(dy)) <= 12 {
                        flipGrammar()
                    } else if abs(dx) > abs(dy) && abs(dx) >= 45 {
                        changeGrammarCard(by: dx < 0 ? 1 : -1)
                    } else if abs(dy) >= 45 {
                        changeGrammarCard(by: dy < 0 ? 1 : -1)
                    }
                }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Lật thẻ") { flipGrammar() }
        .accessibilityAction(named: "Mẫu tiếp theo") { changeGrammarCard(by: 1) }
    }

    private func changeGrammarCard(by step: Int) {
        guard !content.isEmpty, !isSavingReview else { return }
        voice.stop()
        position = (position + step + content.count) % content.count
        revealed = false
        reviewMessage = nil
    }

    private func flipGrammar() {
        revealed.toggle()
        if !revealed { voice.stop() }
    }

    private func reload() {
        content = store.course.grammar.filter { $0.week <= store.studyWeekLimit }.shuffled()
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