import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Candidate entries are generated ONLY from PDFs on the user's own device.
/// They are not approved app flashcards until their readings, meanings and
/// examples have been checked against the book and a separate dictionary.
struct SouMatomeSourceEntry: Codable, Identifiable {
    let id: String
    let bookId: String
    let page: Int
    let heading: String
    let detail: String
    let skill: String
    let reading: String?
    /// Hán-Việt and readings from the owner's personal PDF, not confirmed
    /// contextual meanings. The dictionary suggestion is independent.
    let sourceHanViet: String?
    let sourceOnKun: String?
    let dictionaryHanViet: String?
    let dictionaryReference: String?
    /// Private-source automated warnings. Never interpreted as approval.
    let qaFlags: [String]?

    init(id: String, bookId: String, page: Int, heading: String,
         detail: String, skill: String, reading: String? = nil,
         qaFlags: [String]? = nil, sourceHanViet: String? = nil,
         sourceOnKun: String? = nil, dictionaryHanViet: String? = nil,
         dictionaryReference: String? = nil) {
        self.id = id
        self.bookId = bookId
        self.page = page
        self.heading = heading
        self.detail = detail
        self.skill = skill
        self.reading = reading
        self.sourceHanViet = sourceHanViet
        self.sourceOnKun = sourceOnKun
        self.dictionaryHanViet = dictionaryHanViet
        self.dictionaryReference = dictionaryReference
        self.qaFlags = qaFlags
    }
}

private enum SouMatomeSourceParser {
    private static let kanjiMarkers = "①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳"
    private static let wordClasses: Set<String> = [
        "n", "v", "adj", "adi", "adv", "s", "n,", "adj,", "adn", "aux",
        "phr", "int", "i-adj", "na-adj"
    ]
    private static let japanese = try! NSRegularExpression(
        pattern: "[\\p{Han}\\p{Hiragana}\\p{Katakana}]")
    private static let grammar = try! NSRegularExpression(
        pattern: "^[A-H][\\.:：]\\s*(.+)")
    private static let numberedKanji = try! NSRegularExpression(
        pattern: "^[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳]\\s*([\\p{Han}])")

    private static func isJapanese(_ text: String) -> Bool {
        japanese.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    static func extract(docId: String, source: URL, pageFolder: URL) -> [SouMatomeSourceEntry] {
        guard let pdf = PDFDocument(url: source) else { return [] }
        var all: [SouMatomeSourceEntry] = []

        for page in 1...pdf.pageCount {
            let file = pageFolder.appendingPathComponent(
                String(format: "page-%04d.txt", page))
            let content = (try? String(contentsOf: file, encoding: .utf8))
                ?? pdf.page(at: page - 1)?.string ?? ""
            let lines = content.split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var found: [(String, String)] = []
            switch docId {
            case "kanji-vi":
                for index in lines.indices {
                    let word = lines[index]
                    guard let match = numberedKanji.firstMatch(
                        in: word, range: NSRange(word.startIndex..., in: word)),
                        let range = Range(match.range(at: 1), in: word) else { continue }
                    let char = String(word[range])
                    let next = index + 1 < lines.count ? lines[index + 1] : ""
                    found.append((char, next))
                }

            case "bunpou-vi":
                for index in lines.indices {
                    let line = lines[index]
                    guard let match = grammar.firstMatch(
                        in: line, range: NSRange(line.startIndex..., in: line)),
                          let range = Range(match.range(at: 1), in: line)
                    else { continue }
                    let pattern = String(line[range])
                    guard isJapanese(pattern) else { continue }
                    var meaning = ""
                    for next in (index+1)..<min(index+6, lines.count) {
                        let candidate = lines[next]
                        if candidate.localizedCaseInsensitiveContains("ý nghĩa") {
                            meaning = candidate
                            break
                        }
                    }
                    found.append((pattern, meaning))
                }

            case "goi-vi":
                for index in lines.indices where index > 0 {
                    let line = lines[index]
                    let pos = line.components(separatedBy: " ").first ?? ""
                    guard wordClasses.contains(pos.lowercased()) else { continue }
                    let word = lines[index-1]
                    guard isJapanese(word) else { continue }
                    var meaning = line.dropFirst(pos.count)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if meaning.isEmpty, index + 1 < lines.count {
                        meaning = lines[index+1]
                    }
                    // Context may be split across several lines in the PDF.
                    // Keep source-page link for verification, do not guess missing words.
                    found.append((word, meaning))
                }

            default:
                break
            }

            for (number, candidate) in found.enumerated() {
                all.append(SouMatomeSourceEntry(
                    id: "\(docId):\(page):\(number)",
                    bookId: docId, page: page,
                    heading: candidate.0, detail: candidate.1,
                    skill: docId == "kanji-vi" ? "Kanji" :
                           docId == "bunpou-vi" ? "Ngữ pháp" : "Từ vựng"))
            }
        }
        return all
    }
}

/// Corrections update private candidate metadata only and never bypass
/// separate Japanese/PDF and Vietnamese validation for a study card.
private struct SouMatomeCandidateCorrectionFile: Decodable {
    struct Change: Decodable {
        let id: String
        let expectedHeading: String
        let newHeading: String?
        let newDetail: String?
        let addFlags: [String]?
    }
    let schemaVersion: Int
    let corrections: [Change]
}

@MainActor
final class SouMatomeSourceEntryStore: ObservableObject {
    @Published var entries: [SouMatomeSourceEntry] = []
    @Published var processing = false
    @Published var loadedBooks = 0
    @Published var notes: String?
    @Published var importedCandidateCount = 0
    @Published private(set) var diagnostics = SouMatomeReviewDiagnostics.analyze([])
    private let root = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        .appendingPathComponent("SouMatomePersonalLibrary", isDirectory: true)

    private var importedURL: URL {
        root.appendingPathComponent("private-draft-candidates.json")
    }

    private func recalculateQuality() {
        diagnostics = SouMatomeReviewDiagnostics.analyze(entries.map { item in
            SouMatomeReviewCandidate(
                id: item.id, bookID: item.bookId,
                skill: item.skill, heading: item.heading,
                reading: item.reading ?? "", vietnamese: item.detail,
                inheritedFlags: item.qaFlags ?? [])
        })
    }

    /// On source replacement, remove only candidates derived from that book.
    /// Stale text may still be shown as a human-edited draft in the review
    /// store, but its approval is revoked separately.
    func invalidateImportedCandidates(for bookID: String) {
        let remaining = loadImportedCandidates().filter { $0.bookId != bookID }
        do {
            if remaining.isEmpty {
                if FileManager.default.fileExists(atPath: importedURL.path) {
                    try FileManager.default.removeItem(at: importedURL)
                }
            } else {
                let data = try JSONEncoder().encode(remaining)
                try data.write(to: importedURL, options: .atomic)
            }
            entries.removeAll { $0.bookId == bookID }
            recalculateQuality()
            importedCandidateCount = remaining.count
        } catch {
            notes = "Không thể làm mới dữ liệu nguồn đã nhập: " + error.localizedDescription
        }
    }

    private func loadImportedCandidates() -> [SouMatomeSourceEntry] {
        guard let data = try? Data(contentsOf: importedURL),
              let decoded = try? JSONDecoder().decode(
                [SouMatomeSourceEntry].self, from: data) else { return [] }
        return decoded
    }

    /// Merge one or more book-specific candidate files, preserving other
    /// books. Report IDs whose source text changed so their approval can be
    /// revoked, rather than assuming unchanged numbered rows are identical.
    @discardableResult
    func importCandidates(from url: URL) throws -> (count: Int, changedIDs: Set<String>) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bytes = try Data(contentsOf: url)
        guard bytes.count > 0, bytes.count <= 8 * 1_024 * 1_024 else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        let incoming = try JSONDecoder().decode(
            [SouMatomeSourceEntry].self, from: bytes)
        guard !incoming.isEmpty, incoming.count <= 15_000,
              Set(incoming.map(\.id)).count == incoming.count else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        let validBooks = Dictionary(uniqueKeysWithValues:
            SouMatomeDocument.all.map { ($0.id, $0.pages) })
        for card in incoming {
            guard let maxPage = validBooks[card.bookId],
                  (1...maxPage).contains(card.page),
                  ["Từ vựng", "Kanji", "Ngữ pháp"].contains(card.skill),
                  card.id.hasPrefix(card.bookId + ":" + String(card.page) + ":"),
                  card.heading.count <= 250, card.detail.count <= 250,
                  (card.reading?.count ?? 0) <= 150,
                  (card.sourceHanViet?.count ?? 0) <= 70,
                  (card.sourceOnKun?.count ?? 0) <= 150,
                  (card.dictionaryHanViet?.count ?? 0) <= 70,
                  (card.dictionaryReference?.count ?? 0) <= 250
            else { throw SouMatomeReviewError.invalidCandidateFile }
        }

        let old = loadImportedCandidates()
        let incomingBooks = Set(incoming.map(\.bookId))
        let oldAffected = old.filter { incomingBooks.contains($0.bookId) }
        // Also catch approvals made against the older PDFKit-derived rows
        // before the more reliable private geometry file was imported.
        var oldByID: [String: SouMatomeSourceEntry] = [:]
        for item in entries where incomingBooks.contains(item.bookId) {
            oldByID[item.id] = item
        }
        for item in oldAffected { oldByID[item.id] = item }
        let incomingByID = Dictionary(uniqueKeysWithValues:
            incoming.map { ($0.id, $0) })
        let changedIDs = Set(oldByID.values.compactMap { previous -> String? in
            guard let updated = incomingByID[previous.id] else {
                return previous.id
            }
            let changed = previous.heading != updated.heading ||
                          previous.detail != updated.detail ||
                          previous.reading != updated.reading ||
                          previous.skill != updated.skill ||
                          previous.sourceHanViet != updated.sourceHanViet ||
                          previous.sourceOnKun != updated.sourceOnKun ||
                          previous.dictionaryHanViet != updated.dictionaryHanViet
            return changed ? previous.id : nil
        })
        let merged = old.filter { !incomingBooks.contains($0.bookId) } + incoming
        let mergedBytes = try JSONEncoder().encode(merged)
        guard mergedBytes.count <= 8 * 1_024 * 1_024 else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
        try mergedBytes.write(to: importedURL, options: .atomic)
        importedCandidateCount = merged.count
        let unaffected = entries.filter { !incomingBooks.contains($0.bookId) }
        entries = (unaffected + incoming).sorted { $0.id < $1.id }
        recalculateQuality()
        return (incoming.count, changedIDs)
    }

    /// Apply a small reviewed-source correction patch without replacing the
    /// entire 2,963-entry library or silently approving unverified meanings.
    func applyPrivateCorrections(from url: URL) throws -> (Int, Set<String>) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let bytes = try Data(contentsOf: url)
        guard !bytes.isEmpty, bytes.count <= 1024 * 1024 else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        let patch = try JSONDecoder().decode(
            SouMatomeCandidateCorrectionFile.self, from: bytes)
        guard patch.schemaVersion == 1, !patch.corrections.isEmpty,
              patch.corrections.count <= 300,
              Set(patch.corrections.map(\.id)).count == patch.corrections.count else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        var candidates = loadImportedCandidates()
        guard !candidates.isEmpty else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        let indices = Dictionary(uniqueKeysWithValues:
            candidates.enumerated().map { ($0.element.id, $0.offset) })
        var changedIDs: Set<String> = []
        for update in patch.corrections {
            guard let at = indices[update.id] else {
                throw SouMatomeReviewError.invalidCandidateFile
            }
            let existing = candidates[at]
            guard existing.heading == update.expectedHeading,
                  (update.newDetail?.count ?? 0) <= 250,
                  (update.newHeading?.count ?? 0) <= 250,
                  (update.addFlags ?? []).count <= 12,
                  (update.addFlags ?? []).allSatisfy({
                      !$0.isEmpty && $0.count <= 72 &&
                      $0.range(of: "^[A-Z0-9_]+$", options: .regularExpression) != nil
                  })
            else { throw SouMatomeReviewError.invalidCandidateFile }
            if let text = update.newDetail,
               text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw SouMatomeReviewError.invalidCandidateFile
            }
            let heading = update.newHeading ?? existing.heading
            guard heading.range(of: "[\\p{Han}\\p{Hiragana}\\p{Katakana}]",
                                   options: .regularExpression) != nil else {
                throw SouMatomeReviewError.invalidCandidateFile
            }
            let detail = update.newDetail ?? existing.detail
            var flags = existing.qaFlags ?? []
            if update.newDetail != nil && !detail.isEmpty {
                flags.removeAll { $0 == "MISSING_VIETNAMESE_GLOSS" }
            }
            flags = Array(Set(flags + (update.addFlags ?? []))).sorted()
            let next = SouMatomeSourceEntry(
                id: existing.id, bookId: existing.bookId,
                page: existing.page, heading: heading,
                detail: detail, skill: existing.skill,
                reading: existing.reading, qaFlags: flags,
                sourceHanViet: existing.sourceHanViet,
                sourceOnKun: existing.sourceOnKun,
                dictionaryHanViet: existing.dictionaryHanViet,
                dictionaryReference: existing.dictionaryReference)
            if heading != existing.heading ||
               detail != existing.detail || flags != (existing.qaFlags ?? []) {
                candidates[at] = next
                changedIDs.insert(existing.id)
            }
        }
        let out = try JSONEncoder().encode(candidates)
        guard out.count <= 8 * 1024 * 1024 else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
        try out.write(to: importedURL, options: .atomic)
        var keyed = Dictionary(uniqueKeysWithValues:
            entries.map { ($0.id, $0) })
        for card in candidates { keyed[card.id] = card }
        entries = keyed.values.sorted { $0.id < $1.id }
        importedCandidateCount = candidates.count
        recalculateQuality()
        return (changedIDs.count, changedIDs)
    }

    func indexBooks() async {
        guard !processing else { return }
        processing = true
        entries = []
        loadedBooks = 0
        let candidates = ["goi-vi", "kanji-vi", "bunpou-vi"]
        let imported = loadImportedCandidates()
        let importedBooks = Set(imported.map(\.bookId))
        let available: [(String, URL)] = candidates.compactMap { name in
            let pdf = root.appendingPathComponent(name + ".pdf")
            return FileManager.default.fileExists(atPath: pdf.path) ? (name, pdf) : nil
        }
        for (book, pdf) in available {
            if importedBooks.contains(book) {
                // Never mix imprecise PDFKit line parsing with the verified-
                // provenance geometry-extracted candidate IDs for this book.
                loadedBooks += 1
                continue
            }
            let folder = root.appendingPathComponent("PageText", isDirectory: true)
                .appendingPathComponent(book, isDirectory: true)
            let parsed = await Task.detached(priority: .userInitiated) {
                SouMatomeSourceParser.extract(docId: book, source: pdf, pageFolder: folder)
            }.value
            entries.append(contentsOf: parsed)
            loadedBooks += 1
        }
        var keyed: [String: SouMatomeSourceEntry] = [:]
        for item in entries { keyed[item.id] = item }
        // Locally extracted geometry-based entries supersede imprecise PDFKit
        // line-based detection, but remain unapproved study candidates.
        for item in imported { keyed[item.id] = item }
        entries = keyed.values.sorted {
            $0.bookId == $1.bookId
                ? ($0.page == $1.page ? $0.id < $1.id : $0.page < $1.page)
                : $0.bookId < $1.bookId
        }
        importedCandidateCount = imported.count
        recalculateQuality()
        notes = "Đã nhận diện \(entries.count) ứng viên từ PDF, gồm \(imported.count) bản ghi nhập riêng. Chưa được kiểm duyệt."
        processing = false
    }
}

struct SouMatomeSourceEntriesView: View {
    @StateObject private var source = SouMatomeSourceEntryStore()
    @StateObject private var library = SouMatomeLibraryStore()
    @State private var query = ""
    @State private var skill = "Tất cả"
    @State private var qualityFilter = "Tất cả"
    @State private var displayLimit = 200
    @State private var revealedIDs: Set<String> = []
    @StateObject private var reviews = SouMatomePersonalReviewStore()
    @EnvironmentObject private var studyStore: StudyStore
    @State private var installMessage: String?
    @State private var pickCandidateJSON = false
    @State private var pickCorrectionJSON = false
    @State private var correctionMessage: String?
    @State private var importMessage: String?
    private let skills = ["Tất cả", "Từ vựng", "Kanji", "Ngữ pháp"]
    private let qualityFilters = ["Tất cả", "Cần rà soát", "Trùng chữ Nhật", "Thiếu nghĩa Việt", "Thiếu cách đọc", "Đã kiểm chứng", "Chưa kiểm chứng"]

    private var matching: [SouMatomeSourceEntry] {
        source.entries.filter { item in
            (skill == "Tất cả" || skill == item.skill) &&
            (qualityFilter == "Tất cả" ||
             (qualityFilter == "Cần rà soát" &&
              !source.diagnostics.flags(for: item.id).isEmpty) ||
             (qualityFilter == "Trùng chữ Nhật" &&
              source.diagnostics.flags(for: item.id).contains("DUPLICATE_JAPANESE_HEADWORD")) ||
             (qualityFilter == "Thiếu nghĩa Việt" &&
              source.diagnostics.flags(for: item.id).contains(where: {
                  ["MISSING_VIETNAMESE_GLOSS",
                   "MISSING_ADJACENT_VIETNAMESE_MEANING",
                   "MISSING_VIETNAMESE_SENSE_AND_READINGS"].contains($0)
              })) ||
             (qualityFilter == "Thiếu cách đọc" &&
              source.diagnostics.flags(for: item.id).contains(where: {
                  ["MISSING_KANA_READING",
                   "MISSING_VIETNAMESE_SENSE_AND_READINGS"].contains($0)
              })) ||
             (qualityFilter == "Đã kiểm chứng" &&
              reviews.cards[item.id]?.isApproved == true) ||
             (qualityFilter == "Chưa kiểm chứng" &&
              reviews.cards[item.id]?.isApproved != true)) &&
            (query.isEmpty || (item.heading + " " + item.detail)
                .localizedCaseInsensitiveContains(query))
        }
    }

    private func progressRow(for skillName: String) -> some View {
        let items = source.entries.filter { $0.skill == skillName }
        let approved = items.filter {
            reviews.cards[$0.id]?.isApproved == true
        }.count
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(skillName).font(.subheadline)
                Spacer()
                Text("\(approved)/\(items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Palette.navy)
            }
            ProgressView(value: Double(approved),
                         total: Double(max(1, items.count)))
                .tint(Palette.teal)
        }
    }

    private func reviewFlagLabel(_ code: String) -> String {
        switch code {
        case "MISSING_VIETNAMESE_GLOSS", "MISSING_ADJACENT_VIETNAMESE_MEANING",
             "MISSING_VIETNAMESE_SENSE_AND_READINGS":
            return "Thiếu nghĩa Việt"
        case "MISSING_KANA_READING": return "Thiếu cách đọc"
        case "DUPLICATE_JAPANESE_HEADWORD": return "Chữ Nhật trùng"
        case "POSSIBLY_FRAGMENTED_FURIGANA": return "Tách dòng/furigana"
        case "HEADING_NOT_CONTIGUOUS_ON_SOURCE_PAGE": return "Chữ Nhật cần đối chiếu"
        case "READING_NOT_CONTIGUOUS_ON_SOURCE_PAGE": return "Cách đọc cần đối chiếu"
        case "JAPANESE_PRESENT_IN_VIETNAMESE_GLOSS": return "Nghĩa có chữ Nhật"
        case "NO_JAPANESE_HEADWORD": return "Thiếu chữ Nhật"
        case "MISSING_HAN_VIET_LABEL": return "PDF thiếu âm Hán–Việt"
        case "HAN_VIET_CONFLICT_WITH_DICTIONARY": return "Hán–Việt khác từ điển"
        case "SOURCE_READING_SPLIT_ACROSS_PAGE": return "Cách đọc bị cắt trang"
        case "NEEDS_CONTEXTUAL_VIETNAMESE_MEANING": return "Cần dịch nghĩa Kanji"
        case "PAGE_CONTINUATION_FRAGMENT_NEEDS_RECONSTRUCTION":
            return "Dòng bị cắt ở đầu trang"
        case "CONTEXT_DEPENDENT_SUFFIX_NEEDS_REVIEW": return "Hậu tố cần ngữ cảnh"
        case "HEADING_RECONSTRUCTED_FROM_PDF": return "Đã ghép lại tiêu đề"
        case "SOURCE_TYPO_CORRECTED": return "Đã sửa lỗi nguồn"
        case "HEADING_IS_EXAMPLE_NOT_GRAMMAR_RULE": return "Ví dụ, chưa phải quy tắc"
        case "INDEPENDENT_DICTIONARY_CROSSCHECKED": return "Có đối chiếu từ điển"
        default: return "Kiểm tra nguồn"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Mục học từ toàn bộ tài liệu",
                             subtitle: "Tự đọc 3 PDF bổ trợ đã nhập, không chia tuần")
                LessonPanel {
                    Text(source.notes ?? "Tìm các mục học có thể nhận diện từ sách tiếng Việt đã nhập.")
                        .font(.subheadline).foregroundColor(Palette.navy)
                    MainButton(title: source.processing ? "Đang phân tích…" : "Quét tất cả trang có chữ",
                               symbol: "text.magnifyingglass") {
                        Task { await source.indexBooks() }
                    }.disabled(source.processing)
                    Text("Danh sách này chỉ là ứng viên cần kiểm tra. Các mục OCR sai hoặc nội dung bị xuống dòng sẽ cần hiệu đính trước khi xuất sang flashcard.")
                        .font(.caption).foregroundColor(.secondary)
                    MainButton(title: "Nhập tệp ứng viên từ PDF cá nhân",
                               symbol: "doc.badge.plus") {
                        pickCandidateJSON = true
                    }
                    MainButton(title: "Áp dụng bản vá nghĩa Nhật–Việt đã đối chiếu",
                               symbol: "checkmark.shield") {
                        pickCorrectionJSON = true
                    }
                    if let correctionMessage {
                        Text(correctionMessage).font(.caption)
                            .foregroundColor(Palette.navy)
                    }
                    Text("Bản vá chỉ sửa ứng viên và cảnh báo nguồn. Mọi mục vẫn cần xác nhận trước khi xuất flashcard.")
                        .font(.caption).foregroundColor(.secondary)
                    if source.importedCandidateCount > 0 {
                        Text("Cần rà soát: \(source.diagnostics.requiringAttentionCount) ứng viên · \(source.diagnostics.repeatedHeadwordGroups) nhóm trùng chữ Nhật (\(source.diagnostics.repeatedHeadwordRows) dòng). Không tự xóa các từ nhiều nghĩa.")
                            .font(.caption).foregroundColor(Palette.orange)
                        Text("Đã nhận \(source.importedCandidateCount) ứng viên từ tệp JSON cá nhân.")
                            .font(.caption).foregroundColor(Palette.teal)
                    }
                    if let importMessage {
                        Text(importMessage).font(.caption).foregroundColor(Palette.navy)
                    }
                }
                LessonPanel {
                    SectionTitle("Kho flashcard đã kiểm chứng")
                    Text("\(reviews.approvedCount) mục đã xác minh trong \(source.entries.count) ứng viên · \(reviews.draftCount) bản nháp từng lưu")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.navy)
                    progressRow(for: "Từ vựng")
                    progressRow(for: "Kanji")
                    progressRow(for: "Ngữ pháp")
                    Text("Chỉ mục được kiểm chứng và có PDF gốc mới tính vào tiến độ hoàn thiện nội dung.")
                        .font(.caption).foregroundColor(.secondary)
                    Text("Các ứng viên tách từ PDF chỉ chuyển thành thẻ học khi đã kiểm tra riêng chữ Nhật, cách đọc và nghĩa Việt. Không tự duyệt hàng loạt.")
                        .font(.caption).foregroundColor(.secondary)
                    MainButton(title: "Cập nhật flashcard và câu hỏi đã kiểm chứng",
                               symbol: "checkmark.seal.fill") {
                        do {
                            let count = try reviews.installApprovedIntoStudy(studyStore)
                            installMessage = "Đã cập nhật \(count) mục đã kiểm chứng vào bộ Sou Matome. Các bài luyện mới dùng dữ liệu này."
                        } catch {
                            installMessage = error.localizedDescription
                        }
                    }.disabled(reviews.approvedCount == 0)
                    if let installMessage {
                        Text(installMessage).font(.footnote)
                            .foregroundColor(Palette.navy)
                    }
                }
                LessonPanel {
                    Picker("Kỹ năng", selection: $skill) {
                        ForEach(skills, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                    Picker("Tình trạng", selection: $qualityFilter) {
                        ForEach(qualityFilters, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                    TextField("Tìm chữ Nhật hoặc nghĩa Việt", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Text("\(matching.count) ứng viên phù hợp")
                        .font(.caption.weight(.semibold)).foregroundColor(Palette.blue)
                }
                LazyVStack(spacing: 9) {
                    ForEach(matching.prefix(displayLimit)) { entry in
                        LessonPanel {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.heading)
                                        .font(.headline).foregroundColor(Palette.navy)
                                    if entry.skill == "Kanji" {
                                        if let label = entry.sourceHanViet, !label.isEmpty {
                                            Text("Hán–Việt theo PDF: " + label)
                                                .font(.caption).foregroundColor(Palette.blue)
                                        }
                                        if let reads = entry.sourceOnKun, !reads.isEmpty {
                                            Text("Đọc theo PDF: " + reads)
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                        if let suggestion = entry.dictionaryHanViet,
                                           !suggestion.isEmpty {
                                            Text("Từ điển đối chiếu: " + suggestion)
                                                .font(.caption).foregroundColor(Palette.orange)
                                        }
                                    }
                                    if !entry.detail.isEmpty {
                                        if revealedIDs.contains(entry.id) {
                                            Text(entry.detail)
                                                .font(.subheadline).foregroundColor(.secondary)
                                        }
                                        Button(revealedIDs.contains(entry.id) ? "Ẩn nghĩa" : "Hiện nghĩa") {
                                            if revealedIDs.contains(entry.id) {
                                                revealedIDs.remove(entry.id)
                                            } else {
                                                revealedIDs.insert(entry.id)
                                            }
                                        }
                                        .font(.caption)
                                        .buttonStyle(.borderless)
                                    }
                                    Button {
                                        JapaneseVoice.shared.speak(entry.heading)
                                    } label: {
                                        Label("Nghe tiếng Nhật", systemImage: "speaker.wave.2")
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                    if !source.diagnostics.flags(for: entry.id).isEmpty {
                                        Label("Cần rà soát: " +
                                              source.diagnostics.flags(for: entry.id)
                                                .map(reviewFlagLabel).joined(separator: " · "),
                                              
                                              systemImage: "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundColor(Palette.orange)
                                    }
                                    Text("\(entry.skill) · Trang \(entry.page) · "
                                         + (reviews.cards[entry.id]?.isApproved == true
                                            ? "Đã kiểm chứng" : "Chưa kiểm chứng"))
                                        .font(.caption)
                                        .foregroundColor(reviews.cards[entry.id]?.isApproved == true
                                                         ? Palette.teal : .secondary)
                                    NavigationLink {
                                        SouMatomePersonalCardEditor(candidate: entry,
                                                                     reviews: reviews,
                                                                     reviewQueue: source.entries)
                                    } label: {
                                        Label("Sửa và kiểm tra nghĩa", systemImage: "checkmark.seal")
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                                Spacer()
                                if let book = SouMatomeDocument.all.first(where: { $0.id == entry.bookId }),
                                   let url = library.fileURL(for: book) {
                                    NavigationLink {
                                        SouMatomePDFReader(book: book, url: url,
                                                           initialPage: entry.page)
                                    } label: {
                                        Image(systemName: "book.closed.fill")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                if matching.count > displayLimit {
                    Button("Xem thêm mục (\(min(displayLimit, matching.count))/\(matching.count))") {
                        displayLimit += 200
                    }.buttonStyle(.bordered)
                }
                NavigationLink {
                    SouMatomeWholeBooksView()
                } label: {
                    ActionTile(icon: "books.vertical", color: Palette.teal,
                               title: "Trở về toàn bộ sách",
                               detail: "Mở PDF để xem mọi nội dung chưa được tách thành mục")
                }.buttonStyle(.plain)
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Mục học trong sách")
        .navigationBarTitleDisplayMode(.inline)
        .task { await source.indexBooks() }
        .fileImporter(isPresented: $pickCorrectionJSON,
                      allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    let applied = try source.applyPrivateCorrections(from: url)
                    try reviews.invalidateCandidateIDs(applied.1)
                    _ = try reviews.synchronizeApprovedCards(with: studyStore)
                    correctionMessage = "Đã cập nhật \(applied.0) ứng viên; thẻ có nguồn thay đổi sẽ phải duyệt lại."
                } catch {
                    correctionMessage = error.localizedDescription
                }
            case .failure(let error):
                correctionMessage = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $pickCandidateJSON,
                      allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                Task {
                    do {
                        let imported = try source.importCandidates(from: url)
                        try reviews.invalidateCandidateIDs(imported.changedIDs)
                        _ = try reviews.synchronizeApprovedCards(with: studyStore)
                        importMessage = "Đã nhập \(imported.count) ứng viên; "
                            + "đã hủy xác nhận cho \(imported.changedIDs.count) mục đổi nguồn. "
                            + "Cần đối chiếu trước khi đưa mục mới vào luyện tập."
                    } catch {
                        importMessage = error.localizedDescription
                    }
                }
            case .failure(let error):
                importMessage = error.localizedDescription
            }
        }
    }
}
