import SwiftUI
import Foundation

// All user-supplied content and review decisions stay on the owner's iPhone.
// Machine-extracted candidates NEVER enter the study/quiz pool automatically.
struct SouMatomePersonalCard: Codable, Identifiable {
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

    var isApproved: Bool {
        sourceChecked && translationChecked && lastApproved != nil &&
        hasJapaneseText &&
        !vietnamese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !vietnamese.hasPrefix("EN ·") &&
        (kind != "Từ vựng" || readingHasKana) &&
        (kind != "Kanji" || japanese.count == 1)
    }

    static func draft(_ entry: SouMatomeSourceEntry) -> SouMatomePersonalCard {
        .init(id: entry.id, bookID: entry.bookId, page: entry.page,
              kind: entry.skill, japanese: entry.heading,
              reading: entry.reading ?? "", vietnamese: entry.detail, explanation: "",
              exampleJapanese: "", exampleVietnamese: "",
              onReading: "", kunReading: "", relatedWord: "",
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
    let candidate: SouMatomeSourceEntry

    @State private var card: SouMatomePersonalCard
    @State private var message: String?
    @State private var sourceConfirmed = false
    @State private var translationConfirmed = false

    init(candidate: SouMatomeSourceEntry,
         reviews: SouMatomePersonalReviewStore) {
        self.candidate = candidate
        self.reviews = reviews
        _card = State(initialValue: reviews.card(for: candidate))
    }

    var body: some View {
        Form {
            Section("Nguồn cần kiểm tra") {
                Text("Sách: \(candidate.bookId) · Trang \(candidate.page)")
                Text("Loại: \(candidate.skill)")
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
                Button("Lưu bản nháp") { save(approve: false) }
                Button("Xác nhận đã kiểm tra và lưu") {
                    save(approve: true)
                }
                .disabled(!sourceConfirmed || !translationConfirmed ||
                    card.japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    card.vietnamese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (card.kind == "Từ vựng" && card.reading.trimmingCharacters(
                        in: .whitespacesAndNewlines).isEmpty))
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

    private func save(approve: Bool) {
        card.sourceChecked = approve && sourceConfirmed
        card.translationChecked = approve && translationConfirmed
        card.lastApproved = approve ? Date() : nil
        guard reviews.save(card) else {
            message = "Không lưu được bản hiệu đính."
            return
        }
        do {
            let installed = try reviews.synchronizeApprovedCards(with: study)
            message = approve
                ? "Đã lưu và cập nhật \(installed) mục được kiểm chứng vào bài học."
                : "Đã lưu bản nháp; đã thu hồi bản học cũ nếu mục này không còn được duyệt."
        } catch {
            message = "Đã lưu bản nháp, nhưng cập nhật gói học thất bại: "
                + error.localizedDescription
        }
    }
}
