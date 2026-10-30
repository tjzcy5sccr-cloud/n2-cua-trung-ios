import SwiftUI
import UniformTypeIdentifiers

struct PlanView: View {
    @EnvironmentObject private var store: StudyStore
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                LessonPanel {
                    SectionTitle("Lộ trình 35 tuần", subtitle: "02/11/2026 – 04/07/2027")
                    Text("Từ trình độ N3 đến mục tiêu JLPT N2 tháng 7/2027. Học 90 phút/ngày, 6 ngày/tuần. Chủ nhật ôn nhẹ hoặc nghỉ.")
                        .font(.subheadline).foregroundColor(.secondary)
                    ProgressView(value: Double(store.week), total: 35)
                        .tint(Palette.teal)
                    Text("Đang học tuần \(store.week) / 35")
                        .font(.caption.weight(.medium)).foregroundColor(Palette.blue)
                    if store.saved.overrideWeek != nil {
                        Button("Chuyển về lịch tự động") { store.selectWeek(nil) }
                            .font(.subheadline)
                    }
                }
                ForEach(store.course.weeks) { item in
                    LessonPanel {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TUẦN \(item.n)")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(item.n == store.week ? Palette.teal : Palette.blue)
                                Text(item.date).font(.caption).foregroundColor(.secondary)
                                Text(item.focus).font(.headline).foregroundColor(Palette.navy)
                            }
                            Spacer()
                            if item.n == store.week {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(Palette.teal)
                            }
                        }
                        Text("Chủ đề: \(item.context)")
                            .font(.subheadline).foregroundColor(.secondary)
                        Text("Đánh giá: \(item.exam)")
                            .font(.subheadline).foregroundColor(.secondary)
                        if item.n != store.week {
                            Button("Học tuần này") { store.selectWeek(item.n) }
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("35 tuần")
    }
}

struct ProgressDashboardView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var showExport = false
    @State private var showImport = false
    @State private var backupMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("Tiến độ của Trung", subtitle: "Lưu cục bộ và dùng được khi offline")
                HStack(spacing: 9) {
                    StatBox(number: "\(store.reviewedCount)", label: "Thẻ đã ôn", symbol: "rectangle.stack")
                    StatBox(number: "\(store.mastered)", label: "Nhớ vững", symbol: "checkmark.circle")
                    StatBox(number: "\(store.averageScore)%", label: "Điểm luyện", symbol: "chart.line.uptrend.xyaxis")
                }
                LessonPanel {
                    SectionTitle("Bộ bài học hiện có")
                    progressLine("Từ vựng", value: store.course.vocab.count)
                    progressLine("Ngữ pháp", value: store.course.grammar.count)
                    progressLine("Kanji", value: store.course.kanji.count)
                    progressLine("Đọc hiểu", value: store.course.readings.count)
                    progressLine("Nghe hiểu", value: store.course.listening.count)
                    Text("Số lượng trên là nội dung bản đầu tiên, không phải toàn bộ kho JLPT N2.")
                        .font(.caption).foregroundColor(.secondary)
                }
                LessonPanel {
                    SectionTitle("Kết quả kiểm tra")
                    HStack {
                        Text("Bài số 01 (trước khi dùng app)")
                            .font(.subheadline)
                        Spacer()
                        Text("3/6").font(.headline).foregroundColor(Palette.orange)
                    }
                    if store.saved.tests.isEmpty {
                        Text("Chưa làm bài kiểm tra trong ứng dụng.")
                            .font(.subheadline).foregroundColor(.secondary)
                    } else {
                        ForEach(store.saved.tests.prefix(12)) { item in
                            Divider()
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.type).font(.subheadline.weight(.semibold))
                                    Text(item.date, style: .date)
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(item.correct)/\(item.total)")
                                    .font(.headline).foregroundColor(Palette.blue)
                            }
                        }
                    }
                }
                NavigationLink {
                    AboutView()
                } label: {
                    ActionTile(icon: "info.circle", color: Palette.blue,
                               title: "Giới thiệu và bản quyền", detail: "Tác giả: Trần Phước Trung")
                }
                .buttonStyle(.plain)
                LessonPanel {
                    SectionTitle("Sao lưu & khôi phục")
                    Text("Chuyển kết quả sang iPhone mới bằng tệp JSON. Không cần tài khoản hay máy chủ.")
                        .font(.subheadline).foregroundColor(.secondary)
                    MainButton(title: "Xuất bản sao lưu", symbol: "square.and.arrow.up") {
                        showExport = true
                    }
                    MainButton(title: "Nhập bản sao lưu", symbol: "square.and.arrow.down", color: Palette.navy) {
                        showImport = true
                    }
                    if let backupMessage {
                        Text(backupMessage).font(.caption).foregroundColor(Palette.teal)
                    }
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Tiến độ")
        .fileExporter(isPresented: $showExport,
                      document: ProgressBackupDocument(data: store.exportJSON() ?? Data()),
                      contentType: .json, defaultFilename: "N2_cua_Trung_backup") { result in
            if case .failure(let error) = result { backupMessage = "Không xuất được: \(error.localizedDescription)" }
        }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    let bytes = try Data(contentsOf: url)
                    try store.importJSON(bytes)
                    backupMessage = "Đã khôi phục dữ liệu từ bản sao lưu."
                } catch {
                    backupMessage = "Không đọc được bản sao lưu: \(error.localizedDescription)"
                }
            case .failure(let error):
                backupMessage = "Không thể chọn tệp: \(error.localizedDescription)"
            }
        }
    }

    private func progressLine(_ title: String, value: Int) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(Palette.navy)
            Spacer()
            Text("\(value)").font(.subheadline.weight(.bold)).foregroundColor(Palette.blue)
        }
    }
}

struct ProgressBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
