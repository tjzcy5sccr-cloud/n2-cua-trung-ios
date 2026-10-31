import Foundation

struct Vocabulary: Decodable, Identifiable {
    let id: String
    let word: String
    let reading: String
    let meaning: String
    let example: String
    let topic: String
    let week: Int
    let exampleVi: String?
    /// Siêu dữ liệu kiểm chứng chỉ nằm trong mã và JSON, không in nhãn lên giao diện.
    let meaningStatus: String?
    let meaningSource: String?
    let exampleStatus: String?
    /// Nội dung chưa được hiệu đính chỉ lưu ở GitHub, không làm thẻ học.
    private var approvedStatuses: Set<String> {
        ["editorial_reviewed", "source_verified", "independently_verified"]
    }
    var isApprovedForStudy: Bool {
        approvedStatuses.contains(meaningStatus ?? "") &&
        !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !meaning.hasPrefix("EN ·")
    }
    var isMeaningVerified: Bool { isApprovedForStudy }
    var hasApprovedExample: Bool {
        approvedStatuses.contains(exampleStatus ?? "") &&
        !example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !(exampleVi ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !(exampleVi ?? "").hasPrefix("EN ·")
    }
    var displayMeaning: String { isApprovedForStudy ? meaning : "" }
    var displayExampleTranslation: String { hasApprovedExample ? (exampleVi ?? "") : "" }
    var approvedExampleJapanese: String? { hasApprovedExample ? example : nil }

}

struct Grammar: Decodable, Identifiable {
    let id: String
    let pattern: String
    let meaning: String
    let rule: String
    let example: String
    let translation: String
    let week: Int
    let samples: [GrammarSample]?
    let grammarStatus: String?
    let translationStatus: String?
    var isApprovedForStudy: Bool {
        ["editorial_reviewed", "source_verified", "independently_verified"]
            .contains(grammarStatus ?? "") &&
        !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !meaning.hasPrefix("EN ·")
    }
    var hasApprovedExample: Bool {
        ["editorial_reviewed", "source_verified", "independently_verified"]
            .contains(translationStatus ?? "") && !example.isEmpty && !translation.isEmpty
    }
    var displayMeaning: String { isApprovedForStudy ? meaning : "" }
    var displayRule: String { isApprovedForStudy ? rule : "" }
    var displayTranslation: String { hasApprovedExample ? translation : "" }

}

struct Kanji: Decodable, Identifiable {
    let id: String
    let char: String
    let on: String
    let kun: String
    let meaning: String
    let word: String
    let meaningStatus: String?
    var isApprovedForStudy: Bool {
        ["editorial_reviewed", "source_verified", "independently_verified"]
            .contains(meaningStatus ?? "") &&
        !char.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !meaning.hasPrefix("EN ·")
    }
    var isMeaningVerified: Bool { isApprovedForStudy }
    var displayMeaning: String { isApprovedForStudy ? meaning : "" }

}

struct ReadingLesson: Decodable, Identifiable {
    let id: String
    let title: String
    let topic: String
    let text: String
    /// Bản dịch toàn đoạn từ học liệu gốc do dự án biên soạn (tùy chọn).
    let textVi: String?
    let question: String
    let choices: [String]
    let answer: Int
    let explanation: String
}

struct ListeningLesson: Decodable, Identifiable {
    let id: String
    let title: String
    let speaker: String
    let script: String
    /// Bản dịch toàn hội thoại để xem sau khi người học yêu cầu kết quả.
    let scriptVi: String?
    let question: String
    let choices: [String]
    let answer: Int
    let explanation: String
}

struct WeeklyPlan: Decodable, Identifiable {
    let n: Int
    let date: String
    let focus: String
    let context: String
    let exam: String
    var id: Int { n }
}

struct CourseData: Decodable {
    let vocab: [Vocabulary]
    let grammar: [Grammar]
    let kanji: [Kanji]
    let readings: [ReadingLesson]
    let listening: [ListeningLesson]
    let weeks: [WeeklyPlan]

    static func load() -> CourseData {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let content = try? JSONDecoder().decode(CourseData.self, from: data) else {
            fatalError("Thiếu dữ liệu content.json trong ứng dụng. Hãy kiểm tra Build Phases > Copy Bundle Resources.")
        }
        return content
    }
}

struct ReviewRecord: Codable {
    var streak: Int
    var interval: Int
    var nextReview: Date
    var lastReviewed: Date
}

struct TestRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var correct: Int
    var total: Int
    var type: String
}

struct SavedProgress: Codable {
    var reviews: [String: ReviewRecord] = [:]
    var tests: [TestRecord] = []
    var overrideWeek: Int? = nil
}

struct ExamQuestion: Identifiable {
    let id: UUID = UUID()
    let category: String
    let prompt: String
    let passage: String?
    let audioText: String?
    let choices: [String]
    let answer: Int
    let explanation: String
}

enum QuestionBank {
    private static func create(category: String, prompt: String, passage: String? = nil,
                               audio: String? = nil, correct: String, others: [String],
                               explanation: String) -> ExamQuestion {
        var alternatives = [String]()
        for candidate in others.shuffled() where candidate != correct && !alternatives.contains(candidate) {
            alternatives.append(candidate)
            if alternatives.count == 3 { break }
        }
        let options = ([correct] + alternatives).shuffled()
        return ExamQuestion(category: category, prompt: prompt, passage: passage,
                            audioText: audio, choices: options,
                            answer: options.firstIndex(of: correct) ?? 0,
                            explanation: explanation)
    }

    static func vocabulary(_ data: CourseData, week: Int) -> [ExamQuestion] {
        let eligible = data.vocab.filter { $0.week <= week && $0.isApprovedForStudy }
        let meanings = data.vocab.filter { $0.isApprovedForStudy }.map(\.displayMeaning)
        return eligible.shuffled().prefix(100).map { item in
            create(category: "Từ vựng", prompt: "「\(item.word)」（\(item.reading)）nghĩa là gì?",
                   passage: item.approvedExampleJapanese, correct: item.displayMeaning,
                   others: meanings,
                   explanation: "\(item.word)・\(item.reading): \(item.displayMeaning)"
                     + (item.hasApprovedExample ? ". Ví dụ: \(item.displayExampleTranslation)" : ""))
        }
    }

    static func grammar(_ data: CourseData, week: Int) -> [ExamQuestion] {
        let eligible = data.grammar.filter { $0.week <= week && $0.isApprovedForStudy }
        let meanings = data.grammar.filter { $0.isApprovedForStudy }.map(\.displayMeaning)
        return eligible.shuffled().prefix(70).map { item in
            create(category: "Ngữ pháp", prompt: "Ý nghĩa của \(item.pattern) là gì?",
                   passage: item.hasApprovedExample ? item.example : nil,
                   correct: item.displayMeaning,
                   others: meanings,
                   explanation: item.displayRule +
                     (item.hasApprovedExample ? " Ví dụ: \(item.displayTranslation)" : ""))
        }
    }

    static func kanji(_ data: CourseData) -> [ExamQuestion] {
        data.kanji.filter { $0.isApprovedForStudy }.map { item in
            create(category: "Kanji", prompt: "Chữ 「\(item.char)」 có nghĩa gì?",
                   passage: nil, correct: item.displayMeaning,
                   others: data.kanji.filter { $0.isApprovedForStudy }.map(\.displayMeaning),
                   explanation: "Âm On: \(item.on) · Âm Kun: \(item.kun)")
        }
    }

    /// Mỗi lượt chỉ lấy 12 câu và tránh các bài ở lượt luyện ngay trước đó.
    private static func uniqueSession<T: Identifiable>(_ lessons: [T], key: String) -> [T]
        where T.ID == String {
        let recent = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let newOnes = lessons.filter { !recent.contains($0.id) }.shuffled()
        let remaining = lessons.filter { recent.contains($0.id) }.shuffled()
        let chosen = Array((newOnes + remaining).prefix(12))
        UserDefaults.standard.set(chosen.map(\.id), forKey: key)
        return chosen
    }

    private static func shuffledChoices(_ choices: [String], answer: Int) -> ([String], Int) {
        guard choices.indices.contains(answer) else { return (choices, answer) }
        let correct = choices[answer]
        let shuffled = choices.shuffled()
        return (shuffled, shuffled.firstIndex(of: correct) ?? answer)
    }

    static func reading(_ data: CourseData) -> [ExamQuestion] {
        uniqueSession(data.readings, key: "N2.recentReadingV2").map { item in
            let (choices, answer) = shuffledChoices(item.choices, answer: item.answer)
            return ExamQuestion(category: "Đọc hiểu", prompt: item.question,
                                passage: item.text, audioText: nil, choices: choices,
                                answer: answer, explanation: item.explanation)
        }
    }

    static func listening(_ data: CourseData) -> [ExamQuestion] {
        uniqueSession(data.listening, key: "N2.recentListeningV2").map { item in
            let (choices, answer) = shuffledChoices(item.choices, answer: item.answer)
            return ExamQuestion(category: "Nghe hiểu", prompt: item.question,
                                passage: nil, audioText: item.script, choices: choices,
                                answer: answer, explanation: item.explanation)
        }
    }

    static func make(_ data: CourseData, week: Int, count: Int = 20) -> [ExamQuestion] {
        let first = Array(grammar(data, week: week).shuffled().prefix(6))
        let second = Array(vocabulary(data, week: week).shuffled().prefix(6))
        let third = Array(kanji(data).shuffled().prefix(4))
        let fourth = Array(reading(data).shuffled().prefix(2))
        let fifth = Array(listening(data).shuffled().prefix(2))
        var all = (first + second + third + fourth + fifth).shuffled()
        var seen = Set(all.map { "\($0.category)|\($0.prompt)" })
        let extra = (vocabulary(data, week: week) + grammar(data, week: week) + kanji(data)
                     + reading(data) + listening(data)).shuffled()
        for item in extra {
            if all.count >= count { break }
            let key = "\(item.category)|\(item.prompt)"
            if !seen.contains(key) {
                all.append(item)
                seen.insert(key)
            }
        }
        return Array(all.prefix(count))
    }
}