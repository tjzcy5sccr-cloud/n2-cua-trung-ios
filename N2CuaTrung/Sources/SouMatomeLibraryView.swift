import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import AVFoundation

// Chỉ lưu sách và CD mà người học tự nhập vào iPhone; tuyệt đối không tải
// nội dung thương mại từ repository công khai của ứng dụng.
struct SouMatomeDocument: Identifiable {
    let id: String
    let title: String
    let skill: String
    let pages: Int
    let supplementary: Bool

    // Vị trí đầu mỗi tuần/chương theo mục lục in trong chính các PDF đã kiểm tra.
    // Trang của tệp PDF lệch +1 so với số trang sách in (tệp có bìa riêng).
    var sectionPages: [Int] {
        switch id {
        case "kanji", "goi": return [12, 28, 44, 60, 76, 92, 108, 124]
        case "bunpou": return [14, 30, 46, 62, 78, 94, 110, 126]
        case "dokkai": return [12, 28, 44, 60, 78, 96]
        case "choukai": return [12, 24, 40, 52, 64]
        // Mốc tuần ở bản Việt được xác minh trực tiếp từ 556 trang có text layer.
        case "kanji-vi": return [1, 24, 51, 79, 106, 132, 160, 185]
        case "goi-vi": return [1, 16, 31, 49, 76, 95, 117, 140]
        case "bunpou-vi": return [1, 27, 53, 77, 100, 121, 144, 165]
        default: return []
        }
    }

    var sectionLabel: String { id == "choukai" ? "Chương" : "Tuần" }

    static let all: [SouMatomeDocument] = [
        .init(id: "kanji", title: "Kanji – 漢字", skill: "Kanji", pages: 177, supplementary: false),
        .init(id: "goi", title: "Từ vựng – 語彙", skill: "Từ vựng", pages: 156, supplementary: false),
        .init(id: "bunpou", title: "Ngữ pháp – 文法", skill: "Ngữ pháp", pages: 156, supplementary: false),
        .init(id: "dokkai", title: "Đọc hiểu – 読解", skill: "Đọc hiểu", pages: 121, supplementary: false),
        .init(id: "choukai", title: "Nghe hiểu – 聴解", skill: "Nghe hiểu", pages: 73, supplementary: false),
        .init(id: "kanji-vi", title: "Kanji – tài liệu tiếng Việt", skill: "Kanji", pages: 208, supplementary: true),
        .init(id: "goi-vi", title: "Từ vựng – tài liệu bổ trợ", skill: "Từ vựng", pages: 163, supplementary: true),
        .init(id: "bunpou-vi", title: "Ngữ pháp – tài liệu tiếng Việt", skill: "Ngữ pháp", pages: 185, supplementary: true)
    ]
}

struct SouMatomeTrack: Identifiable {
    let url: URL
    let cd: String
    var id: String { url.path }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

enum SouMatomeImportError: LocalizedError {
    case invalidPDF(Int, Int)
    case invalidSource
    case noAudio

    var errorDescription: String? {
        switch self {
        case .invalidPDF(let expected, let actual):
            return "Số trang không khớp bản đã kiểm tra: cần \(expected), nhận \(actual). Hãy chọn đúng tệp."
        case .invalidSource:
            return "Tệp không đúng định dạng PDF hoặc thư mục CD."
        case .noAudio:
            return "Không tìm thấy MP3 trong thư mục đã chọn. Hãy giải nén RAR trước."
        }
    }
}

@MainActor
final class SouMatomeLibraryStore: ObservableObject {
    @Published private(set) var pagesImported: [String: Int] = [:]
    @Published private(set) var tracks: [SouMatomeTrack] = []

    private let root = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        .appendingPathComponent("SouMatomePersonalLibrary", isDirectory: true)

    init() { refresh() }

    /// Nhận diện cả 8 tệp theo tên, tránh nhầm hai sách cùng có 156 trang.
    static func identifyBook(named filename: String) -> SouMatomeDocument? {
        let name = filename.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                    locale: Locale(identifier: "vi_VN")).lowercased()
        let isSupplement = name.contains("ban tieng viet") ||
                           name.contains("tieng viet") ||
                           name.contains("file tu vung")
        let skill: String
        if name.contains("kanji") { skill = "kanji" }
        else if name.contains("bunpou") { skill = "bunpou" }
        else if name.contains("dokkai") { skill = "dokkai" }
        else if name.contains("choukai") { skill = "choukai" }
        else if name.contains("goi") { skill = "goi" }
        else { return nil }
        let id = isSupplement ? skill + "-vi" : skill
        return SouMatomeDocument.all.first { $0.id == id }
    }

    func fileURL(for book: SouMatomeDocument) -> URL? {
        let url = root.appendingPathComponent(book.id + ".pdf")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func refresh() {
        var found: [String: Int] = [:]
        for book in SouMatomeDocument.all {
            if let url = fileURL(for: book), let pdf = PDFDocument(url: url) {
                found[book.id] = pdf.pageCount
            }
        }
        pagesImported = found
        var all: [SouMatomeTrack] = []
        for cd in ["CD1", "CD2"] {
            let folder = root.appendingPathComponent("Audio/" + cd, isDirectory: true)
            let urls = (try? FileManager.default.contentsOfDirectory(at: folder,
                             includingPropertiesForKeys: nil)) ?? []
            all += urls.filter { $0.pathExtension.lowercased() == "mp3" }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { SouMatomeTrack(url: $0, cd: cd) }
        }
        tracks = all
    }

    func importPDF(from source: URL, for book: SouMatomeDocument) async throws {
        let root = self.root
        let id = book.id
        let expected = book.pages
        let replaced = try await Task.detached(priority: .userInitiated) { () throws -> Bool in
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            guard source.pathExtension.lowercased() == "pdf" else {
                throw SouMatomeImportError.invalidSource
            }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let temp = root.appendingPathComponent(id + ".importing.pdf")
            let target = root.appendingPathComponent(id + ".pdf")
            if FileManager.default.fileExists(atPath: temp.path) {
                try FileManager.default.removeItem(at: temp)
            }
            defer { try? FileManager.default.removeItem(at: temp) }
            try FileManager.default.copyItem(at: source, to: temp)
            let actual = PDFDocument(url: temp)?.pageCount ?? 0
            guard actual == expected else { throw SouMatomeImportError.invalidPDF(expected, actual) }
            let previouslyInstalled = FileManager.default.fileExists(atPath: target.path)
            if previouslyInstalled {
                _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)
            } else {
                try FileManager.default.moveItem(at: temp, to: target)
            }
            return previouslyInstalled
        }.value
        // An old corrected transcription cannot be certified for a replaced PDF.
        if replaced {
            let directory = root.appendingPathComponent("PageText", isDirectory: true)
                .appendingPathComponent(book.id, isDirectory: true)
            try? FileManager.default.removeItem(at: directory)
            for page in 1...book.pages {
                UserDefaults.standard.removeObject(
                    forKey: "SouMatome.verified." + book.id + "." + String(page))
            }
        }
        refresh()
    }

    /// Chọn một thư mục CD1/CD2 hoặc thư mục mẹ chứa cả hai CD.
    /// Giữ tách biệt tên file 01.mp3 ... vì hai CD dùng lại cùng tên.
    func importAudioFolder(from source: URL) async throws -> Int {
        let root = self.root
        let imported = try await Task.detached(priority: .userInitiated) { () -> Int in
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            var count = 0
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  let walker = FileManager.default.enumerator(at: source,
                         includingPropertiesForKeys: [.isRegularFileKey],
                         options: [.skipsHiddenFiles]) else {
                throw SouMatomeImportError.invalidSource
            }
            let rootAudio = root.appendingPathComponent("Audio", isDirectory: true)
            for case let url as URL in walker {
                guard url.pathExtension.lowercased() == "mp3" else { continue }
                let relative = url.path.replacingOccurrences(of: source.path, with: "")
                let label = (source.lastPathComponent + "/" + relative).uppercased()
                let cd = label.contains("CD2") || label.contains("ＣＤ2") ? "CD2" : "CD1"
                let folder = rootAudio.appendingPathComponent(cd, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let dest = folder.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                count += 1
            }
            guard count > 0 else { throw SouMatomeImportError.noAudio }
            return count
        }.value
        refresh()
        return imported
    }
}

@MainActor
final class SouMatomeAudioPlayer: ObservableObject {
    @Published private(set) var currentTrack: String?
    @Published private(set) var playing = false
    @Published var position = 0.0
    @Published private(set) var duration = 0.0
    private var player: AVPlayer?
    private var timeToken: Any?

    func play(_ track: SouMatomeTrack) {
        stop()
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio) }
        catch { /* iOS vẫn có thể phát theo audio session hiện hành. */ }
        let next = AVPlayer(url: track.url)
        player = next
        currentTrack = track.id
        timeToken = next.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main) { [weak self, weak next] time in
                guard let self, let next else { return }
                self.position = time.seconds.isFinite ? time.seconds : 0
                let seconds = next.currentItem?.duration.seconds ?? 0
                self.duration = seconds.isFinite && seconds > 0 ? seconds : 0
            }
        next.play()
        playing = true
    }

    func toggle() {
        guard let player else { return }
        if playing { player.pause() } else { player.play() }
        playing.toggle()
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
    }

    func stop() {
        if let player, let timeToken { player.removeTimeObserver(timeToken) }
        player?.pause()
        player = nil
        timeToken = nil
        currentTrack = nil
        playing = false
        position = 0
        duration = 0
    }
}

struct SouMatomeLibraryView: View {
    @EnvironmentObject private var store: StudyStore
    @StateObject private var library = SouMatomeLibraryStore()
    @StateObject private var audio = SouMatomeAudioPlayer()
    @State private var selectedBook: SouMatomeDocument?
    @State private var pickPDF = false
    @State private var pickAllPDF = false
    @State private var pickAudio = false
    @State private var working = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                SectionTitle("Sou Matome N2 – thư viện cá nhân",
                             subtitle: "5 kỹ năng, các tài liệu Nhật–Việt và CD nghe")
                LessonPanel {
                    Text("Bộ đang chọn: \(store.selectedSeries.name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.navy)
                    if store.selectedSeries != .souMatome {
                        MainButton(title: "Chuyển sang học Sou Matome", symbol: "checkmark.circle.fill") {
                            store.selectSeries(.souMatome)
                        }
                    }
                    Text("Phần PDF và CD được lưu riêng trên iPhone sau khi bạn nhập từ Tệp. Không tải hoặc đăng sách lên GitHub. Dữ liệu tương tác vẫn là gói JSON được kiểm duyệt riêng, không phải bản chép đầy đủ sách.")
                        .font(.caption).foregroundColor(.secondary)
                }
                LessonPanel {
                    SectionTitle("Nhập nhanh toàn bộ PDF")
                    Text("Chọn cả 8 PDF đã giải nén trong Tệp. Ứng dụng tự nhận diện theo tên và kiểm tra số trang của từng cuốn.")
                        .font(.caption).foregroundColor(.secondary)
                    MainButton(title: working ? "Đang xác minh và nhập…" : "Chọn nhiều PDF cùng lúc",
                               symbol: "square.and.arrow.down.on.square") {
                        pickAllPDF = true
                    }.disabled(working)
                }
                LessonPanel {
                    SectionTitle("5 sách chính",
                                 subtitle: "\(SouMatomeDocument.all.filter { !$0.supplementary && library.pagesImported[$0.id] != nil }.count)/5 đã nhập")
                    ForEach(SouMatomeDocument.all.filter { !$0.supplementary }) { book in
                        bookRow(book)
                    }
                }
                LessonPanel {
                    SectionTitle("3 tài liệu bổ trợ Nhật – Việt")
                    ForEach(SouMatomeDocument.all.filter { $0.supplementary }) { book in
                        bookRow(book)
                    }
                }
                LessonPanel {
                    SectionTitle("CD nghe hiểu – 116 tệp MP3",
                                 subtitle: "CD1: 64 tệp • CD2: 52 tệp trong bộ đã cung cấp")
                    Text("Để nhập CD, giải nén RAR trên máy tính rồi chuyển thư mục CD1/CD2 vào Tệp trên iPhone. Chọn thư mục mẹ để nhập cả hai CD.")
                        .font(.caption).foregroundColor(.secondary)
                    MainButton(title: working ? "Đang nhập dữ liệu…" : "Nhập thư mục audio CD",
                               symbol: "folder.badge.plus") {
                        pickAudio = true
                    }.disabled(working)
                    Text("Đã nhập: \(library.tracks.count)/116 tệp MP3")
                        .font(.subheadline.weight(.semibold)).foregroundColor(Palette.blue)
                    if audio.currentTrack != nil {
                        VStack(spacing: 8) {
                            HStack {
                                Button {
                                    audio.toggle()
                                } label: {
                                    Label(audio.playing ? "Tạm dừng" : "Phát tiếp",
                                          systemImage: audio.playing ? "pause.fill" : "play.fill")
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                                Button { audio.stop() } label: {
                                    Label("Dừng", systemImage: "stop.fill")
                                }.buttonStyle(.bordered)
                            }
                            Slider(value: Binding(get: { audio.position },
                                                  set: { audio.seek(to: $0) }),
                                   in: 0...max(1, audio.duration))
                            HStack {
                                Text(time(audio.position))
                                Spacer()
                                Text(time(audio.duration))
                            }.font(.caption.monospacedDigit()).foregroundColor(.secondary)
                        }
                    }
                    ForEach(library.tracks) { track in
                        Button {
                            audio.play(track)
                        } label: {
                            HStack {
                                Image(systemName: audio.currentTrack == track.id && audio.playing
                                      ? "waveform" : "play.circle")
                                Text("\(track.cd) · Track \(track.name)")
                                    .font(.subheadline)
                                Spacer()
                            }
                            .foregroundColor(Palette.navy)
                            .padding(.vertical, 5)
                        }.buttonStyle(.plain)
                    }
                }
                if let message {
                    Text(message).font(.footnote).foregroundColor(Palette.navy)
                }
            }
            .padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Sou Matome N2")
        .fileImporter(isPresented: $pickAllPDF, allowedContentTypes: [.pdf],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                working = true
                Task {
                    var count = 0
                    var errors: [String] = []
                    for url in urls {
                        guard let book = SouMatomeLibraryStore.identifyBook(named: url.lastPathComponent) else {
                            errors.append(url.lastPathComponent + ": không nhận diện được tên")
                            continue
                        }
                        do {
                            try await library.importPDF(from: url, for: book)
                            count += 1
                        } catch {
                            errors.append(url.lastPathComponent + ": " + error.localizedDescription)
                        }
                    }
                    message = "Đã nhập đúng \(count)/\(urls.count) PDF."
                        + (errors.isEmpty ? "" : " Chưa nhập: " + errors.joined(separator: " | "))
                    working = false
                }
            case .failure(let error): message = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $pickPDF, allowedContentTypes: [.pdf]) { result in
            guard let book = selectedBook else { return }
            switch result {
            case .success(let url):
                working = true
                Task {
                    do {
                        try await library.importPDF(from: url, for: book)
                        message = "Đã nhập \(book.title), đủ \(book.pages) trang."
                    } catch {
                        message = "Lỗi nhập sách: \(error.localizedDescription)"
                    }
                    working = false
                }
            case .failure(let error): message = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $pickAudio, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                working = true
                Task {
                    do {
                        let count = try await library.importAudioFolder(from: url)
                        message = "Đã nhập \(count) tệp âm thanh vào thư viện riêng."
                    } catch {
                        message = "Lỗi nhập audio: \(error.localizedDescription)"
                    }
                    working = false
                }
            case .failure(let error): message = error.localizedDescription
            }
        }
        .onDisappear { audio.stop() }
    }

    private func bookRow(_ book: SouMatomeDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title).font(.subheadline.weight(.bold)).foregroundColor(Palette.navy)
                    Text("\(book.pages) trang · \(book.skill)")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if library.pagesImported[book.id] != nil {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Palette.teal)
                }
            }
            HStack(spacing: 12) {
                Button {
                    selectedBook = book
                    pickPDF = true
                } label: {
                    Label(library.pagesImported[book.id] == nil ? "Nhập PDF" : "Thay PDF",
                          systemImage: "square.and.arrow.down")
                }.buttonStyle(.bordered).disabled(working)
                if let fileURL = library.fileURL(for: book) {
                    NavigationLink {
                        SouMatomePDFReader(book: book, url: fileURL)
                    } label: {
                        Label("Đọc sách", systemImage: "book.pages")
                    }.buttonStyle(.borderedProminent)
                    NavigationLink {
                        SouMatomePageWorkbenchView(book: book, url: fileURL)
                    } label: {
                        Label("Kiểm tra chữ", systemImage: "text.viewfinder")
                    }.buttonStyle(.bordered)
                }
            }
            Divider()
        }
    }

    private func time(_ seconds: Double) -> String {
        let valid = max(0, Int(seconds.isFinite ? seconds : 0))
        return String(format: "%02d:%02d", valid / 60, valid % 60)
    }
}

struct SouMatomePDFReader: View {
    let book: SouMatomeDocument
    let url: URL
    @State private var page: Int

    init(book: SouMatomeDocument, url: URL, initialPage: Int? = nil) {
        self.book = book
        self.url = url
        let stored = UserDefaults.standard.integer(forKey: "SouMatome.lastPage." + book.id)
        _page = State(initialValue: max(1, min(book.pages, initialPage ?? stored)))
    }

    var body: some View {
        VStack(spacing: 0) {
            SouMatomePDFKitView(url: url, page: $page)
            if !book.sectionPages.isEmpty {
                HStack {
                    Text("Đi đến bài học")
                        .font(.caption.weight(.semibold)).foregroundColor(Palette.navy)
                    Spacer()
                    Menu {
                        ForEach(Array(book.sectionPages.enumerated()), id: \.offset) { index, firstPage in
                            Button("\(book.sectionLabel) \(index + 1) · Trang \(firstPage)") {
                                page = firstPage
                            }
                        }
                    } label: {
                        Label("Chọn \(book.sectionLabel.lowercased())", systemImage: "list.bullet")
                    }
                }
                .padding(.horizontal, 13)
                .padding(.top, 8)
                .background(Palette.pale)
            }
            HStack(spacing: 15) {
                Button { page = max(1, page - 1) } label: {
                    Image(systemName: "chevron.left.circle.fill").font(.title2)
                }.disabled(page <= 1)
                Spacer()
                Text("Trang \(page)/\(book.pages)")
                    .font(.subheadline.monospacedDigit())
                Spacer()
                Button { page = min(book.pages, page + 1) } label: {
                    Image(systemName: "chevron.right.circle.fill").font(.title2)
                }.disabled(page >= book.pages)
            }
            .padding(13)
            .background(Palette.pale)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: page) { value in
            UserDefaults.standard.set(value, forKey: "SouMatome.lastPage." + book.id)
        }
    }
}

struct SouMatomePDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var page: Int

    func makeCoordinator() -> Coordinator { Coordinator(page: $page) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemGroupedBackground
        view.document = PDFDocument(url: url)
        context.coordinator.pdfView = view
        NotificationCenter.default.addObserver(context.coordinator,
                         selector: #selector(Coordinator.changed(_:)),
                         name: .PDFViewPageChanged, object: view)
        if let initial = view.document?.page(at: max(0, page - 1)) {
            view.go(to: initial)
        }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard let document = view.document,
              let current = view.currentPage,
              let wanted = document.page(at: max(0, min(page - 1, document.pageCount - 1)))
        else { return }
        if current != wanted { view.go(to: wanted) }
    }

    final class Coordinator: NSObject {
        @Binding var page: Int
        weak var pdfView: PDFView?
        init(page: Binding<Int>) { _page = page }

        @objc func changed(_ note: Notification) {
            guard let view = pdfView, let current = view.currentPage,
                  let document = view.document else { return }
            let index = document.index(for: current) + 1
            if index > 0 && index != page { page = index }
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
