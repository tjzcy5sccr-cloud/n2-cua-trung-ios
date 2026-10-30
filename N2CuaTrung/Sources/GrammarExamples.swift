import Foundation

struct GrammarIllustration: Decodable {
    let structure: String
    let extra: [GrammarSample]
}

struct GrammarSample: Decodable, Identifiable {
    let text: String
    let translation: String
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
        stored[grammar.id]?.structure ?? grammar.rule
    }

    static func examples(for grammar: Grammar) -> [GrammarSample] {
        let main = GrammarSample(text: grammar.example, translation: grammar.translation)
        return [main] + (stored[grammar.id]?.extra ?? [])
    }
}