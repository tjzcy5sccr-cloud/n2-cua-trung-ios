import SwiftUI
import Foundation

/// User-owned questions stay on this device. Source scans and passages are
/// never uploaded to the public repository or approved by OCR automatically.
struct SouMatomePrivateQuestion: Identifiable, Codable {
    let id: String
    var kind: String
    var bookID: String
    var page: Int
    var title: String
    var japaneseText: String
    var vietnameseText: String
    var question: String
    var choices: [String]
    var answer: Int
    var explanation: String
    var audioCD: String
    var audioTrack: Int
    var sourceChecked: Bool
    var translationChecked: Bool
    var answerChecked: Bool
    var approvedAt: Date?

    static func new(kind: String) -> Self {
        .init(id: UUID().uuidString, kind: kind,
              bookID: kind == "Nghe hiểu" ? "choukai" : "dokkai", page: 1,
              title: "", japaneseText: "", vietnameseText: "",
              question: "", choices: Array(repeating: "", count: 4),
              answer: 0, explanation: "",
              audioCD: "CD1", audioTrack: 1,
              sourceChecked: false, translationChecked: false,
              answerChecked: false, approvedAt: nil)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive,
                               .widthInsensitive],
                     locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    var readyForReview: Bool {
        guard (kind == "Đọc hiểu" && bookID == "dokkai") ||
              (kind == "Nghe hiểu" && bookID == "choukai") else { return false }
        let maxPage = kind == "Đọc hiểu" ? 121 : 73
        if kind == "Nghe hiểu" {
            guard ["CD1", "CD2"].contains(audioCD),
                  (1...(audioCD == "CD1" ? 64 : 52)).contains(audioTrack)
            else { return false }
        }
        guard (1...maxPage).contains(page), !title.isEmpty, !question.isEmpty,
              !japaneseText.isEmpty, !vietnameseText.isEmpty,
              !explanation.isEmpty, choices.count == 4,
              choices.indices.contains(answer) else { return false }
        guard japaneseText.unicodeScalars.contains(where: {
            (0x3040...0x30FF).contains(Int($0.value)) ||
            (0x3400...0x9FFF).contains(Int($0.value))
        }) else { return false }
        let keys = choices.map(normalized)
        guard keys.allSatisfy({ !$0.isEmpty }),
              Set(keys).count == 4,
              !normalized(vietnameseText).isEmpty,
              !normalized(question).isEmpty,
              !normalized(explanation).isEmpty else { return false }
        return true
    }

    var isApproved: Bool {
        readyForReview && sourceChecked && translationChecked &&
        answerChecked && approvedAt != nil
    }

    mutating func revokeApproval() {
        sourceChecked = false
        translationChecked = false
        answerChecked = false
        approvedAt = nil
    }
}

@MainActor
final class SouMatomePrivateQuestionStore: ObservableObject {
    @Published private(set) var items: [SouMatomePrivateQuestion] = []
    @Published var lastError: String?
    private let root = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SouMatomePersonalLibrary", isDirectory: true)
    private var file: URL {
        root.appendingPathComponent("personal-reading-listening-questions.json")
    }

    init() {
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode(
                [SouMatomePrivateQuestion].self, from: data) {
            items = decoded
        }
    }

    var approvedCount: Int { items.filter(\.isApproved).count }
    var drafts: Int { items.count - approvedCount }

    func save(_ updated: SouMatomePrivateQuestion) throws {
        var merged = items
        if let index = merged.firstIndex(where: { $0.id == updated.id }) {
            merged[index] = updated
        } else { merged.append(updated) }
        try write(merged)
    }

    func invalidateBook(_ bookID: String) throws {
        var revised = items
        for index in revised.indices where revised[index].bookID == bookID {
            revised[index].revokeApproval()
        }
        try write(revised)
    }

    /// A changed CD track invalidates only exercises linked to that file.
    /// Unchanged listening questions and reading questions keep their reviews.
    func invalidateAudioTracks(_ keys: Set<String>) throws {
        guard !keys.isEmpty else { return }
        var revised = items
        for index in revised.indices where revised[index].kind == "Nghe hiểu" {
            let item = revised[index]
            let filename = String(format: "%02d.mp3", item.audioTrack)
            if keys.contains(item.audioCD + "/" + filename) {
                revised[index].revokeApproval()
            }
        }
        try write(revised)
    }

    private func write(_ updated: [SouMatomePrivateQuestion]) throws {
        guard updated.count <= 2000,
              Set(updated.map(\.id)).count == updated.count else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(updated)
        guard data.count <= 8 * 1_024 * 1_024 else {
            throw SouMatomeReviewError.invalidCandidateFile
        }
        try data.write(to: file, options: .atomic)
        items = updated
        lastError = nil
    }

    /// Separate pack ID means updating reading/listening cannot remove or
    /// overwrite reviewed vocab/grammar/Kanji cards.
    func synchronize(with study: StudyStore) throws -> Int {
        let approved = items.filter(\.isApproved).sorted { $0.id < $1.id }
        if approved.isEmpty {
            try study.revokePersonalExercisePack()
            return 0
        }
        var readings: [[String: Any]] = []
        var listening: [[String: Any]] = []
        for item in approved {
            let lessonID = "sm-personal-question-" + item.id
            if item.kind == "Đọc hiểu" {
                readings.append([
                    "id": lessonID, "title": item.title,
                    "topic": "private-book:dokkai:page-\(item.page)",
                    "text": item.japaneseText, "textVi": item.vietnameseText,
                    "question": item.question, "choices": item.choices,
                    "answer": item.answer, "explanation": item.explanation
                ])
            } else {
                listening.append([
                    "id": lessonID, "title": item.title,
                    "speaker": "private-book:choukai:page-\(item.page)",
                    // The quiz uses the verified Japanese script as iOS TTS;
                    // original CD files remain in the separate private library.
                    "script": item.japaneseText, "scriptVi": item.vietnameseText,
                    "audioCD": item.audioCD, "audioTrack": item.audioTrack,
                    "question": item.question, "choices": item.choices,
                    "answer": item.answer, "explanation": item.explanation
                ])
            }
        }
        let version = (study.installedPacks.first {
            $0.id == "sou-matome-personal-exercises"
        }?.version ?? 0) + 1
        let pack: [String: Any] = [
            "id": "sou-matome-personal-exercises", "seriesId": "sou-matome",
            "version": version, "title": "Sou Matome – câu đọc/nghe riêng đã duyệt",
            "vocab": [[String: Any]](), "grammar": [[String: Any]](),
            "kanji": [[String: Any]](),
            "readings": readings, "listening": listening
        ]
        let bytes = try JSONSerialization.data(
            withJSONObject: pack, options: [.sortedKeys])
        try study.importContentPack(bytes)
        return approved.count
    }
}

struct SouMatomePrivateQuestionListView: View {
    @EnvironmentObject private var study: StudyStore
    @StateObject private var store = SouMatomePrivateQuestionStore()
    @State private var message: String?
    var body: some View {
        List {
            Section {
                Text("\(store.approvedCount) câu đã kiểm tra · \(store.drafts) bản nháp")
                Text("Chỉ câu hỏi được đối chiếu với trang PDF, dịch Việt và kiểm tra đáp án mới chuyển sang phần luyện. Bản nghe dùng bản thoại đã duyệt và giọng Nhật iOS; chưa tự động ghép CD gốc.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("Thêm câu hỏi từ trang sách cá nhân") {
                NavigationLink {
                    SouMatomePrivateQuestionEditor(
                        store: store, initial: .new(kind: "Đọc hiểu"))
                } label: {
                    Label("Thêm câu đọc hiểu", systemImage: "doc.text")
                }
                NavigationLink {
                    SouMatomePrivateQuestionEditor(
                        store: store, initial: .new(kind: "Nghe hiểu"))
                } label: {
                    Label("Thêm câu nghe hiểu", systemImage: "headphones")
                }
            }
            Section("Các câu đã nhập") {
                ForEach(store.items.sorted { $0.title < $1.title }) { item in
                    NavigationLink {
                        SouMatomePrivateQuestionEditor(store: store, initial: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title.isEmpty ? "Câu hỏi chưa đặt tên" : item.title)
                            Text("\(item.kind) · PDF trang \(item.page) · "
                                 + (item.isApproved ? "Đã kiểm chứng" : "Cần đối chiếu"))
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            Section {
                Button("Đồng bộ câu hỏi đã kiểm chứng vào bài luyện") {
                    do {
                        let count = try store.synchronize(with: study)
                        message = "Đã đồng bộ \(count) câu hỏi được kiểm chứng."
                    } catch {
                        message = error.localizedDescription
                    }
                }
                if let message { Text(message).font(.caption) }
            }
        }
        .navigationTitle("Câu hỏi đọc và nghe")
    }
}

struct SouMatomePrivateQuestionEditor: View {
    @EnvironmentObject private var study: StudyStore
    @ObservedObject var store: SouMatomePrivateQuestionStore
    @State private var item: SouMatomePrivateQuestion
    @State private var confirmation: String?
    @State private var sourceOK = false
    @State private var translationOK = false
    @State private var answerOK = false

    init(store: SouMatomePrivateQuestionStore, initial: SouMatomePrivateQuestion) {
        self.store = store
        _item = State(initialValue: initial)
    }

    var body: some View {
        Form {
            Section("Nguồn bài học") {
                Text(item.kind)
                Stepper("Trang \(item.page)", value: $item.page,
                        in: 1...(item.kind == "Đọc hiểu" ? 121 : 73))
                if item.kind == "Nghe hiểu" {
                    Picker("CD nguồn", selection: $item.audioCD) {
                        Text("CD1").tag("CD1")
                        Text("CD2").tag("CD2")
                    }
                    Stepper("Track \(item.audioTrack)",
                            value: $item.audioTrack,
                            in: 1...(item.audioCD == "CD1" ? 64 : 52))
                    if let track = SouMatomeLibraryStore().tracks.first(where: {
                        $0.cd == item.audioCD &&
                        Int($0.name.filter(\.isNumber)) == item.audioTrack
                    }) {
                        Text("Đã tìm thấy \(track.name).mp3 trong thư viện riêng.")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        Text("Chưa nhập đúng track CD này. Có thể ghi nội dung nhưng chưa phát audio gốc trong đề.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                if let book = SouMatomeDocument.all.first(where: {
                    $0.id == item.bookID
                }), let url = SouMatomeLibraryStore().fileURL(for: book) {
                    NavigationLink {
                        SouMatomePDFReader(book: book, url: url,
                                          initialPage: item.page)
                    } label: {
                        Label("Đối chiếu đúng trang PDF", systemImage: "book")
                    }
                }
            }
            Section("Đề và giải thích Nhật–Việt") {
                TextField("Tên bài tự đặt", text: $item.title)
                TextField("Văn bản tiếng Nhật đã kiểm tra",
                          text: $item.japaneseText, axis: .vertical)
                TextField("Bản dịch tiếng Việt đã kiểm tra",
                          text: $item.vietnameseText, axis: .vertical)
                TextField("Câu hỏi", text: $item.question, axis: .vertical)
            }
            Section("Đáp án: bốn phương án không được trùng nghĩa") {
                ForEach(0..<4, id: \.self) { index in
                    TextField("Lựa chọn \(index + 1)",
                              text: $item.choices[index], axis: .vertical)
                }
                Picker("Đáp án đúng", selection: $item.answer) {
                    ForEach(0..<4, id: \.self) { index in
                        Text("Đáp án \(index + 1)").tag(index)
                    }
                }
                TextField("Giải thích lý do đáp án đúng",
                          text: $item.explanation, axis: .vertical)
            }
            Section("Kiểm chứng nguồn và đáp án") {
                Toggle(item.kind == "Nghe hiểu"
                       ? "Đã đối chiếu văn bản Nhật với PDF và track CD"
                       : "Đã đối chiếu nguyên văn tiếng Nhật với PDF",
                       isOn: $sourceOK)
                Toggle("Đã đối chiếu dịch nghĩa tiếng Việt",
                       isOn: $translationOK)
                Toggle("Đã xác minh đáp án và ba phương án sai",
                       isOn: $answerOK)
                Text(item.readyForReview
                     ? "Bài hợp lệ về cấu trúc; vẫn cần người kiểm chứng."
                     : "Thiếu nội dung Nhật–Việt, lời giải hoặc bốn đáp án phân biệt.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section {
                Button("Lưu bản nháp") { persist(approve: false) }
                Button("Xác nhận kiểm chứng và cập nhật luyện tập") {
                    persist(approve: true)
                }
                .disabled(!item.readyForReview ||
                          !sourceOK || !translationOK || !answerOK)
                if let confirmation {
                    Text(confirmation).font(.footnote)
                }
            }
        }
        .navigationTitle(item.kind)
        .onAppear {
            sourceOK = item.sourceChecked
            translationOK = item.translationChecked
            answerOK = item.answerChecked
        }
        .onChange(of: item.page) { _ in sourceOK = false }
        .onChange(of: item.audioCD) { _ in
            sourceOK = false
            item.audioTrack = min(item.audioTrack,
                                  item.audioCD == "CD1" ? 64 : 52)
        }
        .onChange(of: item.audioTrack) { _ in sourceOK = false }
        .onChange(of: item.japaneseText) { _ in sourceOK = false }
        .onChange(of: item.vietnameseText) { _ in translationOK = false }
        .onChange(of: item.title) { _ in sourceOK = false }
        .onChange(of: item.question) { _ in answerOK = false }
        .onChange(of: item.choices) { _ in answerOK = false }
        .onChange(of: item.answer) { _ in answerOK = false }
        .onChange(of: item.explanation) { _ in answerOK = false }
    }

    private func persist(approve: Bool) {
        item.sourceChecked = approve && sourceOK
        item.translationChecked = approve && translationOK
        item.answerChecked = approve && answerOK
        item.approvedAt = approve ? Date() : nil
        do {
            try store.save(item)
            let count = try store.synchronize(with: study)
            confirmation = "Đã lưu riêng và cập nhật \(count) câu được duyệt."
        } catch {
            confirmation = "Không thể đồng bộ vào bài luyện: "
                + error.localizedDescription
        }
    }
}
