import SwiftUI

/// Nghĩa Hán tự và các từ liên quan: tận dụng từ điển từ vựng đã lưu trong ứng dụng.
struct KanjiVocabularyView: View {
    let item: Kanji
    let vocabulary: [Vocabulary]

    private var compounds: [String] {
        item.word.components(separatedBy: CharacterSet(charactersIn: "、,，/"))
            .map {
                $0.replacingOccurrences(of: "[（(][^）)]*[）)]", with: "",
                                           options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private var vocabByWord: [String: Vocabulary] {
        Dictionary(vocabulary.map { ($0.word, $0) },
                   uniquingKeysWith: { old, _ in old })
    }

    private var related: [Vocabulary] {
        let shown = Set(compounds)
        return Array(vocabulary
            .filter { $0.word.contains(item.char) && !shown.contains($0.word) }
            .sorted { $0.word.count < $1.word.count }
            .prefix(12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Nghĩa Hán tự", subtitle: item.displayMeaning)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Âm On").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    Text(item.on).font(.subheadline).foregroundColor(Palette.navy)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Âm Kun").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    Text(item.kun).font(.subheadline).foregroundColor(Palette.navy)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            SectionTitle("Từ ghép", subtitle: "Nghĩa tiếng Việt dưới mỗi từ")
            ForEach(compounds, id: \.self) { word in
                VStack(alignment: .leading, spacing: 3) {
                    FuriganaText(text: word,
                                 mainWord: vocabByWord[word]?.word ?? "",
                                 mainReading: vocabByWord[word]?.reading ?? "", size: 17)
                    if let value = vocabByWord[word] {
                        Text(value.displayMeaning)
                            .font(.subheadline).foregroundColor(Palette.teal)
                    } else {
                        Text("Nghĩa tiếng Việt chưa có trong kho từ vựng.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            SectionTitle("Từ liên quan", subtitle: "Các từ có chứa chữ Kanji này")
            if related.isEmpty {
                Text("Chưa có từ liên quan khác trong kho N2.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(related, id: \.id) { value in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(value.word).font(.subheadline.weight(.semibold))
                                .foregroundColor(Palette.navy)
                            Text(value.reading).font(.caption).foregroundColor(Palette.blue)
                        }
                        Text(value.displayMeaning).font(.subheadline)
                            .foregroundColor(Palette.teal)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
