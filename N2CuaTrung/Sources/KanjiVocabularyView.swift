import SwiftUI

/// Nghĩa Hán tự và các từ liên quan: tận dụng từ điển từ vựng đã lưu trong ứng dụng.
struct KanjiVocabularyView: View {
    @EnvironmentObject private var study: StudyStore
    let item: Kanji
    let vocabulary: [Vocabulary]

    private var bookSourceOnly: Bool {
        study.selectedSeries == .souMatome ||
        item.id.hasPrefix("sm-reviewed-")
    }

    private var compounds: [String] {
        item.word.components(separatedBy: CharacterSet(charactersIn: "、,，/"))
            .map {
                $0.replacingOccurrences(of: "[（(][^）)]*[）)]", with: "",
                                           options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty && vocabByWord[$0] != nil }
    }

    private var vocabByWord: [String: Vocabulary] {
        Dictionary(vocabulary.filter { $0.isApprovedForStudy }.map { ($0.word, $0) },
                   uniquingKeysWith: { old, _ in old })
    }

    private var related: [Vocabulary] {
        let shown = Set(compounds)
        return Array(vocabulary
            .filter { $0.isApprovedForStudy && $0.word.contains(item.char) && !shown.contains($0.word) }
            .sorted { $0.word.count < $1.word.count }
            .prefix(12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Nghĩa chữ Kanji", subtitle: item.displayMeaning)
            if bookSourceOnly {
                if let label = item.hanViet, !label.isEmpty {
                    Text("Âm Hán–Việt ghi trong sách: " + label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.blue)
                } else {
                    Text("Chưa có âm Hán–Việt được duyệt từ PDF sách")
                        .font(.caption).foregroundColor(.secondary)
                }
                Text("Bộ Sou Matome chỉ hiển thị dữ liệu từ sách. Không dùng nghĩa bộ thủ hay từ điển khác để bổ sung.")
                    .font(.caption2).foregroundColor(.secondary)
            } else if let info = KangxiReference.info(for: item.char) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Âm Hán–Việt")
                            .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                        Text(item.hanViet.flatMap { $0.isEmpty ? nil : $0 } ??
                             info.sinoVietnamese)
                            .font(.headline).foregroundColor(Palette.blue)
                        if let label = item.hanViet, !label.isEmpty,
                           label.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                         locale: Locale(identifier: "vi_VN")) !=
                           info.sinoVietnamese.folding(
                               options: [.caseInsensitive, .diacriticInsensitive],
                               locale: Locale(identifier: "vi_VN")) {
                            Text("Đối chiếu từ điển: " + info.sinoVietnamese)
                                .font(.caption).foregroundColor(Palette.orange)
                        }
                    }
                    Spacer()
                    if let radical = KangxiReference.radical(forKanji: item.char) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bộ thủ #\(radical.id)")
                                .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                            Text("\(radical.character) • \(radical.sinoVietnamese.capitalized)")
                                .font(.headline).foregroundColor(Palette.navy)
                            Text(radical.meaning)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            } else if let radical = KangxiReference.radical(for: item.char) {
                Text("Bộ thủ #\(radical.id): \(radical.character) — \(radical.sinoVietnamese.capitalized) (\(radical.meaning))")
                    .font(.subheadline).foregroundColor(Palette.blue)
            }
            if !bookSourceOnly {
                Text("Bộ thủ dùng để phân loại chữ; không được lấy nghĩa bộ thủ thay cho nghĩa của cả Kanji hoặc từ ghép.")
                    .font(.caption2).foregroundColor(.secondary)
            }
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
            if !compounds.isEmpty {
                Divider()
                SectionTitle("Từ ghép", subtitle: "Nghĩa tiếng Việt dưới mỗi từ")
            }
            ForEach(compounds, id: \.self) { word in
                VStack(alignment: .leading, spacing: 3) {
                    FuriganaText(text: word,
                                 mainWord: vocabByWord[word]?.word ?? "",
                                 mainReading: vocabByWord[word]?.reading ?? "", size: 17)
                    if let value = vocabByWord[word] {
                        Text(value.displayMeaning)
                            .font(.subheadline).foregroundColor(Palette.teal)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if !related.isEmpty {
                Divider()
                SectionTitle("Từ liên quan", subtitle: "Các từ có chứa chữ Kanji này")
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
