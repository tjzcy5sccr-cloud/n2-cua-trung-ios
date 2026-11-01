import Foundation

@main enum CandidateAuditTests {
    static func item(_ id: String, _ heading: String, _ read: String,
                     _ gloss: String, _ skill: String = "Từ vựng",
                     flags: [String] = []) -> SouMatomeReviewCandidate {
        .init(id: id, bookID: "goi-vi", skill: skill,
              heading: heading, reading: read,
              vietnamese: gloss, inheritedFlags: flags)
    }

    static func main() {
        // All examples below are freshly authored; no commercial book text.
        let rows = [
            item("v1", "調整", "ちょうせい", "điều chỉnh"),
            item("v2", " 調 整 ", "ちょうせい", "sắp xếp"),
            item("v3", "予定", "よてい", ""),
            item("v4", "改善", "", "cải thiện"),
            item("v5", "確認", "かくにん", "xác nhận",
                 flags: ["CHECK_SOURCE_PAGE"]),
            item("v6", "結果", "けっか", "kết quả")
        ]
        let audit = SouMatomeReviewDiagnostics.analyze(rows)
        precondition(audit.repeatedHeadwordGroups == 1)
        precondition(audit.repeatedHeadwordRows == 2)
        precondition(audit.flags(for: "v1").contains("DUPLICATE_JAPANESE_HEADWORD"))
        precondition(audit.flags(for: "v2").contains("DUPLICATE_JAPANESE_HEADWORD"))
        precondition(audit.flags(for: "v3").contains("MISSING_VIETNAMESE_GLOSS"))
        precondition(audit.flags(for: "v4").contains("MISSING_KANA_READING"))
        precondition(audit.flags(for: "v5").contains("CHECK_SOURCE_PAGE"))
        precondition(audit.flags(for: "v6").isEmpty)
        precondition(audit.requiringAttentionCount == 5)
        print("PASS: duplicate kanji wording, Vietnamese gloss, kana, inherited flags, reviewed queue")
    }
}
