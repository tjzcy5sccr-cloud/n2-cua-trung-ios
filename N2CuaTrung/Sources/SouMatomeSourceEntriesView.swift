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

    init(id: String, bookId: String, page: Int, heading: String,
         detail: String, skill: String, reading: String? = nil) {
        self.id = id
        self.bookId = bookId
        self.page = page
        self.heading = heading
        self.detail = detail
        self.skill = skill
        self.reading = reading
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

@MainActor
final class SouMatomeSourceEntryStore: ObservableObject {
    @Published var entries: [SouMatomeSourceEntry] = []
    @Published var processing = false
    @Published var loadedBooks = 0
    @Published var notes: String?
    @Published var importedCandidateCount = 0
    private let root = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        .appendingPathComponent("SouMatomePersonalLibrary", isDirectory: true)

    private var importedURL: URL {
        root.appendingPathComponent("private-draft-candidates.json")
    }

    private func loadImportedCandidates() -> [SouMatomeSourceEntry] {
        guard let data = try? Data(contentsOf: importedURL),
              let decoded = try? JSONDecoder().decode(
                [SouMatomeSourceEntry].self, from: data) else { return [] }
        return decoded
    }

    @discardableResult
    func importCandidates(from url: URL) throws -> Int {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let bytes = try Data(contentsOf: url)
        guard bytes.count > 0, bytes.count <= 8 * 1_024 * 1_024 else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        let imported = try JSONDecoder().decode(
            [SouMatomeSourceEntry].self, from: bytes)
        guard !imported.isEmpty, imported.count <= 15_000,
              Set(imported.map(\.id)).count == imported.count else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        let validBooks = Dictionary(uniqueKeysWithValues:
            SouMatomeDocument.all.map { ($0.id, $0.pages) })
        for card in imported {
            guard let maxPage = validBooks[card.bookId],
                  (1...maxPage).contains(card.page),
                  ["Từ vựng", "Kanji", "Ngữ pháp"].contains(card.skill),
                  card.id.hasPrefix(card.bookId + ":" + String(card.page) + ":"),
                  card.heading.count <= 250, card.detail.count <= 250
            else { throw SouMatomeReviewError.invalidCandidateFile }
        }
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
        try bytes.write(to: importedURL, options: .atomic)
        importedCandidateCount = imported.count
        var keyed = Dictionary(uniqueKeysWithValues:
            entries.map { ($0.id, $0) })
        for card in imported { keyed[card.id] = card }
        entries = keyed.values.sorted { $0.id < $1.id }
        return imported.count
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
        notes = "Đã nhận diện \(entries.count) ứng viên từ PDF, gồm \(imported.count) bản ghi nhập riêng. Chưa được kiểm duyệt."
        processing = false
    }
}

struct SouMatomeSourceEntriesView: View {
    @StateObject private var source = SouMatomeSourceEntryStore()
    @StateObject private var library = SouMatomeLibraryStore()
    @State private var query = ""
    @State private var skill = "Tất cả"
    @State private var displayLimit = 200
    @State private var revealedIDs: Set<String> = []
    @StateObject private var reviews = SouMatomePersonalReviewStore()
    @EnvironmentObject private var studyStore: StudyStore
    @State private var installMessage: String?
    @State private var pickCandidateJSON = false
    @State private var importMessage: String?
    private let skills = ["Tất cả", "Từ vựng", "Kanji", "Ngữ pháp"]

    private var matching: [SouMatomeSourceEntry] {
        source.entries.filter { item in
            (skill == "Tất cả" || skill == item.skill) &&
            (query.isEmpty || (item.heading + " " + item.detail)
                .localizedCaseInsensitiveContains(query))
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
                    if source.importedCandidateCount > 0 {
                        Text("Đã nhận \(source.importedCandidateCount) ứng viên từ tệp JSON cá nhân.")
                            .font(.caption).foregroundColor(Palette.teal)
                    }
                    if let importMessage {
                        Text(importMessage).font(.caption).foregroundColor(Palette.navy)
                    }
                }
                LessonPanel {
                    SectionTitle("Kho flashcard đã kiểm chứng")
                    Text("\(reviews.approvedCount) thẻ đã xác minh · \(reviews.draftCount) bản nháp")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.navy)
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
                                    Text("\(entry.skill) · Trang \(entry.page) · "
                                         + (reviews.cards[entry.id]?.isApproved == true
                                            ? "Đã kiểm chứng" : "Chưa kiểm chứng"))
                                        .font(.caption)
                                        .foregroundColor(reviews.cards[entry.id]?.isApproved == true
                                                         ? Palette.teal : .secondary)
                                    NavigationLink {
                                        SouMatomePersonalCardEditor(candidate: entry,
                                                                     reviews: reviews)
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
        .fileImporter(isPresented: $pickCandidateJSON,
                      allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                Task {
                    do {
                        let count = try source.importCandidates(from: url)
                        importMessage = "Đã nhập \(count) ứng viên. Cần đối chiếu trước khi cho vào bài luyện."
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
