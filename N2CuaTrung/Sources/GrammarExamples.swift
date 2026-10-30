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

    static func structure(for grammar: Grammar) -> String {
        grammar.meaning.hasPrefix("EN ·") ? "Đang bổ sung cách dùng bằng tiếng Việt." : (stored[grammar.id]?.structure ?? grammar.rule)
    }

    static func examples(for grammar: Grammar) -> [GrammarSample] {
        let main = GrammarSample(text: grammar.example, translation: grammar.displayTranslation, translationStatus: grammar.translationStatus)
        let all = [main] + (stored[grammar.id]?.extra ?? grammar.samples ?? [])
        return all.map { part in
            let visible: String
            if part.translationStatus == "machine_translated_unreviewed" {
                visible = "Dịch tự động theo nghĩa chính (cần kiểm tra): " + part.translation
            } else if part.translationStatus == "needs_sentence_review" {
                visible = "Bản dịch ví dụ này đang được đối chiếu."
            } else if part.translation.hasPrefix("EN ·") {
                visible = "Bản dịch tiếng Việt đang được bổ sung."
            } else {
                visible = part.translation
            }
            return GrammarSample(text: part.text, translation: visible, translationStatus: part.translationStatus)
        }
    }
}