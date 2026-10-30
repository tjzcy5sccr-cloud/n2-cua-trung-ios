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
                SectionTitle("Thư viện bài học", subtitle: "Bài mới được lưu trên iPhone để học offline")
                LessonPanel {
                    SectionTitle("Tổng dữ liệu hiện tại")
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
                                status = count == 0 ? "Đã là phiên bản dữ liệu mới nhất." : "Đã cài \(count) gói bài học mới, dùng được offline."
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
                                    Text(pack.id == "openjlpt-n2-core" ? "Bộ N2 mở rộng" : "Bộ bài học nâng cao").font(.subheadline.weight(.semibold))
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
                    status = "Đã cài gói dữ liệu mới và lưu offline trên iPhone."
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