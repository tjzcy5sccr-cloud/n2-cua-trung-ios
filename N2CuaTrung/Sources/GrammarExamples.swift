import Foundation

struct GrammarIllustration: Decodable {
    let structure: String
    let extra: [GrammarSample]
}

struct GrammarSample: Decodable, Identifiable {
    let text: String
    let translation: String
    var translationStatus: String? = nil
    var id: String { text }
}

enum GrammarLibrary {
    private static let stored: [String: GrammarIllustration] = {
        guard let url = Bundle.main.url(forResource: "grammar-details", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([String: GrammarIllustration].self, from: data) else {
            return [:]
        }
        return result
    }()

    private static let approvedStatuses: Set<String> = [
        "editorial_reviewed", "source_verified", "independently_verified"
    ]

    static func structure(for grammar: Grammar) -> String {
        // Cách dùng đã biên tập theo gói học chính được ưu tiên.
        // Tư liệu cũ chưa có trạng thái kiểm chứng vẫn giữ trong JSON, không hiện trong app.
        grammar.isApprovedForStudy ? grammar.displayRule : ""
    }

    static func examples(for grammar: Grammar) -> [GrammarSample] {
        var approved: [GrammarSample] = []
        if grammar.hasApprovedExample, !grammar.example.isEmpty, !grammar.displayTranslation.isEmpty {
            approved.append(GrammarSample(text: grammar.example,
                                          translation: grammar.displayTranslation,
                                          translationStatus: grammar.translationStatus))
        }
        let extra = stored[grammar.id]?.extra ?? grammar.samples ?? []
        approved.append(contentsOf: extra.filter {
            approvedStatuses.contains($0.translationStatus ?? "") &&
            !$0.text.isEmpty && !$0.translation.isEmpty &&
            !$0.translation.hasPrefix("EN ·")
        })
        return approved
    }
}