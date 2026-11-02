import SwiftUI

/// Thẻ Kanji vuốt ngang hoặc dọc; chạm để lật hai mặt.
struct KanjiSwipeDeckView: View {
    @EnvironmentObject private var store: StudyStore
    @StateObject private var voice = JapaneseVoice.shared
    @State private var cards: [Kanji] = []
    @State private var position = 0
    @State private var revealed = false
    @State private var autoPlay = false
    private let autoAdvanceSeconds = 3
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
        GeometryReader { proxy in
            // Reserve the height of all controls first, then size the single card.
            let compact = proxy.size.height < 690
            let shortScreen = proxy.size.height < 520
            let gap: CGFloat = shortScreen ? 3 : (compact ? 5 : 7)
            let actionHeight: CGFloat = 44
            let statusHeight: CGFloat = 30
            let verticalPadding: CGFloat = shortScreen ? 4 : 8
            let hasFeedback = !(feedback ?? voice.lastError ?? "").isEmpty
            let feedbackHeight: CGFloat = hasFeedback ? 15 : 0
            let gapCount: CGFloat = hasFeedback ? 5 : 4
            let reservedHeight = (statusHeight + actionHeight * 3 + feedbackHeight
                + gap * gapCount + verticalPadding * 2)
            let cardHeight = max(72, proxy.size.height - reservedHeight)
            VStack(spacing: gap) {
                HStack(spacing: 12) {
                    Pill(text: cards.isEmpty ? "0/0" : "\(position + 1)/\(cards.count)",
                         color: Palette.blue)
                    Spacer(minLength: 3)
                    NavigationLink {
                        KanjiListView()
                    } label: {
                        Label("Tra cứu", systemImage: "list.bullet")
                    }
                    NavigationLink {
                        FreshPracticeSessionView(type: "Kanji")
                    } label: {
                        Label("Luyện", systemImage: "checklist")
                    }
                }
                .font(.caption.weight(.semibold))
                .frame(height: statusHeight)
                if let card = current {
                    cardSurface(card, height: cardHeight, compact: compact || cardHeight < 265)
                    HStack(spacing: 7) {
                        actionButton("Chi tiết", symbol: "text.book.closed",
                                     color: Palette.navy, height: actionHeight) {
                            showFullDetails = true
                        }
                        .disabled(!revealed).opacity(revealed ? 1 : 0.38)
                        actionButton("Nghe từ", symbol: "speaker.wave.2",
                                     color: Palette.blue, height: actionHeight) {
                            if let word = approvedRelatedWord(card) {
                                voice.speak(word)
                            }
                        }
                        .disabled(approvedRelatedWord(card) == nil)
                        .opacity(approvedRelatedWord(card) == nil ? 0.38 : 1)
                        actionButton("Dừng đọc", symbol: "stop.fill",
                                     color: Palette.teal, height: actionHeight) { voice.stop() }
                    }
                    HStack(spacing: 7) {
                        actionButton(autoPlay ? "Dừng tự chạy" : "Tự chạy",
                                     symbol: autoPlay ? "pause.fill" : "play.fill",
                                     color: autoPlay ? Palette.orange : Palette.teal, height: actionHeight) {
                            autoPlay.toggle()
                            elapsed = 0
                            if autoPlay { revealed = false; voice.stop() }
                        }
                        actionButton("Chữ tiếp theo", symbol: "arrow.right", color: Palette.blue, height: actionHeight) {
                            advance()
                        }
                    }
                    HStack(spacing: 7) {
                        actionButton("Chưa thuộc", symbol: "arrow.counterclockwise",
                                     color: Palette.orange, height: actionHeight) {
                            mark(card.id, known: false)
                        }
                        actionButton("Đã thuộc", symbol: "checkmark", color: Palette.teal, height: actionHeight) {
                            mark(card.id, known: true)
                        }
                    }
                } else {
                    LessonPanel {
                        Text("Chưa có Kanji để học. Chọn bộ có mục đã kiểm chứng.")
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
                if let message = feedback ?? voice.lastError, !message.isEmpty {
                    Text(message).font(.caption2)
                        .foregroundColor(Palette.teal).lineLimit(1)
                        .frame(height: feedbackHeight)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .frame(width: proxy.size.width, height: proxy.size.height,
                   alignment: .top)
        }
        .background(Palette.pale)
        .navigationTitle("Kanji")
        .navigationBarTitleDisplayMode(.inline)
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
        .onChange(of: store.contentRevision) { _ in reload() }
        .onDisappear { autoPlay = false; voice.stop() }
        .onReceive(ticker) { _ in
            guard autoPlay, !revealed, !cards.isEmpty, !isDraggingCard else { return }
            elapsed += 1
            if elapsed >= autoAdvanceSeconds { advance() }
        }
    }

    /// Không đặt ScrollView bên trong vùng vuốt: vuốt thẻ không thể cuộn nội dung.
    /// Vuốt trái/lên: Kanji tiếp theo; phải/xuống: Kanji trước; chạm: lật mặt.
    private func cardSurface(_ card: Kanji, height: CGFloat,
                             compact: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(.white)
            VStack(spacing: compact ? 5 : 9) {
                Spacer(minLength: 0)
                Text(card.char)
                    .font(.system(size: revealed ? (compact ? 52 : 63)
                                               : (compact ? 92 : 110),
                                  weight: .bold, design: .rounded))
                    .foregroundColor(Palette.navy)
                    .minimumScaleFactor(0.7)
                if revealed {
                    Text(card.displayMeaning)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.teal)
                        .multilineTextAlignment(.center)
                        .lineLimit(compact ? 2 : 3)
                        .minimumScaleFactor(0.75)
                    if let label = card.hanViet, !label.isEmpty {
                        Text("Hán–Việt: " + label)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Palette.blue)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    HStack(spacing: 8) {
                        Text("On: \(card.on)")
                        Text("Kun: \(card.kun)")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.72)
                    if let word = approvedRelatedWord(card) {
                        Text(word)
                            .font(.caption.weight(.medium))
                            .foregroundColor(Palette.navy)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                Spacer(minLength: 0)
                Text(revealed ? "Chạm xem mặt trước" : "Chạm lật · Vuốt 4 hướng đổi chữ")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(compact ? 10 : 15)
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
                              height: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
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
