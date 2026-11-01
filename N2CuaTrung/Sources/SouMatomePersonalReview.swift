import SwiftUI
import Foundation

// All user-supplied content and review decisions stay on the owner's iPhone.
// Machine-extracted candidates NEVER enter the study/quiz pool automatically.
struct SouMatomePersonalCard: Codable, Identifiable, Equatable {
    let id: String
    let bookID: String
    let page: Int
    let kind: String
    var japanese: String
    var reading: String
    var vietnamese: String
    var explanation: String
    var exampleJapanese: String
    var exampleVietnamese: String
    var onReading: String
    var kunReading: String
    var relatedWord: String
    /// Short source label, not a substitute for contextual Vietnamese meaning.
    var hanViet: String?
    var sourceChecked: Bool
    var translationChecked: Bool
    var lastApproved: Date?

    private var hasJapaneseText: Bool {
        japanese.unicodeScalars.contains {
            (0x3040...0x30FF).contains(Int($0.value)) ||
            (0x3400...0x9FFF).contains(Int($0.value))
        }
    }

    private var readingHasKana: Bool {
        reading.unicodeScalars.contains {
            (0x3040...0x30FF).contains(Int($0.value))
        }
    }

    var sourcePDFIsAvailable: Bool {
        // Only a personal, locally imported PDF may certify this card.
        let source = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SouMatomePersonalLibrary", isDirectory: true)
            .appendingPathComponent(bookID + ".pdf")
        return FileManager.default.fileExists(atPath: source.path)
    }

    var isAppropriateForReview: Bool {
        hasJapaneseText &&
        !vietnamese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (kind != "Từ vựng" || readingHasKana) &&
        (kind != "Kanji" || (japanese.count == 1 &&
            (onReading + kunReading).unicodeScalars.contains {
                (0x3040...0x30FF).contains(Int($0.value))
            }))
    }

    var isApproved: Bool {
        sourceChecked && translationChecked && lastApproved != nil &&
        sourcePDFIsAvailable && hasJapaneseText &&
        !vietnamese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !vietnamese.hasPrefix("EN ·") &&
        (kind != "Từ vựng" || readingHasKana) &&
        (kind != "Kanji" || (japanese.count == 1 &&
            (onReading + kunReading).unicodeScalars.contains {
                (0x3040...0x30FF).contains(Int($0.value))
            }))
    }

    static func draft(_ entry: SouMatomeSourceEntry) -> SouMatomePersonalCard {
        .init(id: entry.id, bookID: entry.bookId, page: entry.page,
              kind: entry.skill, japanese: entry.heading,
              reading: entry.reading ?? "", vietnamese: entry.detail, explanation: "",
              exampleJapanese: "", exampleVietnamese: "",
              onReading: "", kunReading: "", relatedWord: "",
              hanViet: entry.dictionaryHanViet ?? entry.sourceHanViet,
              sourceChecked: false, translationChecked: false,
              lastApproved: nil)
    }
}

@MainActor
final class SouMatomePersonalReviewStore: ObservableObject {
    @Published private(set) var cards: [String: SouMatomePersonalCard] = [:]
    @Published var lastError: String?
    private let folder = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SouMatomePersonalLibrary", isDirectory: true)
    private var file: URL {
        folder.appendingPathComponent("verified-study-cards.json")
    }

    init() {
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode(
                [String: SouMatomePersonalCard].self, from: data) {
            cards = decoded
        }
    }

    /// A replacement PDF invalidates the human review tied to its old pages.
    /// Preserve the draft text, but never silently keep its approved status.
    func invalidateBook(_ bookID: String) throws {
        var revised = cards
        for (id, var card) in cards where card.bookID == bookID {
            card.sourceChecked = false
            card.translationChecked = false
            card.lastApproved = nil
            revised[id] = card
        }
        try FileManager.default.createDirectory(at: folder,
                                                withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(revised)
        try data.write(to: file, options: .atomic)
        cards = revised
        lastError = nil
    }

    /// Rebuilds the active study pack from the current checked content. If all
    /// approvals were revoked, removes ONLY this personal pack immediately.
    /// Editing a translation must not leave an older meaning in the quiz bank.
    func synchronizeApprovedCards(with study: StudyStore) throws -> Int {
        if approvedCount == 0 {
            try study.revokePersonalReviewedPack()
            return 0
        }
        return try installApprovedIntoStudy(study)
    }

    /// When new parser output changes an existing source candidate, its old
    /// approval must not silently attach to a different Japanese headword.
    /// Preserve the user's corrected content as a draft for comparison.
    func invalidateCandidateIDs(_ ids: Set<String>) throws {
        guard !ids.isEmpty else { return }
        var revised = cards
        for id in ids {
            guard var card = revised[id] else { continue }
            card.sourceChecked = false
            card.translationChecked = false
            card.lastApproved = nil
            revised[id] = card
        }
        try FileManager.default.createDirectory(at: folder,
                                                withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(revised)
        try data.write(to: file, options: .atomic)
        cards = revised
        lastError = nil
    }

    func card(for candidate: SouMatomeSourceEntry) -> SouMatomePersonalCard {
        cards[candidate.id] ?? .draft(candidate)
    }

    var approvedCount: Int { cards.values.filter(\.isApproved).count }
    var draftCount: Int { cards.count - approvedCount }

    @discardableResult
    func save(_ card: SouMatomePersonalCard) -> Bool {
        do {
            var revised = cards
            revised[card.id] = card
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(revised)
            try data.write(to: file, options: .atomic)
            cards = revised
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// The resulting pack contains ONLY individually source- and translation-
    /// checked cards. Never publish unreviewed OCR/text-layer candidates.
    func installApprovedIntoStudy(_ study: StudyStore) throws -> Int {
        let approved = cards.values.filter(\.isApproved)
            .sorted { $0.id < $1.id }
        guard !approved.isEmpty else {
            throw SouMatomeReviewError.noApprovedCards
        }
        var vocabulary: [[String: Any]] = []
        var grammar: [[String: Any]] = []
        var kanji: [[String: Any]] = []

        for card in approved {
            let provenance = "private-book:\(card.bookID):page-\(card.page)"
            let id = "sm-reviewed-" + card.id
                .replacingOccurrences(of: ":", with: "-")
            switch card.kind {
            case "Từ vựng":
                let exampleOK = !card.exampleJapanese.isEmpty &&
                                !card.exampleVietnamese.isEmpty
                vocabulary.append([
                    "id": id, "word": card.japanese,
                    "reading": card.reading, "meaning": card.vietnamese,
                    "topic": provenance, "week": 1,
                    "example": exampleOK ? card.exampleJapanese : "",
                    "exampleVi": exampleOK ? card.exampleVietnamese : "",
                    "meaningStatus": "editorial_reviewed",
                    "meaningSource": provenance,
                    "exampleStatus": exampleOK ? "editorial_reviewed" : "pending"
                ])
            case "Ngữ pháp":
                let exampleOK = !card.exampleJapanese.isEmpty &&
                                !card.exampleVietnamese.isEmpty
                grammar.append([
                    "id": id, "pattern": card.japanese,
                    "meaning": card.vietnamese, "rule": card.explanation,
                    "example": exampleOK ? card.exampleJapanese : "",
                    "translation": exampleOK ? card.exampleVietnamese : "",
                    "week": 1, "grammarStatus": "editorial_reviewed",
                    "translationStatus": exampleOK ? "editorial_reviewed" : "pending"
                ])
            case "Kanji":
                kanji.append([
                    "id": id, "char": card.japanese,
                    "on": card.onReading, "kun": card.kunReading,
                    "meaning": card.vietnamese, "word": card.relatedWord,
                    "hanViet": card.hanViet ?? "",
                    "meaningStatus": "editorial_reviewed"
                ])
            default: break
            }
        }

        let newVersion = (study.installedPacks.first {
            $0.id == "sou-matome-personal-reviewed"
        }?.version ?? 0) + 1

        let pack: [String: Any] = [
            "id": "sou-matome-personal-reviewed",
            "seriesId": "sou-matome",
            "version": newVersion,
            "title": "Sou Matome – các mục đã đối chiếu trên thiết bị",
            "vocab": vocabulary, "grammar": grammar, "kanji": kanji,
            "readings": [[String: Any]](), "listening": [[String: Any]]()
        ]
        let data = try JSONSerialization.data(
            withJSONObject: pack, options: [.sortedKeys])
        try study.importContentPack(data)
        return vocabulary.count + grammar.count + kanji.count
    }
}

enum SouMatomeReviewError: LocalizedError {
    case noApprovedCards
    case invalidCandidateFile
    var errorDescription: String? {
        switch self {
        case .noApprovedCards:
            return "Chưa có mục nào đã được đối chiếu cả chữ Nhật và nghĩa Việt."
        case .invalidCandidateFile:
            return "Tệp ứng viên không hợp lệ, bị trùng ID, quá lớn hoặc thiếu liên kết đến trang sách."
        }
    }
}

struct SouMatomePersonalCardEditor: View {
    @EnvironmentObject private var study: StudyStore
    @ObservedObject var reviews: SouMatomePersonalReviewStore
    @State private var candidate: SouMatomeSourceEntry
    let reviewQueue: [SouMatomeSourceEntry]

    @State private var card: SouMatomePersonalCard
    @State private var message: String?
    @State private var sourceConfirmed = false
    @State private var translationConfirmed = false

    init(candidate: SouMatomeSourceEntry,
         reviews: SouMatomePersonalReviewStore,
         reviewQueue: [SouMatomeSourceEntry] = []) {
        self.reviews = reviews
        self.reviewQueue = reviewQueue.isEmpty ? [candidate] : reviewQueue
        _candidate = State(initialValue: candidate)
        _card = State(initialValue: reviews.card(for: candidate))
    }

    private var nextUncheckedCandidate: SouMatomeSourceEntry? {
        guard let index = reviewQueue.firstIndex(where: { $0.id == candidate.id })
        else { return nil }
        return reviewQueue.dropFirst(index + 1).first {
            $0.skill == candidate.skill &&
            reviews.cards[$0.id]?.isApproved != true
        }
    }

    private var reviewPosition: Int {
        reviewQueue.filter { $0.skill == candidate.skill }
            .firstIndex(where: { $0.id == candidate.id })
            .map { $0 + 1 } ?? 1
    }
    private var reviewTotal: Int {
        reviewQueue.filter { $0.skill == candidate.skill }.count
    }

    private func moveToNextUnchecked() {
        guard let next = nextUncheckedCandidate else { return }
        candidate = next
        card = reviews.card(for: next)
        sourceConfirmed = card.sourceChecked
        translationConfirmed = card.translationChecked
        message = nil
    }

    var body: some View {
        Form {
            Section("Nguồn cần kiểm tra") {
                Text("Sách: \(candidate.bookId) · Trang \(candidate.page)")
                Text("Loại: \(candidate.skill) · Mục \(reviewPosition)/\(reviewTotal)")
                Text("Đối chiếu trực tiếp với PDF gốc, không tin tuyệt đối vào văn bản tách tự động.")
                    .font(.caption).foregroundColor(.secondary)
                if let book = SouMatomeDocument.all.first(where: { $0.id == candidate.bookId }),
                   let url = SouMatomeLibraryStore().fileURL(for: book) {
                    NavigationLink {
                        SouMatomePDFReader(book: book, url: url, initialPage: candidate.page)
                    } label: {
                        Label("Mở trang \(candidate.page) trong PDF gốc",
                              systemImage: "book.closed.fill")
                    }
                }
                if !card.sourcePDFIsAvailable {
                    Label("Chưa có PDF gốc trên iPhone. Chỉ được lưu nháp, không thể chứng nhận nghĩa Nhật–Việt.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundColor(Palette.orange)
                }
                if let flags = candidate.qaFlags, !flags.isEmpty {
                    Text("Mục này cần rà soát thêm: " + flags.joined(separator: ", "))
                        .font(.caption).foregroundColor(Palette.orange)
                }
                if candidate.skill == "Kanji" {
                    if let han = candidate.sourceHanViet, !han.isEmpty {
                        Text("Hán–Việt ghi trong PDF: " + han)
                            .font(.caption).foregroundColor(Palette.blue)
                    }
                    if let reads = candidate.sourceOnKun, !reads.isEmpty {
                        Text("Dòng cách đọc trong PDF: " + reads)
                            .font(.caption).foregroundColor(Palette.blue)
                    }
                    if let corrected = candidate.dictionaryHanViet,
                       !corrected.isEmpty {
                        Text("Từ điển độc lập gợi ý Hán–Việt: " + corrected)
                            .font(.caption).foregroundColor(Palette.orange)
                    }
                    Text("Hán–Việt là âm đọc. Hãy kiểm tra nghĩa tiếng Việt theo ngữ cảnh và phân loại cách đọc On/Kun trước khi xác nhận.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Section("Chữ Nhật và nghĩa tiếng Việt") {
                TextField("Từ / mẫu câu / chữ Kanji", text: $card.japanese,
                          axis: .vertical)
                TextField("Cách đọc bằng hiragana (nếu là từ vựng)",
                          text: $card.reading, axis: .vertical)
                TextField("Nghĩa tiếng Việt chính xác", text: $card.vietnamese,
                          axis: .vertical)
            }
            if card.kind == "Ngữ pháp" {
                Section("Cách dùng") {
                    TextField("Cấu trúc và lưu ý", text: $card.explanation,
                              axis: .vertical)
                }
            }
            if card.kind == "Kanji" {
                Section("Cách đọc Kanji") {
                    TextField("Âm Hán–Việt", text: Binding(
                        get: { card.hanViet ?? "" },
                        set: { card.hanViet = $0 }
                    ))
                    TextField("Âm On", text: $card.onReading)
                    TextField("Âm Kun", text: $card.kunReading)
                    TextField("Từ ghép đã kiểm tra", text: $card.relatedWord)
                }
            }
            if card.kind != "Kanji" {
                Section("Ví dụ tự biên soạn và bản dịch (tùy chọn)") {
                    TextField("Ví dụ tiếng Nhật", text: $card.exampleJapanese,
                              axis: .vertical)
                    TextField("Dịch nghĩa Việt", text: $card.exampleVietnamese,
                              axis: .vertical)
                    Text("Ví dụ chỉ được đưa vào bài học khi có cả hai ngôn ngữ.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Section("Đối chiếu trước khi phê duyệt") {
                Toggle("Đã so chữ Nhật và cách đọc với PDF gốc",
                       isOn: $sourceConfirmed)
                Toggle("Đã so nghĩa và cách dùng tiếng Việt",
                       isOn: $translationConfirmed)
                Text("Chỉ các thẻ được xác nhận cả hai bước mới xuất hiện trong bộ flashcard và trắc nghiệm chính thức.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section {
                Button("Lưu bản nháp") { _ = save(approve: false) }
                Button("Xác nhận đã kiểm tra và lưu") {
                    _ = save(approve: true)
                }
                .disabled(!card.sourcePDFIsAvailable ||
                    !sourceConfirmed || !translationConfirmed ||
                    !card.isAppropriateForReview)
                if nextUncheckedCandidate != nil {
                    Button("Lưu nháp và sang mục chưa duyệt tiếp theo") {
                        if save(approve: false) { moveToNextUnchecked() }
                    }
                    Button("Xác nhận và sang mục chưa duyệt tiếp theo") {
                        if save(approve: true) { moveToNextUnchecked() }
                    }
                    .disabled(!card.sourcePDFIsAvailable || !sourceConfirmed ||
                        !translationConfirmed || !card.isAppropriateForReview)
                    Button("Sang mục chưa duyệt (không thay đổi thẻ đã lưu)") {
                        guard card == reviews.card(for: candidate) else {
                            message = "Bạn có thay đổi chưa lưu. Hãy lưu nháp trước khi chuyển."
                            return
                        }
                        moveToNextUnchecked()
                    }
                }
                if let message { Text(message).font(.footnote) }
                if let error = reviews.lastError {
                    Text(error).font(.footnote).foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Kiểm chứng mục học")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            card = reviews.card(for: candidate)
            sourceConfirmed = card.sourceChecked
            translationConfirmed = card.translationChecked
        }
        .onChange(of: card.japanese) { _ in
            sourceConfirmed = false
        }
        .onChange(of: card.reading) { _ in
            sourceConfirmed = false
        }
        .onChange(of: card.vietnamese) { _ in
            translationConfirmed = false
        }
        .onChange(of: card.explanation) { _ in
            translationConfirmed = false
        }
        .onChange(of: card.exampleJapanese) { _ in
            sourceConfirmed = false
        }
        .onChange(of: card.exampleVietnamese) { _ in
            translationConfirmed = false
        }
        .onChange(of: card.hanViet) { _ in
            sourceConfirmed = false
        }
        .onChange(of: card.onReading) { _ in
            sourceConfirmed = false
        }
        .onChange(of: card.kunReading) { _ in
            sourceConfirmed = false
        }
        .onChange(of: card.relatedWord) { _ in
            sourceConfirmed = false
        }
    }

    @discardableResult
    private func save(approve: Bool) -> Bool {
        guard !approve || (sourceConfirmed && translationConfirmed &&
                           card.sourcePDFIsAvailable &&
                           card.isAppropriateForReview) else {
            message = "Chưa đủ điều kiện xác minh nguồn, chữ Nhật hoặc nghĩa Việt."
            return false
        }
        card.sourceChecked = approve && sourceConfirmed
        card.translationChecked = approve && translationConfirmed
        card.lastApproved = approve ? Date() : nil
        guard reviews.save(card) else {
            message = "Không lưu được bản hiệu đính."
            return false
        }
        do {
            let installed = try reviews.synchronizeApprovedCards(with: study)
            message = approve
                ? "Đã lưu và cập nhật \(installed) mục được kiểm chứng vào bài học."
                : "Đã lưu bản nháp; đã thu hồi bản học cũ nếu mục này không còn được duyệt."
            return true
        } catch {
            message = "Đã lưu bản nháp, nhưng cập nhật gói học thất bại: "
                + error.localizedDescription
            return false
        }
    }
}
