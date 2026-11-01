import SwiftUI
import PDFKit

/// Search the user's locally imported textbook PDFs and OCR transcripts.
/// No textbook bytes or extracted passages are committed to the repository.
struct SouMatomeSourceSearchHit: Identifiable {
    let bookID: String
    let bookName: String
    let page: Int
    let preview: String
    var id: String { bookID + ":" + String(page) }
}

struct SouMatomeWholeBooksView: View {
    @EnvironmentObject private var study: StudyStore
    @StateObject private var library = SouMatomeLibraryStore()
    @State private var searchText = ""
    @State private var results: [SouMatomeSourceSearchHit] = []
    @State private var searching = false
    @State private var searched = false
    @State private var displayLimit = 150

    private var importedBooks: [SouMatomeDocument] {
        SouMatomeDocument.all.filter { library.fileURL(for: $0) != nil }
    }
    private var importedPages: Int {
        importedBooks.reduce(0) { $0 + $1.pages }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Toàn bộ giáo trình Sou Matome N2",
                             subtitle: "Học trực tiếp theo sách và kỹ năng – không chia tuần")
                LessonPanel {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(importedBooks.count)/8 sách đã nhập")
                                .font(.headline).foregroundColor(Palette.navy)
                            Text("\(importedPages)/1.239 trang có thể mở từ thư viện cá nhân")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "books.vertical.fill")
                            .font(.title2).foregroundColor(Palette.blue)
                    }
                    NavigationLink {
                        SouMatomeLibraryView()
                    } label: {
                        ActionTile(icon: "square.and.arrow.down.on.square", color: Palette.teal,
                                   title: "Nhập sách PDF và 116 MP3",
                                   detail: "Nhập một lần để đọc toàn bộ ngoại tuyến")
                    }.buttonStyle(.plain)
                    Text("Số trang đã nhập là số trang nguồn, không phải số mục flashcard đã hiệu đính. Các file sách và CD chỉ lưu trên iPhone của bạn.")
                        .font(.caption).foregroundColor(.secondary)
                }

                LessonPanel {
                    SectionTitle("Tình trạng kho học liệu đã dùng được",
                                 subtitle: "Đếm bài học thực trong ứng dụng, không đếm trang sách là flashcard")
                    if study.selectedSeries == .souMatome {
                        Text("Từ vựng: \(study.course.vocab.count) · Kanji: \(study.course.kanji.count) · Ngữ pháp: \(study.course.grammar.count)")
                            .font(.subheadline).foregroundColor(Palette.navy)
                        Text("Đọc hiểu: \(study.course.readings.count) câu · Nghe hiểu: \(study.course.listening.count) câu")
                            .font(.subheadline).foregroundColor(Palette.navy)
                    } else {
                        Text("Chọn bộ Sou Matome để xem số lượng bài tương tác của bộ này.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    Text("PDF đã nhập: \(importedBooks.count)/8 · MP3 đã nhập: \(library.tracks.count)/116. Chỉ số nhập tệp không bảo đảm bản dịch và đáp án đã đối chiếu.")
                        .font(.caption).foregroundColor(.secondary)
                    Text("Chưa có xác nhận hoàn thiện 100% từng mục của toàn bộ sách.")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Palette.orange)
                }

                NavigationLink {
                    SouMatomeSourceEntriesView()
                } label: {
                    ActionTile(icon: "text.book.closed.fill", color: Palette.teal,
                               title: "Tìm từng mục từ sách gốc",
                               detail: "Đọc toàn bộ trang có chữ, tách từ vựng – Kanji – ngữ pháp để đối chiếu")
                }.buttonStyle(.plain)

                NavigationLink {
                    SouMatomePrivateQuestionListView()
                } label: {
                    ActionTile(icon: "checklist", color: Palette.blue,
                               title: "Hiệu đính câu hỏi đọc và nghe",
                               detail: "Bốn đáp án, lời giải Nhật–Việt, đối chiếu đúng trang nguồn")
                }.buttonStyle(.plain)

                bookGroup(title: "Từ vựng · 語彙", ids: ["goi", "goi-vi"])
                bookGroup(title: "Kanji · 漢字", ids: ["kanji", "kanji-vi"])
                bookGroup(title: "Ngữ pháp · 文法", ids: ["bunpou", "bunpou-vi"])
                bookGroup(title: "Đọc hiểu · 読解", ids: ["dokkai"])
                bookGroup(title: "Nghe hiểu · 聴解", ids: ["choukai"])

                LessonPanel {
                    SectionTitle("Tìm trên toàn bộ sách",
                                 subtitle: "Tìm theo từ Nhật, nghĩa tiếng Việt hoặc câu đã hiệu đính")
                    TextField("Nhập ít nhất 2 ký tự", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    MainButton(title: searching ? "Đang kiểm tra các trang…" : "Tìm kiếm toàn bộ sách",
                               symbol: "magnifyingglass") {
                        startSearch()
                    }.disabled(searching || searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                    if searched {
                        Text("\(results.count) trang có từ khóa trong dữ liệu đã đọc được.")
                            .font(.caption.weight(.semibold)).foregroundColor(Palette.blue)
                        Text("Các PDF ảnh quét chỉ tìm được sau khi nhận dạng chữ; một trang chưa tìm thấy không có nghĩa là sách bị thiếu nội dung.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(results.prefix(displayLimit)) { match in
                        if let book = SouMatomeDocument.all.first(where: { $0.id == match.bookID }),
                           let url = library.fileURL(for: book) {
                            NavigationLink {
                                SouMatomePDFReader(book: book, url: url, initialPage: match.page)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(match.bookName) · Trang \(match.page)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(Palette.blue)
                                    Text(match.preview)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if results.count > displayLimit {
                        Button("Xem thêm trang (\(min(displayLimit, results.count))/\(results.count))") {
                            displayLimit += 150
                        }.buttonStyle(.bordered)
                    }
                }
            }
            .padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Toàn bộ sách Sou Matome")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { library.refresh() }
    }

    private func bookGroup(title: String, ids: [String]) -> some View {
        LessonPanel {
            SectionTitle(title)
            ForEach(ids, id: \.self) { id in
                if let book = SouMatomeDocument.all.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(book.title)
                            .font(.subheadline.weight(.semibold)).foregroundColor(Palette.navy)
                        HStack {
                            Text("\(book.pages) trang")
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            if let url = library.fileURL(for: book) {
                                NavigationLink {
                                    SouMatomePDFReader(book: book, url: url, initialPage: 1)
                                } label: {
                                    Label("Xem toàn bộ", systemImage: "book.pages")
                                }.buttonStyle(.borderedProminent)

                                NavigationLink {
                                    SouMatomePageWorkbenchView(book: book, url: url, initialPage: 1)
                                } label: {
                                    Label("Chữ Nhật", systemImage: "text.viewfinder")
                                }.buttonStyle(.bordered)
                            } else {
                                Text("Chưa nhập PDF").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }.padding(.vertical, 5)
                    Divider()
                }
            }
            if ids.contains("choukai") {
                NavigationLink {
                    SouMatomeLibraryView()
                } label: {
                    ActionTile(icon: "headphones", color: Palette.blue,
                               title: "Toàn bộ 116 track nghe",
                               detail: "CD1: 64 · CD2: 52 · Phát và tua offline")
                }.buttonStyle(.plain)
            }
        }
    }

    private func startSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, !searching else { return }
        let books = importedBooks.compactMap { book -> (String, String, Int, URL)? in
            guard let url = library.fileURL(for: book) else { return nil }
            return (book.id, book.title, book.pages, url)
        }
        searching = true
        searched = false
        results = []
        displayLimit = 150
        Task {
            let matches = await Task.detached(priority: .userInitiated) {
                () -> [SouMatomeSourceSearchHit] in
                var found: [SouMatomeSourceSearchHit] = []
                let appSupport = FileManager.default.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask)[0]
                for (bookID, bookName, pageCount, url) in books {
                    guard let pdf = PDFDocument(url: url) else { continue }
                    let transcriptFolder = appSupport
                        .appendingPathComponent("SouMatomePersonalLibrary/PageText", isDirectory: true)
                        .appendingPathComponent(bookID, isDirectory: true)
                    for pageNumber in 1...min(pageCount, pdf.pageCount) {
                        let file = transcriptFolder.appendingPathComponent(
                            String(format: "page-%04d.txt", pageNumber))
                        let words = (try? String(contentsOf: file, encoding: .utf8))
                            ?? pdf.page(at: pageNumber - 1)?.string ?? ""
                        guard let range = words.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
                            continue
                        }
                        let start = words.index(range.lowerBound, offsetBy: -70, limitedBy: words.startIndex)
                            ?? words.startIndex
                        let end = words.index(range.upperBound, offsetBy: 110, limitedBy: words.endIndex)
                            ?? words.endIndex
                        let preview = String(words[start..<end]).replacingOccurrences(of: "\n", with: " ")
                        found.append(.init(bookID: bookID, bookName: bookName,
                                           page: pageNumber, preview: preview))
                    }
                }
                return found
            }.value
            results = matches
            searching = false
            searched = true
        }
    }
}
