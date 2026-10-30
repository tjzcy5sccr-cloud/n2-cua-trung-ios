import SwiftUI

struct ExamStartView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var questions: [ExamQuestion] = []
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                LessonPanel {
                    Image(systemName: "graduationcap.fill")
                        .font(.largeTitle).foregroundColor(Palette.blue)
                    SectionTitle("Kiểm tra tổng hợp N2", subtitle: "20 câu • 12 phút")
                    Text("Gồm từ vựng, ngữ pháp, Kanji, đọc hiểu và nghe hiểu. Có chữa bài sau mỗi câu. Đề là bài luyện tập tự biên soạn, không phải đề JLPT chính thức.")
                        .font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Pill(text: "Offline", color: Palette.teal)
                        Pill(text: "Bấm giờ", color: Palette.orange)
                        Pill(text: "Lưu điểm", color: Palette.blue)
                    }
                }
                MainButton(title: "Tạo đề mới", symbol: "arrow.triangle.2.circlepath") {
                    questions = QuestionBank.make(store.course, week: store.week)
                }
                if !questions.isEmpty {
                    NavigationLink {
                        QuestionSessionView(questions: questions, type: "Đề 20 câu", timed: true)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Bắt đầu làm \(questions.count) câu")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .foregroundColor(.white)
                        .background(Palette.teal, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Thi thử")
        .onAppear { if questions.isEmpty { questions = QuestionBank.make(store.course, week: store.week) } }
    }
}

struct QuestionSessionView: View {
    let questions: [ExamQuestion]
    let type: String
    var timed = false

    @EnvironmentObject private var store: StudyStore
    @StateObject private var voice = JapaneseVoice.shared
    @State private var position = 0
    @State private var selected: Int? = nil
    @State private var correct = 0
    @State private var completed = false
    @State private var revealedTranscript = false
    @State private var remainingSeconds = 12 * 60
    @State private var speed: Float = 0.47
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: ExamQuestion? {
        questions.indices.contains(position) ? questions[position] : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if completed {
                    finishPanel
                } else if let question = current {
                    HStack(spacing: 8) {
                        Pill(text: question.category, color: Palette.blue)
                        Spacer()
                        Text("\(position + 1)/\(questions.count)")
                            .font(.subheadline.monospacedDigit()).foregroundColor(.secondary)
                        if timed {
                            Label(formatClock(remainingSeconds), systemImage: "clock")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(remainingSeconds < 60 ? .red : Palette.orange)
                        }
                    }
                    ProgressView(value: Double(position), total: Double(max(1, questions.count)))
                        .tint(Palette.teal)
                    LessonPanel {
                        if let text = question.passage {
                            Text(text)
                                .font(.system(size: question.category == "Đọc hiểu" ? 17 : 16))
                                .foregroundColor(Palette.navy)
                                .textSelection(.enabled)
                        }
                        if let text = question.audioText {
                            SectionTitle("Nghe tình huống")
                            HStack(spacing: 10) {
                                MainButton(title: "Phát audio", symbol: "play.fill") {
                                    voice.speakConversation(text, rate: speed)
                                }
                                MainButton(title: "Dừng", symbol: "stop.fill", color: Palette.navy) {
                                    voice.stop()
                                }
                            }
                            HStack {
                                Text("Tốc độ").font(.caption).foregroundColor(.secondary)
                                Picker("Tốc độ", selection: $speed) {
                                    Text("Chậm").tag(Float(0.39))
                                    Text("Vừa").tag(Float(0.47))
                                    Text("Nhanh").tag(Float(0.54))
                                }.pickerStyle(.segmented)
                            }
                            if let error = voice.lastError {
                                Text(error).font(.caption).foregroundColor(.red)
                            }
                            if selected != nil {
                                Button(revealedTranscript ? "Ẩn hội thoại" : "Xem hội thoại") {
                                    revealedTranscript.toggle()
                                }
                                if revealedTranscript { Text(text).font(.subheadline).foregroundColor(.secondary) }
                            }
                        }
                        SectionTitle(question.prompt)
                    }

                    ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                        Button { choose(index) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(UnicodeScalar(65 + index)!))
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 27, height: 27)
                                    .background(Palette.navy.opacity(0.06), in: Circle())
                                Text(choice).font(.subheadline).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if selected != nil && index == question.answer {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Palette.teal)
                                } else if selected == index {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                }
                            }
                            .foregroundColor(Palette.navy)
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(choiceColor(index, question: question),
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(selected != nil)
                        .buttonStyle(.plain)
                    }
                    if let answer = selected {
                        LessonPanel {
                            HStack {
                                Image(systemName: answer == question.answer ? "checkmark.seal.fill" : "info.circle.fill")
                                    .foregroundColor(answer == question.answer ? Palette.teal : Palette.orange)
                                Text(answer == question.answer ? "Chính xác!" : "Đáp án đúng: \(question.choices[question.answer])")
                                    .font(.headline).foregroundColor(Palette.navy)
                            }
                            Text(question.explanation).font(.subheadline).foregroundColor(.secondary)
                            Text("Nút chuyển câu nằm cố định ở cuối màn hình, không cần kéo xuống.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Không có câu hỏi cho phần này.")
                        .foregroundColor(.secondary)
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle(type)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !completed && !questions.isEmpty {
                HStack(spacing: 10) {
                    Text("Câu \(position + 1)/\(questions.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(Palette.navy)
                    MainButton(
                        title: position + 1 == questions.count ? "Xem kết quả" : (selected == nil ? "Bỏ qua / Tiếp" : "Câu tiếp theo"),
                        symbol: "arrow.right", color: Palette.teal
                    ) { next() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
            }
        }
        .onDisappear { voice.stop() }
        .onReceive(ticker) { _ in
            guard timed && !completed && !questions.isEmpty else { return }
            if remainingSeconds > 0 { remainingSeconds -= 1 }
            if remainingSeconds == 0 { finish() }
        }
    }

    private var finishPanel: some View {
        LessonPanel {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundColor(Palette.teal)
            SectionTitle("Hoàn thành bài luyện")
            Text("\(correct) / \(questions.count)")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundColor(Palette.navy)
            Text("Tỉ lệ đúng: \(questions.isEmpty ? 0 : Int(100.0 * Double(correct) / Double(questions.count)))%")
                .font(.headline).foregroundColor(Palette.blue)
            Text("Điểm đã lưu trong Tiến độ. Hãy ôn lại những câu chưa chắc trước khi làm đề mới.")
                .font(.subheadline).foregroundColor(.secondary)
        }
    }

    private func choose(_ index: Int) {
        guard selected == nil, let question = current else { return }
        selected = index
        if index == question.answer { correct += 1 }
    }

    private func next() {
        voice.stop()
        if position + 1 < questions.count {
            position += 1
            selected = nil
            revealedTranscript = false
        } else { finish() }
    }

    private func finish() {
        guard !completed else { return }
        completed = true
        voice.stop()
        store.recordTest(correct: correct, total: questions.count, type: type)
    }

    private func choiceColor(_ index: Int, question: ExamQuestion) -> Color {
        guard selected != nil else { return .white }
        if index == question.answer { return Palette.teal.opacity(0.16) }
        if index == selected { return Color.red.opacity(0.12) }
        return .white
    }

    private func formatClock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}