import SwiftUI

struct FlashcardDeckView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var scope = 0
    @State private var cards: [Vocabulary] = []
    @State private var position = 0
    @State private var revealed = false
    @State private var autoPlay = false
    private let autoAdvanceSeconds = 3
    @State private var elapsed = 0
    @State private var isDraggingCard = false
    @State private var showFullExample = false
    @ObservedObject private var voice = JapaneseVoice.shared
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: Vocabulary? {
        cards.indices.contains(position) ? cards[position] : nil
    }

    /// Âm Hán–Việt trên mặt sau, lấy từ thẻ Kanji đã duyệt hoặc bảng
    /// tham chiếu Hán–Việt của ứng dụng. Không tự suy đoán âm thiếu.
    /// Chỉ hiển thị khi tra được toàn bộ Kanji của từ.
    private func sinoVietnamese(for word: String) -> String? {
        let studied = store.course.kanji.reduce(into: [String: String]()) { known, item in
            guard item.isApprovedForStudy,
                  let value = item.hanViet?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return }
            // Một chữ có thể thuộc nhiều gói; tránh lỗi trùng khóa khi gộp.
            if known[item.char] == nil { known[item.char] = value }
        }
        var readings: [String] = []
        for scalar in word.unicodeScalars {
            let value = scalar.value
            guard (0x3400...0x9FFF).contains(value) ||
                  (0xF900...0xFAFF).contains(value) else { continue }
            let character = String(scalar)
            let reading = studied[character] ??
                KangxiReference.info(for: character)?.sinoVietnamese
            guard let sound = reading?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sound.isEmpty,
                  // Một Kanji có nhiều âm chưa xác định theo ngữ cảnh:
                  // không tự chọn cách đọc đầu tiên.
                  !sound.contains(","), !sound.contains("、"),
                  !sound.contains("/"), !sound.contains("／")
            else { return nil }
            readings.append(sound.lowercased())
        }
        return readings.isEmpty ? nil : readings.joined(separator: " ")
    }

    var body: some View {
        // No outer ScrollView. The available NavigationStack/TabView safe area
        // sizes one stable card. Gestures never scroll the background.
        GeometryReader { proxy in
            // Keep ALL controls inside the TabView + NavigationStack safe area.
            // Reserve exact heights for every control before sizing the stationary card.
            let compact = proxy.size.height < 690
            let shortScreen = proxy.size.height < 520
            let gap: CGFloat = shortScreen ? 3 : (compact ? 5 : 7)
            let actionHeight: CGFloat = 44
            let pickerHeight: CGFloat = shortScreen ? 29 : 32
            let statusHeight: CGFloat = 28
            let verticalPadding: CGFloat = shortScreen ? 4 : 7
            let showsError = !(voice.lastError ?? "").isEmpty
            let errorHeight: CGFloat = showsError ? 15 : 0
            let gapCount: CGFloat = showsError ? 6 : 5
            let controlsHeight = (pickerHeight + statusHeight + actionHeight * 3
                + gap * gapCount + verticalPadding * 2 + errorHeight)
            let cardHeight = max(72, proxy.size.height - controlsHeight)
            VStack(spacing: gap) {
                Picker("Bộ thẻ", selection: $scope) {
                    Text("Cần ôn").tag(0)
                    Text("Đến tuần").tag(1)
                    Text("Tất cả").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(height: pickerHeight)
                .onChange(of: scope) { _ in reload() }
                if let card = current {
                    HStack(spacing: 8) {
                        Pill(text: "\(position + 1)/\(cards.count)", color: Palette.blue)
                        Spacer(minLength: 4)
                        Text("Chạm lật · Vuốt 4 hướng đổi từ")
                            .font(.caption2).foregroundColor(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.78)
                    }
                    .frame(height: statusHeight)
                    cardSurface(card, height: cardHeight, compact: compact || cardHeight < 270)
                    // Full-width, equal-sized audio buttons, matching the mastery row.
                    HStack(spacing: 7) {
                        smallAction("Nghe từ", symbol: "speaker.wave.2", color: Palette.blue, height: actionHeight) {
                            voice.speak(card.reading.isEmpty ? card.word : card.reading)
                        }
                        smallAction("Nghe ví dụ", symbol: "waveform", color: Palette.teal, height: actionHeight) {
                            if let example = card.approvedExampleJapanese { voice.speak(example) }
                        }
                        .disabled(!card.hasApprovedExample)
                        .opacity(card.hasApprovedExample ? 1 : 0.4)
                    }
                    HStack(spacing: 7) {
                        smallAction(autoPlay ? "Dừng tự chạy" : "Tự chạy",
                                    symbol: autoPlay ? "pause.fill" : "play.fill",
                                    color: autoPlay ? Palette.orange : Palette.teal, height: actionHeight) {
                            toggleAuto()
                        }
                        smallAction("Từ tiếp theo", symbol: "arrow.right", color: Palette.blue, height: actionHeight) {
                            advanceRandom()
                        }
                    }
                    HStack(spacing: 7) {
                        smallAction("Chưa thuộc", symbol: "arrow.counterclockwise",
                                    color: Palette.orange, height: actionHeight) { mark(false, id: card.id) }
                        smallAction("Đã thuộc", symbol: "checkmark",
                                    color: Palette.teal, height: actionHeight) { mark(true, id: card.id) }
                    }
                } else {
                    LessonPanel {
                        SectionTitle("Chưa có thẻ để ôn",
                                     subtitle: store.selectedSeries == .souMatome
                                        ? "Nhập PDF và mục sách, kiểm tra rồi duyệt để học Sou Matome."
                                        : "Đổi sang Tất cả hoặc một bộ học khác.")
                        MainButton(title: "Xem toàn bộ", symbol: "books.vertical") {
                            scope = 2
                            reload()
                        }
                        if store.selectedSeries == .souMatome {
                            NavigationLink {
                                SouMatomeWholeBooksView()
                            } label: {
                                Label("Mở thư viện sách Sou Matome", systemImage: "books.vertical")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let error = voice.lastError, !error.isEmpty {
                    Text(error)
                        .font(.caption2).foregroundColor(.red).lineLimit(1)
                        .frame(height: errorHeight)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .frame(width: proxy.size.width, height: proxy.size.height,
                   alignment: .top)
        }
        .background(Palette.pale)
        .navigationTitle("Flashcard")
        .navigationBarTitleDisplayMode(.inline)
        // Detail action moves into the navigation bar instead of shrinking audio buttons.
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFullExample = true
                } label: {
                    Image(systemName: "text.book.closed")
                }
                .disabled(!revealed || !(current?.hasApprovedExample ?? false))
                .accessibilityLabel("Xem đầy đủ ví dụ")
            }
        }
        .onReceive(ticker) { _ in
            guard autoPlay, !revealed, !cards.isEmpty, !isDraggingCard else { return }
            elapsed += 1
            if elapsed >= autoAdvanceSeconds { advanceRandom() }
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

    private func smallAction(_ title: String, symbol: String, color: Color,
                             height: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundColor(.white)
                .background(color, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    /// Toàn bộ thẻ là một vùng gesture duy nhất, không chứa ScrollView.
    /// Vuốt trái/lên: tiếp theo; phải/xuống: trước. Chạm: lật thẻ.
    private func cardSurface(_ card: Vocabulary, height: CGFloat,
                             compact: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(.white)
            VStack(spacing: compact ? 5 : 8) {
                Spacer(minLength: 0)
                if revealed {
                    // Thứ tự mặt sau: chữ Nhật lớn → âm Hán–Việt → hiragana → nghĩa Việt.
                    Text(card.word)
                        .font(.system(size: compact ? 33 : 40, weight: .bold))
                        .foregroundColor(Palette.navy)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                    if let hanViet = sinoVietnamese(for: card.word) {
                        Text(hanViet)
                            .font(.system(size: compact ? 17 : 20, weight: .semibold))
                            .foregroundColor(Palette.orange)
                            .multilineTextAlignment(.center)
                            .lineLimit(2).minimumScaleFactor(0.75)
                    }
                    if !card.reading.isEmpty {
                        Text(card.reading)
                            .font(.system(size: compact ? 16 : 19, weight: .medium))
                            .foregroundColor(Palette.blue)
                            .multilineTextAlignment(.center)
                            .lineLimit(1).minimumScaleFactor(0.78)
                    }
                    Text(card.displayMeaning)
                        .font(.system(size: compact ? 19 : 23, weight: .semibold))
                        .foregroundColor(Palette.teal)
                        .multilineTextAlignment(.center)
                        .lineLimit(compact ? 2 : 3)
                        .minimumScaleFactor(0.74)
                    if let sentence = card.approvedExampleJapanese {
                        Divider()
                        if height >= 270 && sentence.count <= (compact ? 54 : 95) {
                            VStack(alignment: .center, spacing: compact ? 5 : 8) {
                                FuriganaText(
                                    text: sentence,
                                    mainWord: card.word,
                                    mainReading: card.reading,
                                    highlightTerms: VocabularyExampleFocus.variants(
                                        word: card.word, reading: card.reading,
                                        example: sentence),
                                    size: compact ? 12 : 14,
                                    centered: true
                                )
                                Text(card.displayExampleTranslation)
                                    .font(.system(size: compact ? 11 : 13))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(compact ? 2 : 3)
                                    .minimumScaleFactor(0.76)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Label("Ví dụ dài — xem biểu tượng sách phía trên", systemImage: "text.book.closed")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(card.word)
                        .font(.system(size: compact ? 43 : 53,
                                      weight: .bold, design: .rounded))
                        .foregroundColor(Palette.navy)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.55)
                }
                Spacer(minLength: 0)
                Text(revealed ? "Chạm để xem mặt trước" : "Chạm để lật")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(compact ? 10 : 15)
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
                    } else if abs(dx) >= abs(dy) && abs(dx) >= 45 {
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
        GeometryReader { proxy in
            let compact = proxy.size.height < 690
            let shortScreen = proxy.size.height < 520
            let gap: CGFloat = shortScreen ? 4 : (compact ? 6 : 8)
            let actionHeight: CGFloat = 44
            let statusHeight: CGFloat = 28
            let verticalPadding: CGFloat = shortScreen ? 4 : 8
            let hasMessage = !(reviewMessage ?? voice.lastError ?? "").isEmpty
            let messageHeight: CGFloat = hasMessage ? 15 : 0
            let gapCount: CGFloat = hasMessage ? 4 : 3
            let reservedHeight = (statusHeight + actionHeight * 2 + messageHeight
                + gap * gapCount + verticalPadding * 2)
            let cardHeight = max(72, proxy.size.height - reservedHeight)
            VStack(spacing: gap) {
                if content.indices.contains(position) {
                    let item = content[position]
                    HStack {
                        Pill(text: "\(position + 1)/\(content.count)", color: Palette.blue)
                        Spacer()
                        Text("Chạm lật · Vuốt 4 hướng đổi mẫu")
                            .font(.caption2).foregroundColor(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.78)
                    }
                    .frame(height: statusHeight)
                    grammarCard(item, height: cardHeight, compact: compact || cardHeight < 260)
                    HStack(spacing: 7) {
                        grammarAction("Xem đủ", symbol: "text.book.closed",
                                      color: Palette.navy, height: actionHeight) {
                            showFullGrammar = true
                        }
                        .disabled(!revealed).opacity(revealed ? 1 : 0.38)
                        grammarAction("Nghe ví dụ", symbol: "speaker.wave.2",
                                      color: Palette.blue, height: actionHeight) {
                            if let example = GrammarLibrary.examples(for: item).first {
                                voice.speak(example.text)
                            }
                        }
                        .disabled(GrammarLibrary.examples(for: item).isEmpty)
                        .opacity(GrammarLibrary.examples(for: item).isEmpty ? 0.38 : 1)
                        grammarAction("Mẫu kế", symbol: "arrow.right",
                                      color: Palette.teal, height: actionHeight) {
                            changeGrammarCard(by: 1)
                        }
                    }
                    HStack(spacing: 7) {
                        grammarAction("Chưa thuộc", symbol: "arrow.counterclockwise",
                                      color: Palette.orange, height: actionHeight) {
                            next(item.id, known: false)
                        }
                        grammarAction("Đã thuộc", symbol: "checkmark",
                                      color: Palette.teal, height: actionHeight) {
                            next(item.id, known: true)
                        }
                    }
                    .disabled(isSavingReview)
                } else {
                    LessonPanel {
                        SectionTitle("Chưa có thẻ ngữ pháp",
                                     subtitle: "Chọn một bộ có mục đã kiểm chứng.")
                        MainButton(title: "Tải lại", symbol: "arrow.clockwise") {
                            reload()
                        }
                        if store.selectedSeries == .souMatome {
                            NavigationLink {
                                SouMatomeWholeBooksView()
                            } label: {
                                Label("Mở thư viện sách Sou Matome",
                                      systemImage: "books.vertical")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let message = reviewMessage ?? voice.lastError, !message.isEmpty {
                    Text(message).font(.caption2)
                        .foregroundColor(Palette.teal).lineLimit(1)
                        .frame(height: messageHeight)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .frame(width: proxy.size.width, height: proxy.size.height,
                   alignment: .top)
        }
        .background(Palette.pale)
        .navigationTitle("Ngữ pháp")
        .navigationBarTitleDisplayMode(.inline)
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


    private func grammarAction(_ name: String, symbol: String,
                               color: Color, height: CGFloat,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(name, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundColor(.white)
                .background(color, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    /// One stationary card, sized by the current safe area; only detail sheets scroll.
    private func grammarCard(_ g: Grammar, height: CGFloat,
                             compact: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(.white)
            VStack(spacing: compact ? 7 : 12) {
                Spacer(minLength: 0)
                Text(g.pattern)
                    .font(.system(size: compact ? 20 : 25, weight: .bold))
                    .foregroundColor(Palette.navy)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                if revealed {
                    Text(g.displayMeaning)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.teal)
                        .lineLimit(3).minimumScaleFactor(0.78)
                        .multilineTextAlignment(.center)
                    if let example = GrammarLibrary.examples(for: g).first {
                        Divider()
                        if height >= 260 && example.text.count <= (compact ? 58 : 100) {
                            FuriganaText(
                                text: example.text,
                                highlightTerms: GrammarFocus.terms(from: g.pattern),
                                size: compact ? 12 : 14, centered: true)
                            Text(example.translation)
                                .font(.system(size: compact ? 11 : 13))
                                .foregroundColor(.secondary)
                                .lineLimit(compact ? 2 : 3)
                                .minimumScaleFactor(0.8)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Label("Ví dụ dài — bấm Xem đủ",
                                  systemImage: "text.book.closed")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    } else {
                        Text(GrammarLibrary.structure(for: g))
                            .font(.caption)
                            .foregroundColor(Palette.navy)
                            .lineLimit(compact ? 3 : 5)
                            .minimumScaleFactor(0.76)
                            .multilineTextAlignment(.center)
                    }
                }
                Spacer(minLength: 0)
                Text(revealed ? "Chạm xem mặt trước" : "Chạm xem nghĩa và ví dụ")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(compact ? 10 : 18)
        }
        .frame(height: height)
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
                    } else if abs(dx) >= abs(dy) && abs(dx) >= 45 {
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