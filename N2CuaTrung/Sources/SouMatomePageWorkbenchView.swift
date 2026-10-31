import SwiftUI
import PDFKit
import Vision

/// Private page-by-page transcription workbench. The PDF, extracted text,
/// corrections and verification markers never leave Application Support.
@MainActor
final class SouMatomePageEditor: ObservableObject {
    let book: SouMatomeDocument
    let source: URL

    @Published var page: Int = 1
    @Published var text: String = ""
    @Published var isWorking = false
    @Published var status: String?
    @Published var verified = false
    @Published var verifiedPageCount = 0
    @Published var query = ""
    @Published var matchingPages: [Int] = []

    private let root: URL

    init(book: SouMatomeDocument, source: URL) {
        self.book = book
        self.source = source
        self.root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SouMatomePersonalLibrary/PageText", isDirectory: true)
            .appendingPathComponent(book.id, isDirectory: true)
        self.page = min(book.pages, max(1,
            UserDefaults.standard.integer(forKey: "SouMatome.editorPage." + book.id)))
        load()
    }

    private func textFile(_ number: Int) -> URL {
        root.appendingPathComponent(String(format: "page-%04d.txt", number))
    }

    private func reviewKey(_ number: Int) -> String {
        "SouMatome.verified." + book.id + "." + String(number)
    }

    func load() {
        if let bytes = try? String(contentsOf: textFile(page), encoding: .utf8) {
            text = bytes
        } else if let pdf = PDFDocument(url: source),
                  let pdfPage = pdf.page(at: page - 1),
                  let selectable = pdfPage.string, !selectable.isEmpty {
            text = selectable
        } else {
            text = ""
        }
        verified = UserDefaults.standard.bool(forKey: reviewKey(page))
        verifiedPageCount = (1...book.pages).filter {
            UserDefaults.standard.bool(forKey: reviewKey($0))
        }.count
        UserDefaults.standard.set(page, forKey: "SouMatome.editorPage." + book.id)
        status = nil
    }

    func move(to destination: Int) {
        let next = max(1, min(book.pages, destination))
        if next != page {
            page = next
            load()
        }
    }

    func saveEdits() {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try text.write(to: textFile(page), atomically: true, encoding: .utf8)
            // Editing invalidates prior verification until the user re-checks it.
            verified = false
            UserDefaults.standard.set(false, forKey: reviewKey(page))
            verifiedPageCount = (1...book.pages).filter {
                UserDefaults.standard.bool(forKey: reviewKey($0))
            }.count
            status = "Đã lưu bản hiệu đính trên iPhone, cần đối chiếu với trang sách."
        } catch {
            status = "Không lưu được: " + error.localizedDescription
        }
    }

    func markVerified() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "Trang chưa có văn bản để đối chiếu."
            return
        }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try text.write(to: textFile(page), atomically: true, encoding: .utf8)
            UserDefaults.standard.set(true, forKey: reviewKey(page))
            verified = true
            verifiedPageCount = (1...book.pages).filter {
                UserDefaults.standard.bool(forKey: reviewKey($0))
            }.count
            status = "Đã đánh dấu trang này được đối chiếu thủ công."
        } catch {
            status = "Không lưu được: " + error.localizedDescription
        }
    }

    func nextUnverified() {
        if let next = (page...book.pages).first(where: {
            !UserDefaults.standard.bool(forKey: reviewKey($0))
        }) {
            move(to: next)
        } else if let first = (1..<page).first(where: {
            !UserDefaults.standard.bool(forKey: reviewKey($0))
        }) {
            move(to: first)
        } else {
            status = "Tất cả trang đã được đánh dấu đối chiếu."
        }
    }

    func searchPages() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else {
            matchingPages = []
            status = "Nhập ít nhất 2 ký tự để tìm."
            return
        }
        guard let document = PDFDocument(url: source) else {
            status = "Không mở được tài liệu."
            return
        }
        var hits: [Int] = []
        for n in 1...book.pages {
            let text = (try? String(contentsOf: textFile(n), encoding: .utf8))
                ?? document.page(at: n - 1)?.string ?? ""
            if text.localizedCaseInsensitiveContains(term) {
                hits.append(n)
            }
        }
        matchingPages = hits
        status = "Tìm thấy trên \(hits.count) trang (chỉ các trang có văn bản)."
    }

    /// Do not claim OCR equals correct transcription. Japanese layout, furigana,
    /// vertical writing, tables and choice numbers always need manual checking.
    func recognizeCurrentPage() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let targetPage = page
        guard let pdf = PDFDocument(url: source),
              let pdfPage = pdf.page(at: targetPage - 1) else {
            status = "Không thể mở trang PDF."
            return
        }
        if let selectable = pdfPage.string,
           selectable.trimmingCharacters(in: .whitespacesAndNewlines).count > 40 {
            text = selectable
            status = "Đã lấy văn bản sẵn có từ PDF. Hãy so với trang gốc."
            return
        }
        let image = pdfPage.thumbnail(
            of: CGSize(width: 1800, height: 2500), for: .mediaBox)
        guard let cgImage = image.cgImage else {
            status = "Không thể tạo ảnh trang để nhận dạng."
            return
        }
        do {
            let extracted = try await Task.detached(priority: .userInitiated) {
                () throws -> String in
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["ja-JP"]
                try VNImageRequestHandler(cgImage: cgImage, options: [:])
                    .perform([request])
                let results = (request.results ?? []).sorted {
                    $0.boundingBox.midY > $1.boundingBox.midY
                }
                return results.compactMap {
                    $0.topCandidates(1).first?.string
                }.joined(separator: "\n")
            }.value
            guard targetPage == page else { return }
            text = extracted
            verified = false
            UserDefaults.standard.set(false, forKey: reviewKey(page))
            status = extracted.isEmpty
                ? "Chưa nhận dạng được chữ trên trang này."
                : "Đã nhận dạng tạm thời. Cần kiểm tra từng chữ, furigana và thứ tự câu."
        } catch {
            status = "Không nhận dạng được: " + error.localizedDescription
        }
    }
}

struct SouMatomePageWorkbenchView: View {
    @StateObject private var editor: SouMatomePageEditor

    init(book: SouMatomeDocument, url: URL) {
        _editor = StateObject(wrappedValue: SouMatomePageEditor(book: book, source: url))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LessonPanel {
                    SectionTitle("Kiểm kê và hiệu đính theo từng trang",
                                 subtitle: editor.book.title)
                    ProgressView(value: Double(editor.verifiedPageCount),
                                 total: Double(editor.book.pages))
                    Text("Đã đối chiếu: \(editor.verifiedPageCount)/\(editor.book.pages) trang")
                        .font(.caption).foregroundColor(.secondary)
                    HStack {
                        Button { editor.move(to: editor.page - 1) } label: {
                            Image(systemName: "chevron.left.circle.fill")
                        }.disabled(editor.page <= 1)
                        Spacer()
                        Text("Trang \(editor.page) / \(editor.book.pages)")
                            .font(.subheadline.monospacedDigit())
                        Spacer()
                        Button { editor.move(to: editor.page + 1) } label: {
                            Image(systemName: "chevron.right.circle.fill")
                        }.disabled(editor.page >= editor.book.pages)
                    }.font(.title2)
                    NavigationLink {
                        SouMatomePDFReader(book: editor.book, url: editor.source)
                    } label: {
                        Label("Mở sách gốc để đối chiếu", systemImage: "book.pages")
                    }
                }
                LessonPanel {
                    HStack {
                        Text("Văn bản tiếng Nhật / tiếng Việt")
                            .font(.headline).foregroundColor(Palette.navy)
                        Spacer()
                        if editor.verified {
                            Label("Đã đối chiếu", systemImage: "checkmark.seal.fill")
                                .font(.caption).foregroundColor(Palette.teal)
                        }
                    }
                    TextEditor(text: $editor.text)
                        .font(.body)
                        .frame(minHeight: 260)
                        .padding(5)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Palette.blue.opacity(0.18), lineWidth: 1))
                    MainButton(title: editor.isWorking ? "Đang nhận dạng…" : "Nhận dạng chữ Nhật trên trang",
                               symbol: "text.viewfinder") {
                        Task { await editor.recognizeCurrentPage() }
                    }.disabled(editor.isWorking)
                    MainButton(title: "Lưu văn bản đã sửa", symbol: "square.and.arrow.down",
                               color: Palette.navy) {
                        editor.saveEdits()
                    }
                    MainButton(title: "Tôi đã đối chiếu với trang gốc",
                               symbol: "checkmark.seal.fill", color: Palette.teal) {
                        editor.markVerified()
                    }
                    MainButton(title: "Đi tới trang chưa đối chiếu",
                               symbol: "arrow.right.circle", color: Palette.blue) {
                        editor.nextUnverified()
                    }
                    Text("Kết quả nhận dạng không tự động trở thành câu hỏi đã duyệt. Hãy rà soát chữ Nhật, cách đọc, bản dịch và đáp án.")
                        .font(.caption).foregroundColor(.secondary)
                }
                LessonPanel {
                    SectionTitle("Tìm nội dung trong các trang đã có chữ")
                    TextField("Nhập từ tiếng Nhật hoặc tiếng Việt", text: $editor.query)
                        .textFieldStyle(.roundedBorder)
                    MainButton(title: "Tìm trong sách này", symbol: "magnifyingglass") {
                        editor.searchPages()
                    }
                    if !editor.matchingPages.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 65))], spacing: 8) {
                            ForEach(editor.matchingPages, id: \.self) { number in
                                Button("Trang \(number)") {
                                    editor.move(to: number)
                                }.buttonStyle(.bordered)
                            }
                        }
                    }
                }
                if let status = editor.status {
                    Text(status).font(.footnote).foregroundColor(Palette.navy)
                }
            }
            .padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Hiệu đính Sou Matome")
        .navigationBarTitleDisplayMode(.inline)
    }
}
