import Foundation

// All sentences/words below are short, original test fixtures. They are not
// copied from the user's textbooks and they are not published as app lessons.
@main
enum SourceQuestionBankTests {
    static func lesson(_ id: String, word: String, reading: String,
                       meaning: String) -> [String: Any] {
        [
            "id": id, "word": word, "reading": reading, "meaning": meaning,
            "topic": "Kiểm thử", "week": 1, "example": "",
            "meaningStatus": "editorial_reviewed",
            "exampleStatus": "pending"
        ]
    }

    static func course(_ values: [[String: Any]]) throws -> CourseData {
        let obj: [String: Any] = [
            "vocab": values, "grammar": [[String: Any]](),
            "kanji": [[String: Any]](), "readings": [[String: Any]](),
            "listening": [[String: Any]](), "weeks": [[String: Any]]()
        ]
        let data = try JSONSerialization.data(withJSONObject: obj)
        return try JSONDecoder().decode(CourseData.self, from: data)
    }

    static func main() throws {
        let values = [
            lesson("v1", word: "改善", reading: "かいぜん", meaning: "cải thiện"),
            lesson("v2", word: "調整", reading: "ちょうせい", meaning: "điều chỉnh"),
            lesson("v3", word: "計画", reading: "けいかく", meaning: "kế hoạch"),
            lesson("v4", word: "組織", reading: "そしき", meaning: "tổ chức"),
            lesson("v5", word: "最善", reading: "さいぜん", meaning: " cải thiện ")
        ]

        let clean = try course(Array(values.prefix(4)))
        let generated = QuestionBank.vocabulary(clean, week: 35)
        precondition(generated.count == 4,
                     "Four unambiguous approved words should create questions")
        for q in generated {
            precondition(q.choices.count == 4)
            precondition(Set(q.choices).count == 4)
            precondition(q.choices.indices.contains(q.answer))
        }

        let duplicates = try course([values[0], values[1], values[2], values[4]])
        precondition(QuestionBank.vocabulary(duplicates, week: 35).isEmpty,
                     "Visually duplicate meanings must not become a 4-choice quiz")
        print("PASS: 4 unique meanings needed; all answers unambiguous")
    }
}
