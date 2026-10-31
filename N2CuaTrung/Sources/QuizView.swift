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
                    Text("Gồm từ vựng, ngữ pháp, Kanji, đọc hiểu và nghe hiểu. Chỉ xem đáp án và giải thích sau khi nộp bài. Đề luyện tập tự biên soạn, không phải đề JLPT chính thức.")
                        .font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Pill(text: "Offline", color: Palette.teal)
                        Pill(text: "Bấm giờ", color: Palette.orange)
                        Pill(text: "Lưu điểm", color: Palette.blue)
                    }
                }
                MainButton(title: "Tạo đề mới", symbol: "arrow.triangle.2.circlepath") {
                    questions = QuestionBank.make(store.course, week: store.studyWeekLimit)
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
        .onAppear { if questions.isEmpty { questions = QuestionBank.make(store.course, week: store.studyWeekLimit) } }
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
    /// Lưu lựa chọn theo số thứ tự; bỏ qua được giữ là chưa trả lời.
    @State private var answersByQuestion: [Int: Int] = [:]
    @State private var showAllExplanations = false
    @State private var showCurrentExplanation = false
    @State private var nextQuestionTask: Task<Void, Never>?
    @State private var correct = 0
    @State private var completed = false
    @State private var revealedTranscript = false
    @State private var remainingSeconds = 12 * 60
    @State private var speed: Float = 0.47
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Tìm từ/mẫu ngữ pháp ngay trong đề, không dựa vào ngẫu nhiên hay tô màu cả câu.
    private func focusTerms(for question: ExamQuestion) -> [String] {
        if question.category == "Ngữ pháp" {
            let pattern = question.prompt
                .replacingOccurrences(of: "Ý nghĩa của ", with: "")
                .replacingOccurrences(of: " là gì?", with: "")
            return GrammarFocus.terms(from: pattern)
        }
        if question.category == "Từ vựng" || question.category == "Kanji" {
            if let left = question.prompt.range(of: "「"),
               let right = question.prompt.range(of: "」", range: left.upperBound..<question.prompt.endIndex) {
                return [String(question.prompt[left.upperBound..<right.lowerBound])]
            }
        }
        return []
    }

    private var current: ExamQuestion? {
        questions.indices.contains(position) ? questions[position] : nil
    }

    /// Đọc hiểu, nghe hiểu, Kanji và ngữ pháp: xem lời giải khi bấm "Kết quả".
    /// Đề thi bấm giờ vẫn chỉ chữa bài sau khi nộp.
    private var manualExplanation: Bool {
        !timed && ["Đọc hiểu", "Ngữ pháp", "Nghe hiểu", "Kanji"].contains(type)
    }
    private var reviewAtEnd: Bool { manualExplanation || timed }

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
                            if question.category == "Ngữ pháp" || question.category == "Từ vựng" || question.category == "Kanji" {
                                FuriganaText(text: text, highlightTerms: focusTerms(for: question), size: 17)
                            } else {
                                FuriganaText(text: text, size: 18)
                            }
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
                                if revealedTranscript { FuriganaText(text: text, size: 17) }
                            }
                        }
                        if question.prompt.unicodeScalars.contains(where: { $0.value >= 0x3040 && $0.value <= 0x9FFF }) {
                            FuriganaText(text: question.prompt, size: 19)
                        } else {
                            SectionTitle(question.prompt)
                        }
                    }

                    ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                        Button { choose(index) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(UnicodeScalar(65 + index)!))
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 27, height: 27)
                                    .background(Palette.navy.opacity(0.06), in: Circle())
                                if choice.unicodeScalars.contains(where: { $0.value >= 0x3040 && $0.value <= 0x9FFF }) {
                                    FuriganaText(text: choice, size: 16)
                                } else {
                                    Text(choice).font(.subheadline).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                if ((!reviewAtEnd || showCurrentExplanation) && selected != nil || showCurrentExplanation) && index == question.answer {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Palette.teal)
                                } else if ((!reviewAtEnd || showCurrentExplanation) && selected == index) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                }
                            }
                            .foregroundColor(Palette.navy)
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(choiceColor(index, question: question),
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(selected != nil || (manualExplanation && showCurrentExplanation))
                        .buttonStyle(.plain)
                    }
                    if manualExplanation && showCurrentExplanation {
                        LessonPanel {
                            HStack(spacing: 10) {
                                Image(systemName: selected == question.answer ? "checkmark.circle.fill" : "info.circle.fill")
                                    .foregroundColor(selected == question.answer ? Palette.teal : Palette.orange)
                                Text(selected == nil ? "Chưa chọn đáp án" :
                                        (selected == question.answer ? "Bạn đã trả lời đúng!" : "Bạn cần ôn lại câu này"))
                                    .font(.headline)
                                    .foregroundColor(Palette.navy)
                            }
                            if let answer = selected, question.choices.indices.contains(answer) {
                                Text("Bạn đã chọn: \(String(UnicodeScalar(65 + answer)!)). \(question.choices[answer])")
                                    .font(.subheadline)
                                    .foregroundColor(Palette.navy)
                            }
                            if question.choices.indices.contains(question.answer) {
                                Text("Đáp án đúng: \(String(UnicodeScalar(65 + question.answer)!)). \(question.choices[question.answer])")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Palette.teal)
                            }
                            Divider()
                            Text("Giải thích")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Palette.navy)
                            Text(question.explanation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if question.category == "Đọc hiểu",
                               let lesson = store.course.readings.first(where: { $0.text == question.passage }),
                               let translation = lesson.textVi, !translation.isEmpty {
                                Divider()
                                Text("Dịch toàn bài đọc")
                                    .font(.subheadline.weight(.bold)).foregroundColor(Palette.navy)
                                Text(translation)
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                            if question.category == "Nghe hiểu",
                               let lesson = store.course.listening.first(where: { $0.script == question.audioText }),
                               let translation = lesson.scriptVi, !translation.isEmpty {
                                Divider()
                                Text("Dịch toàn hội thoại")
                                    .font(.subheadline.weight(.bold)).foregroundColor(Palette.navy)
                                Text(translation)
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                            Text("Câu hỏi sẽ giữ nguyên đến khi bạn nhấn Tiếp.")
                                .font(.caption)
                                .foregroundColor(Palette.blue)
                        }
                    } else if let answer = selected, !reviewAtEnd {
                        LessonPanel {
                            HStack {
                                Image(systemName: answer == question.answer ? "checkmark.seal.fill" : "info.circle.fill")
                                    .foregroundColor(answer == question.answer ? Palette.teal : Palette.orange)
                                Text(answer == question.answer ? "Chính xác!" : "Đáp án đúng: \(question.choices[question.answer])")
                                    .font(.headline).foregroundColor(Palette.navy)
                            }
                            Text(question.explanation).font(.subheadline).foregroundColor(.secondary)
                            Text("Ứng dụng sẽ tự chuyển sang câu mới sau khi chọn đáp án.")
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
                VStack(spacing: 6) {
                    if manualExplanation {
                        HStack(spacing: 7) {
                            Button {
                                guard selected == nil && !showCurrentExplanation else { return }
                                next()
                            } label: {
                                Label("Bỏ qua", systemImage: "forward.fill")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .foregroundColor(.white)
                                    .background(selected == nil && !showCurrentExplanation ? Palette.orange : Color.gray,
                                                in: RoundedRectangle(cornerRadius: 11))
                            }
                            .disabled(selected != nil || showCurrentExplanation)
                            Button {
                                next()
                            } label: {
                                Label(position + 1 == questions.count ? "Hoàn tất" : "Tiếp",
                                      systemImage: "arrow.right")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .foregroundColor(.white)
                                    .background(Palette.teal, in: RoundedRectangle(cornerRadius: 11))
                            }
                            Button {
                                toggleCurrentExplanation()
                            } label: {
                                Label("Kết quả", systemImage: "list.bullet.clipboard.fill")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .foregroundColor(.white)
                                    .background(Palette.blue, in: RoundedRectangle(cornerRadius: 11))
                            }
                            .disabled(showCurrentExplanation)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 10) {
                            Text("Câu \(position + 1)/\(questions.count)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(Palette.navy)
                            MainButton(
                                title: position + 1 == questions.count ? "Hoàn thành" :
                                    (selected == nil ? "Bỏ qua / Tiếp" : "Câu tiếp theo"),
                                symbol: "arrow.right",
                                color: Palette.teal
                            ) { next() }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
            }
        }
        .onDisappear { voice.stop(); nextQuestionTask?.cancel() }
        .onReceive(ticker) { _ in
            guard timed && !completed && !questions.isEmpty else { return }
            if remainingSeconds > 0 { remainingSeconds -= 1 }
            if remainingSeconds == 0 { finish() }
        }
    }

    private var finishPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            LessonPanel {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Palette.teal)
                SectionTitle("Đã hoàn thành bài luyện")
                if reviewAtEnd && !showAllExplanations {
                    Text("Bài làm đã được lưu. Bấm nút bên dưới khi bạn muốn xem điểm, đáp án và phần giải thích toàn bộ câu hỏi.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    resultSummary
                }
            }

            if reviewAtEnd {
                MainButton(
                    title: showAllExplanations ? "Ẩn đáp án và giải thích" : "Hiển thị kết quả và giải thích",
                    symbol: showAllExplanations ? "eye.slash.fill" : "list.bullet.clipboard.fill",
                    color: Palette.teal
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllExplanations.toggle()
                    }
                }
                if showAllExplanations {
                    SectionTitle("Chữa toàn bộ \(questions.count) câu", subtitle: "Đáp án đã chọn, đáp án đúng và giải thích")
                    ForEach(Array(questions.enumerated()), id: \.offset) { questionIndex, question in
                        reviewPanel(question, at: questionIndex)
                    }
                }
            }
        }
    }

    private var resultSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(correct) / \(questions.count)")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundColor(Palette.navy)
            Text("Tỉ lệ đúng: \(questions.isEmpty ? 0 : Int(100.0 * Double(correct) / Double(questions.count)))%")
                .font(.headline).foregroundColor(Palette.blue)
            Text("Đã lưu điểm vào Tiến độ. Những câu bỏ qua được tính là chưa đúng.")
                .font(.subheadline).foregroundColor(.secondary)
        }
    }

    private func reviewPanel(_ question: ExamQuestion, at index: Int) -> some View {
        let picked = answersByQuestion[index]
        let isCorrect = picked == question.answer
        return LessonPanel {
            HStack(spacing: 8) {
                Text("Câu \(index + 1)")
                    .font(.headline).foregroundColor(Palette.navy)
                Spacer()
                Pill(
                    text: picked == nil ? "Bỏ qua" : (isCorrect ? "Đúng" : "Sai"),
                    color: picked == nil ? Palette.orange : (isCorrect ? Palette.teal : .red)
                )
            }
            if let passage = question.passage {
                FuriganaText(text: passage, size: 17)
            }
            if let audio = question.audioText {
                SectionTitle("Hội thoại")
                FuriganaText(text: audio, size: 16)
                Button("Nghe lại hội thoại") { voice.speakConversation(audio, rate: speed) }
                    .font(.subheadline.weight(.medium))
            }
            if question.prompt.unicodeScalars.contains(where: { $0.value >= 0x3040 && $0.value <= 0x9FFF }) {
                FuriganaText(text: question.prompt, size: 18)
            } else {
                Text(question.prompt).font(.headline).foregroundColor(Palette.navy)
            }
            if let picked, question.choices.indices.contains(picked) {
                Text("Bạn chọn: \(String(UnicodeScalar(65 + picked)!)). \(question.choices[picked])")
                    .foregroundColor(isCorrect ? Palette.teal : .red)
                    .font(.subheadline)
            } else {
                Text("Bạn chưa chọn đáp án.").font(.subheadline).foregroundColor(Palette.orange)
            }
            if question.choices.indices.contains(question.answer) {
                Text("Đáp án đúng: \(String(UnicodeScalar(65 + question.answer)!)). \(question.choices[question.answer])")
                    .font(.subheadline.weight(.semibold)).foregroundColor(Palette.teal)
            }
            Divider()
            Text("Giải thích").font(.subheadline.weight(.bold)).foregroundColor(Palette.navy)
            Text(question.explanation).font(.subheadline).foregroundColor(.secondary)
        }
    }

    private func choose(_ index: Int) {
        guard selected == nil, !showCurrentExplanation, let question = current else { return }
        selected = index
        answersByQuestion[position] = index
        if index == question.answer { correct += 1 }
        // Không tự chuyển Đọc hiểu, Nghe hiểu, Kanji hay Ngữ pháp; chờ bấm Tiếp.
        guard !manualExplanation else { return }
        let answeredID = question.id
        nextQuestionTask?.cancel()
        nextQuestionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: reviewAtEnd ? 260_000_000 : 850_000_000)
            guard !Task.isCancelled, !completed, current?.id == answeredID else { return }
            next()
        }
    }

    private func toggleCurrentExplanation() {
        guard manualExplanation, !completed, !showCurrentExplanation else { return }
        nextQuestionTask?.cancel()
        nextQuestionTask = nil
        withAnimation(.easeInOut(duration: 0.18)) {
            showCurrentExplanation.toggle()
        }
    }

    private func next() {
        nextQuestionTask?.cancel()
        nextQuestionTask = nil
        voice.stop()
        if position + 1 < questions.count {
            position += 1
            selected = nil
            showCurrentExplanation = false
            revealedTranscript = false
        } else { finish() }
    }

    private func finish() {
        guard !completed else { return }
        completed = true
        showAllExplanations = false
        nextQuestionTask?.cancel()
        voice.stop()
        store.recordTest(correct: correct, total: questions.count, type: type)
    }

    private func choiceColor(_ index: Int, question: ExamQuestion) -> Color {
        if manualExplanation {
            if showCurrentExplanation {
                if index == question.answer { return Palette.teal.opacity(0.16) }
                if selected == index { return Color.red.opacity(0.12) }
                return .white
            }
            return selected == index ? Palette.blue.opacity(0.11) : .white
        }
        guard !reviewAtEnd, selected != nil else { return .white }
        if index == question.answer { return Palette.teal.opacity(0.16) }
        if index == selected { return Color.red.opacity(0.12) }
        return .white
    }

    private func formatClock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}