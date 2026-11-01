import Foundation

/// Pure, offline diagnostics over an owner's local candidate metadata.
/// Does not certify translations and never uploads source textbook text.
struct SouMatomeReviewCandidate {
    let id: String
    let bookID: String
    let skill: String
    let heading: String
    let reading: String
    let vietnamese: String
    let inheritedFlags: [String]
}

struct SouMatomeReviewDiagnostics {
    let byID: [String: [String]]
    let repeatedHeadwordGroups: Int
    let repeatedHeadwordRows: Int

    func flags(for id: String) -> [String] { byID[id] ?? [] }
    var requiringAttentionCount: Int {
        byID.values.filter { !$0.isEmpty }.count
    }

    static func analyze(_ entries: [SouMatomeReviewCandidate]) -> Self {
        func normalized(_ input: String) -> String {
            input.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .widthInsensitive],
                         locale: Locale(identifier: "ja_JP"))
                .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        }

        func containsJapanese(_ value: String) -> Bool {
            value.unicodeScalars.contains {
                (0x3040...0x30FF).contains(Int($0.value)) ||
                (0x3400...0x9FFF).contains(Int($0.value))
            }
        }

        func containsKana(_ value: String) -> Bool {
            value.unicodeScalars.contains {
                (0x3040...0x30FF).contains(Int($0.value))
            }
        }

        var groups: [String: [String]] = [:]
        for record in entries {
            let head = normalized(record.heading)
            guard !head.isEmpty else { continue }
            let key = record.bookID + "\u{1F}" + head
            groups[key, default: []].append(record.id)
        }
        let repeats = groups.values.filter { $0.count > 1 }
        let duplicateIDs = Set(repeats.flatMap { $0 })

        var issues: [String: [String]] = [:]
        for record in entries {
            var flags: [String] = record.inheritedFlags
            if !containsJapanese(record.heading) {
                flags.append("NO_JAPANESE_HEADWORD")
            }
            if record.vietnamese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flags.append("MISSING_VIETNAMESE_GLOSS")
            }
            if record.skill == "Từ vựng" &&
               !containsKana(record.reading) {
                flags.append("MISSING_KANA_READING")
            }
            if record.skill == "Kanji" && record.heading.count != 1 {
                flags.append("KANJI_HEADING_NOT_ONE_CHARACTER")
            }
            if containsJapanese(record.vietnamese) {
                flags.append("JAPANESE_PRESENT_IN_VIETNAMESE_GLOSS")
            }
            if duplicateIDs.contains(record.id) {
                flags.append("DUPLICATE_JAPANESE_HEADWORD")
            }
            issues[record.id] = Array(Set(flags)).sorted()
        }

        return .init(byID: issues,
                     repeatedHeadwordGroups: repeats.count,
                     repeatedHeadwordRows: duplicateIDs.count)
    }
}
