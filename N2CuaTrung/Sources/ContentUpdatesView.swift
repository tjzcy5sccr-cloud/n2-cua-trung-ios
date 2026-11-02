import SwiftUI
import UniformTypeIdentifiers

struct ContentUpdatesView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var choosingFile = false
    @State private var downloading = false
    @State private var status: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("Thư viện bài học", subtitle: "Mỗi bộ được lưu và hiển thị độc lập")
                LessonPanel {
                    SectionTitle("Bộ đang học")
                    Picker("Chọn bộ", selection: Binding(
                        get: { store.selectedSeries },
                        set: { store.selectSeries($0) }
                    )) {
                        ForEach(LearningSeries.allCases) { series in
                            Text(series.name).tag(series)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.blue)
                    Text(store.selectedSeries.subtitle)
                        .font(.caption).foregroundColor(.secondary)
                    Text("Đổi bộ sẽ thay nội dung trên tất cả các màn học ngay, không xóa tiến độ đã lưu.")
                        .font(.caption).foregroundColor(.secondary)
                }
                if store.selectedSeries == .souMatome {
                    LessonPanel {
                        SectionTitle("Bài luyện N2 và sách Sou Matome")
                        Toggle("Hiện bài luyện N2 độc lập", isOn: Binding(
                            get: { store.includeIndependentSouMatomePractice },
                            set: { store.setIndependentSouMatomePractice($0) }
                        ))
                        .tint(Palette.teal)
                        Text("Bài luyện độc lập do dự án biên soạn, không phải bản sao hoặc đáp án được xác nhận từ sách Sou Matome.")
                            .font(.caption).foregroundColor(.secondary)
                        Text("Mục đã xác nhận riêng từ PDF cá nhân: \(store.souMatomeVerifiedBookItemCount). Chỉ các mục này mới được tính là đã hiệu đính theo sách.")
                            .font(.caption.weight(.semibold)).foregroundColor(Palette.navy)
                    }
                    NavigationLink { SouMatomeWholeBooksView() } label: {
                        ActionTile(icon: "books.vertical.circle.fill", color: Palette.blue,
                                   title: "Mở sách và kho nguồn Sou Matome",
                                   detail: "Nhập PDF, 116 MP3 và mục trích xuất để đối chiếu riêng")
                    }.buttonStyle(.plain)
                    NavigationLink { SouMatomeSourceEntriesView() } label: {
                        ActionTile(icon: "doc.badge.plus", color: Palette.orange,
                                   title: "Nhập 2.963 mục đã trích xuất",
                                   detail: "Chọn JSON cá nhân đã tạo; kiểm tra từng mục trước khi dùng làm flashcard")
                    }.buttonStyle(.plain)
                }
                LessonPanel {
                    SectionTitle("Dữ liệu đang hiển thị — \(store.selectedSeries.name)")
                    itemRow("Từ vựng", store.course.vocab.count)
                    itemRow("Ngữ pháp", store.course.grammar.count)
                    itemRow("Kanji", store.course.kanji.count)
                    itemRow("Đọc hiểu", store.course.readings.count)
                    itemRow("Nghe hiểu", store.course.listening.count)
                }
                LessonPanel {
                    SectionTitle("Cập nhật dữ liệu")
                    Text("Khi có Wi-Fi hoặc mạng di động, bấm tải bản mới từ GitHub. Sau khi hoàn tất, bạn có thể học không cần mạng.")
                        .font(.subheadline).foregroundColor(.secondary)
                    MainButton(title: downloading ? "Đang kiểm tra và tải…" : "Kiểm tra bài học mới",
                               symbol: "arrow.down.circle.fill") {
                        guard !downloading else { return }
                        downloading = true
                        Task {
                            do {
                                let count = try await store.downloadCourseUpdates()
                                if store.selectedSeries == .souMatome {
                                    let items = store.itemCount(for: .souMatome)
                                    status = count == 0
                                        ? "Đã kiểm tra bản mới nhất. Hiện có \(items) bài được phép hiển thị trong chế độ đã chọn."
                                        : "Đã tải \(count) gói. Sou Matome hiển thị \(items) mục theo lựa chọn của bạn; mục từ sách chưa xác nhận không tự biến thành flashcard."
                                } else {
                                    status = count == 0
                                        ? "Đã kiểm tra bản mới nhất cho \(store.selectedSeries.name)."
                                        : "Đã cập nhật \(count) gói; màn học đã làm mới."
                                }
                            } catch { status = "Cập nhật thất bại: \(error.localizedDescription)" }
                            downloading = false
                        }
                    }
                    .disabled(downloading)
                    MainButton(title: "Nhập gói học JSON từ Tệp", symbol: "square.and.arrow.down",
                               color: Palette.navy) {
                        choosingFile = true
                    }
                    if let status {
                        Text(status).font(.footnote).foregroundColor(Palette.navy)
                    }
                }
                LessonPanel {
                    SectionTitle("Gói đã cài")
                    if store.installedPacks.isEmpty {
                        Text("Đã cài bộ bài học offline đi kèm ứng dụng.")
                            .font(.subheadline).foregroundColor(.secondary)
                    } else {
                        ForEach(store.installedPacks) { pack in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pack.title).font(.subheadline.weight(.semibold))
                                    if let seriesID = pack.seriesId,
                                       let series = LearningSeries(rawValue: seriesID) {
                                        Text(series.name).font(.caption2).foregroundColor(Palette.blue)
                                    }
                                    Text("Phiên bản \(pack.version) · \(pack.itemCount) mục")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill").foregroundColor(Palette.teal)
                            }
                        }
                    }
                    Text("Cập nhật dữ liệu không xóa lịch sử ôn tập và điểm kiểm tra. ID thẻ học được giữ cố định khi cập nhật.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Cập nhật bài học")
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    try store.importContentPack(Data(contentsOf: url))
                    status = "Đã cài gói mới, toàn bộ màn hình đã nạp lại theo bộ đang chọn."
                } catch { status = "Không thể nhập: \(error.localizedDescription)" }
            case .failure(let error):
                status = "Không thể mở tệp: \(error.localizedDescription)"
            }
        }
    }

    private func itemRow(_ label: String, _ total: Int) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(Palette.navy)
            Spacer()
            Text("\(total)").font(.subheadline.weight(.bold)).foregroundColor(Palette.blue)
        }
    }
}