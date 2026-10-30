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
    var displayMeaning: String {
        meaning.hasPrefix("EN ·") ? "Đang bổ sung nghĩa tiếng Việt" : meaning
    }
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
    var displayMeaning: String {
        meaning.hasPrefix("EN ·") ? "Đang bổ sung nghĩa tiếng Việt" : meaning
    }
    var displayRule: String {
        meaning.hasPrefix("EN ·") ? "Đang bổ sung hướng dẫn ngữ pháp bằng tiếng Việt." : rule
    }
}

struct Kanji: Decodable, Identifiable {
    let id: String
    let char: String
    let on: String
    let kun: String
    let meaning: String
    let word: String
    var displayMeaning: String {
        meaning.hasPrefix("EN ·") ? "Đang bổ sung nghĩa tiếng Việt" : meaning
    }
}

struct ReadingLesson: Decodable, Identifiable {
    let id: String
    let title: String
    let topic: String
    let text: String
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
        let eligible = data.vocab.filter { $0.week <= week && !$0.meaning.hasPrefix("EN ·") }
        let meanings = data.vocab.filter { !$0.meaning.hasPrefix("EN ·") }.map(\.displayMeaning)
        return eligible.shuffled().prefix(100).map { item in
            create(category: "Từ vựng", prompt: "「\(item.word)」（\(item.reading)）nghĩa là gì?",
                   passage: item.example, correct: item.displayMeaning,
                   others: meanings,
                   explanation: "\(item.word)・\(item.reading): \(item.displayMeaning). Ví dụ: \(item.exampleVi ?? item.example)")
        }
    }

    static func grammar(_ data: CourseData, week: Int) -> [ExamQuestion] {
        let eligible = data.grammar.filter { $0.week <= week && !$0.meaning.hasPrefix("EN ·") }
        let meanings = data.grammar.filter { !$0.meaning.hasPrefix("EN ·") }.map(\.displayMeaning)
        return eligible.shuffled().prefix(70).map { item in
            create(category: "Ngữ pháp", prompt: "Ý nghĩa của \(item.pattern) là gì?",
                   passage: item.example, correct: item.displayMeaning,
                   others: meanings,
                   explanation: "\(item.displayRule) Ví dụ: \(item.translation)")
        }
    }

    static func kanji(_ data: CourseData) -> [ExamQuestion] {
        data.kanji.filter { !$0.meaning.hasPrefix("EN ·") }.map { item in
            create(category: "Kanji", prompt: "Chữ 「\(item.char)」 có nghĩa gì?",
                   passage: "Từ liên quan: \(item.word)", correct: item.displayMeaning,
                   others: data.kanji.filter { !$0.meaning.hasPrefix("EN ·") }.map(\.displayMeaning),
                   explanation: "Âm On: \(item.on) · Âm Kun: \(item.kun) · Từ: \(item.word)")
        }
    }

    static func reading(_ data: CourseData) -> [ExamQuestion] {
        data.readings.map { item in
            ExamQuestion(category: "Đọc hiểu", prompt: item.question,
                         passage: item.text, audioText: nil, choices: item.choices,
                         answer: item.answer, explanation: item.explanation)
        }
    }

    static func listening(_ data: CourseData) -> [ExamQuestion] {
        data.listening.map { item in
            ExamQuestion(category: "Nghe hiểu", prompt: item.question,
                         passage: nil, audioText: item.script, choices: item.choices,
                         answer: item.answer, explanation: item.explanation)
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