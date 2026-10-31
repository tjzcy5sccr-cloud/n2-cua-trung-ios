import SwiftUI

/// Thẻ Kanji vuốt ngang hoặc dọc; chạm để lật hai mặt.
struct KanjiSwipeDeckView: View {
    @EnvironmentObject private var store: StudyStore
    @StateObject private var voice = JapaneseVoice.shared
    @State private var cards: [Kanji] = []
    @State private var position = 0
    @State private var revealed = false
    @State private var autoPlay = false
    @State private var intervalSeconds = 5
    @State private var elapsed = 0
    @State private var isDraggingCard = false
    @State private var showFullDetails = false
    @State private var feedback: String?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: Kanji? { cards.indices.contains(position) ? cards[position] : nil }

    private func approvedRelatedWord(_ card: Kanji) -> String? {
        let approved = Set(store.course.vocab.filter { $0.isApprovedForStudy }.map(\.word))
        return card.word.components(separatedBy: CharacterSet(charactersIn: "、,，/"))
            .map {
                $0.replacingOccurrences(of: "[（(][^）)]*[）)]", with: "",
                                        options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .first { approved.contains($0) }
    }

    var body: some View {
        GeometryReader { _ in
            ScrollView(.vertical) {
                VStack(spacing: 10) {
                SectionTitle("Kanji N2", subtitle: "Vuốt ngang / dọc để đổi chữ • Chạm để lật")
                HStack {
                    if !cards.isEmpty {
                        Pill(text: "\(position + 1) / \(cards.count)", color: Palette.blue)
                    }
                    Spacer()
                    NavigationLink {
                        KanjiListView()
                    } label: {
                        Label("Tra cứu", systemImage: "list.bullet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Palette.blue)
                    }
                }
                NavigationLink {
                    FreshPracticeSessionView(type: "Kanji")
                } label: {
                    Label("Luyện câu hỏi Kanji · Bỏ qua / Tiếp / Kết quả",
                          systemImage: "checklist")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundColor(.white)
                        .background(Palette.blue, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                if let card = current {
                    cardSurface(card, height: 286)
                    // Giữ cố định chiều cao của hàng chi tiết ở cả hai mặt Kanji.
                    Button {
                        if revealed { showFullDetails = true }
                    } label: {
                        Label("Xem đầy đủ từ ghép và bộ thủ", systemImage: "text.book.closed")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .opacity(revealed ? 1 : 0)
                    .disabled(!revealed)
                    .accessibilityHidden(!revealed)
                    Text(feedback ?? " ")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Palette.teal)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18, alignment: .leading)
                    HStack(spacing: 8) {
                        actionButton(autoPlay ? "Dừng tự chạy" : "Tự chạy",
                                     symbol: autoPlay ? "pause.fill" : "play.fill",
                                     color: autoPlay ? Palette.orange : Palette.teal) {
                            autoPlay.toggle()
                            elapsed = 0
                            if autoPlay { revealed = false; voice.stop() }
                        }
                        actionButton("Chữ tiếp theo", symbol: "forward.end.fill",
                                     color: Palette.blue) { advance() }
                    }
                    HStack(spacing: 8) {
                        Text("Đổi Kanji mỗi").font(.caption).foregroundColor(.secondary)
                        Picker("Chu kỳ tự chạy", selection: $intervalSeconds) {
                            Text("3 giây").tag(3)
                            Text("5 giây").tag(5)
                            Text("8 giây").tag(8)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: intervalSeconds) { _ in elapsed = 0 }
                    }
                    HStack(spacing: 8) {
                        actionButton("Nghe từ ghép", symbol: "speaker.wave.2.fill", color: Palette.blue) {
                            if let word = approvedRelatedWord(card) { voice.speak(word) }
                        }
                        .disabled(approvedRelatedWord(card) == nil)
                        .opacity(approvedRelatedWord(card) == nil ? 0.38 : 1)
                        actionButton("Dừng âm thanh", symbol: "stop.fill", color: Palette.navy) {
                            voice.stop()
                        }
                    }
                    HStack(spacing: 8) {
                        actionButton("Chưa thuộc", symbol: "arrow.counterclockwise",
                                     color: Palette.orange) {
                            mark(card.id, known: false)
                        }
                        actionButton("Đã thuộc", symbol: "checkmark", color: Palette.teal) {
                            mark(card.id, known: true)
                        }
                    }
                } else {
                    LessonPanel {
                        Text("Không tìm thấy Kanji.")
                        MainButton(title: "Tải lại", symbol: "arrow.clockwise") { reload() }
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
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(Palette.pale)
        .navigationTitle("Kanji")
        .sheet(isPresented: $showFullDetails) {
            if let card = current {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(card.char)
                                .font(.system(size: 66, weight: .bold))
                                .frame(maxWidth: .infinity)
                            KanjiVocabularyView(item: card, vocabulary: store.course.vocab)
                        }
                        .padding(20)
                    }
                    .navigationTitle("Chi tiết Kanji")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Đóng") { showFullDetails = false }
                        }
                    }
                }
            }
        }
        .onAppear { if cards.isEmpty { reload() } }
        .onDisappear { autoPlay = false; voice.stop() }
        .onReceive(ticker) { _ in
            guard autoPlay, !revealed, !cards.isEmpty, !isDraggingCard else { return }
            elapsed += 1
            if elapsed >= intervalSeconds { advance() }
        }
    }

    /// Không đặt ScrollView bên trong vùng vuốt: vuốt thẻ không thể cuộn nội dung.
    /// Vuốt trái/lên: Kanji tiếp theo; phải/xuống: Kanji trước; chạm: lật mặt.
    private func cardSurface(_ card: Kanji, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(.white)
            VStack(spacing: 10) {
                if revealed {
                    Text(card.char).font(.system(size: 52, weight: .bold))
                        .foregroundColor(Palette.navy)
                    Text(card.displayMeaning)
                        .font(.headline).foregroundColor(Palette.teal)
                        .multilineTextAlignment(.center).lineLimit(2)
                    if let info = KangxiReference.info(for: card.char) {
                        Text("Hán–Việt: \(info.sinoVietnamese)")
                            .font(.subheadline).foregroundColor(Palette.blue)
                        if let radical = KangxiReference.radical(forKanji: card.char) {
                            Text("Bộ #\(radical.id): \(radical.character) • \(radical.sinoVietnamese) — \(radical.meaning)")
                                .font(.subheadline).foregroundColor(Palette.navy)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    HStack(spacing: 12) {
                        Text("On: \(card.on)").lineLimit(2)
                        Text("Kun: \(card.kun)").lineLimit(2)
                    }
                    .font(.caption).foregroundColor(.secondary)
                    if let word = approvedRelatedWord(card) {
                        Text(word)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Palette.navy)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 0)
                    Text("Chạm để xem mặt trước")
                        .font(.caption2).foregroundColor(.secondary)
                } else {
                    Spacer(minLength: 10)
                    Text(card.char)
                        .font(.system(size: 106, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.navy)
                    Spacer(minLength: 10)
                    Label("Chạm để lật • Vuốt 4 hướng để đổi", systemImage: "hand.tap")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(15)
        }
        .frame(height: height)
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.orange.opacity(0.24)))
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
                        // Khung Kanji đứng yên khi vuốt; chỉ ghi nhận hướng.
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
        .accessibilityLabel(revealed ? "Mặt sau Kanji \(card.char), chạm để quay lại." :
                                    "Mặt trước Kanji \(card.char), chạm để xem nghĩa.")
        .accessibilityAction(named: "Lật thẻ") { flip(card) }
        .accessibilityAction(named: "Kanji tiếp theo") { changeCard(by: 1) }
        .accessibilityAction(named: "Kanji trước") { changeCard(by: -1) }
    }

    private func flip(_ card: Kanji) {
        revealed.toggle()
        elapsed = 0
        // Giữ chế độ tự chạy ở trạng thái ngừng khi thẻ đang lật mặt sau.
        if !revealed { voice.stop() }
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

    private func reload() {
        cards = store.course.kanji.shuffled()
        position = 0
        revealed = false
        feedback = nil
        elapsed = 0
        isDraggingCard = false
        voice.stop()
    }

    private func advance() {
        changeCard(by: 1)
    }

    private func changeCard(by step: Int) {
        guard !cards.isEmpty else { return }
        // Chốt từ ghép của thẻ mới trước khi đổi position để không phát từ cũ.
        let nextIndex = (position + step + cards.count) % cards.count
        let next = cards[nextIndex]
        voice.stop()
        // Đổi nội dung trong vị trí cố định; không dùng animation làm khung nảy.
        position = nextIndex
        revealed = false
        elapsed = 0
        if let word = approvedRelatedWord(next) { voice.speak(word) }
    }

    private func mark(_ id: String, known: Bool) {
        store.review("k:\(id)", known: known)
        advance()
        feedback = known ? "Đã lưu: Đã thuộc." : "Đã lưu: Chưa thuộc, sẽ ôn lại."
    }
}
