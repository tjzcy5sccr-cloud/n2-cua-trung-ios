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
        // Khôi phục cách dùng và ghi chú gốc; trạng thái kiểm tra chỉ ở JSON.
        stored[grammar.id]?.structure ?? grammar.rule
    }

    static func examples(for grammar: Grammar) -> [GrammarSample] {
        let main = GrammarSample(text: grammar.example,
                                 translation: grammar.displayTranslation,
                                 translationStatus: grammar.translationStatus)
        let extra = stored[grammar.id]?.extra ?? grammar.samples ?? []
        // Trả lại toàn bộ ví dụ đã được lưu, kể cả chưa kiểm duyệt.
        // Không hiển thị nhãn "tham khảo/chưa duyệt" ở UI.
        return ([main] + extra).filter { !$0.text.isEmpty }
    }

}