import SwiftUI

/// Thẻ Kanji vuốt dọc giống flashcard, giữ kích thước cố định.
struct KanjiSwipeDeckView: View {
    @EnvironmentObject private var store: StudyStore
    @StateObject private var voice = JapaneseVoice.shared
    @State private var cards: [Kanji] = []
    @State private var position = 0
    @State private var revealed = false
    @State private var autoPlay = false
    @State private var intervalSeconds = 5
    @State private var elapsed = 0
    @State private var feedback: String?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: Kanji? { cards.indices.contains(position) ? cards[position] : nil }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                SectionTitle("Kanji N2", subtitle: "Vuốt dọc để đổi chữ • Chạm để xem nghĩa")
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
                if let card = current {
                    cardSurface(card, height: min(320, max(220, geometry.size.height * 0.42)))
                    if let feedback {
                        Label(feedback, systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Palette.teal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
                            voice.speak(card.word)
                        }
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
                if let error = voice.lastError {
                    Text(error).font(.caption2).foregroundColor(.red)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Palette.pale)
        .navigationTitle("Kanji")
        .onAppear { if cards.isEmpty { reload() } }
        .onDisappear { autoPlay = false; voice.stop() }
        .onReceive(ticker) { _ in
            guard autoPlay, !revealed, !cards.isEmpty else { return }
            elapsed += 1
            if elapsed >= intervalSeconds { advance() }
        }
    }

    private func cardSurface(_ card: Kanji, height: CGFloat) -> some View {
        ZStack {
            if revealed {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            showFront()
                        } label: {
                            Label("Mặt trước", systemImage: "arrow.uturn.backward")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Palette.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Palette.blue.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }.padding(.top, 8)
                    ScrollView(.vertical) {
                        VStack(spacing: 12) {
                            Text(card.char)
                                .font(.system(size: 55, weight: .bold))
                                .foregroundColor(Palette.navy)
                            KanjiVocabularyView(item: card, vocabulary: store.course.vocab)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { revealed = true }
                    elapsed = 0
                } label: {
                    VStack(spacing: 12) {
                        Spacer(minLength: 10)
                        Text(card.char)
                            .font(.system(size: 106, weight: .bold, design: .rounded))
                            .foregroundColor(Palette.navy)
                        Spacer(minLength: 10)
                        Label("Chạm để xem nghĩa", systemImage: "hand.tap")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.horizontal, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.orange.opacity(0.24)))
        .highPriorityGesture(
            DragGesture(minimumDistance: 35).onEnded { movement in
                let dy = movement.translation.height
                if abs(dy) > 48 && abs(dy) > abs(movement.translation.width) * 1.25 {
                    advance()
                }
            },
            including: revealed ? .none : .all
        )
        .accessibilityAction(named: "Kanji tiếp theo") { advance() }
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

    private func showFront() {
        guard revealed else { return }
        withAnimation(.easeInOut(duration: 0.15)) { revealed = false }
        elapsed = 0
        voice.stop()
    }

    private func reload() {
        cards = store.course.kanji.shuffled()
        position = 0
        revealed = false
        feedback = nil
        elapsed = 0
        voice.stop()
    }

    private func advance() {
        voice.stop()
        revealed = false
        elapsed = 0
        if position + 1 < cards.count { position += 1 } else { reload() }
    }

    private func mark(_ id: String, known: Bool) {
        store.review("k:\(id)", known: known)
        advance()
        feedback = known ? "Đã lưu: Đã thuộc." : "Đã lưu: Chưa thuộc, sẽ ôn lại."
    }
}
