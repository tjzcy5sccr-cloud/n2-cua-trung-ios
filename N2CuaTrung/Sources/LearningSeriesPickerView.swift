import SwiftUI

/// Chọn bộ chỉ thay nội dung học, không tạo app mới và không xóa lịch sử ôn.
struct LearningSeriesPickerView: View {
    @EnvironmentObject private var store: StudyStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Bộ dữ liệu học",
                             subtitle: "Chọn một bộ để đổi toàn bộ từ vựng, Kanji, ngữ pháp và bài luyện")
                LessonPanel {
                    HStack(spacing: 10) {
                        Image(systemName: store.selectedSeries.icon)
                            .font(.title2)
                            .foregroundColor(Palette.teal)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Đang học: \(store.selectedSeries.name)")
                                .font(.headline).foregroundColor(Palette.navy)
                            Text("\(store.itemCount(for: store.selectedSeries)) mục trong bộ hiện tại")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }
                ForEach(LearningSeries.allCases) { series in
                    let selected = store.selectedSeries == series
                    Button {
                        store.selectSeries(series)
                    } label: {
                        HStack(alignment: .center, spacing: 13) {
                            Image(systemName: series.icon)
                                .font(.title2)
                                .foregroundColor(selected ? Palette.teal : Palette.blue)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(series.name)
                                    .font(.headline)
                                    .foregroundColor(Palette.navy)
                                Text(series.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                Text("\(store.itemCount(for: series)) nội dung thực tế")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Palette.blue)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                                .font(.title3)
                                .foregroundColor(selected ? Palette.teal : .secondary)
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected ? Palette.teal.opacity(0.09) : Color.white,
                                    in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selected ? Palette.teal : Palette.blue.opacity(0.14),
                                        lineWidth: selected ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(series.name), \(store.itemCount(for: series)) mục, \(selected ? "đang chọn" : "chưa chọn")")
                }
                NavigationLink { SouMatomeLibraryView() } label: {
                    ActionTile(icon: "books.vertical.circle.fill", color: Palette.blue,
                               title: "Sou Matome – Sách và CD của bạn",
                               detail: "Nhập 5 PDF sách chính, 3 bản bổ trợ và 116 bài MP3; mở offline")
                }.buttonStyle(.plain)
                LessonPanel {
                    SectionTitle("Dữ liệu theo bộ, không trộn lẫn")
                    Text("Shin Kanzen, Sou Matome, Mimikara và Speed/Kanji Master có các tệp JSON riêng. Các tệp này là bài do dự án N2 của Trung tuyển chọn và sắp xếp theo hướng học, không phải bản số hóa hay nội dung chính thức từ nhà xuất bản.")
                        .font(.subheadline).foregroundColor(.secondary)
                    Text("Chọn «Tổng hợp N2» để hiển thị lại toàn bộ kho gốc cùng các gói đã cài. Dữ liệu ôn tập và điểm cũ vẫn được lưu trên iPhone.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                NavigationLink { ContentUpdatesView() } label: {
                    ActionTile(icon: "arrow.down.circle.fill", color: Palette.teal,
                               title: "Cập nhật các bộ dữ liệu",
                               detail: "Tải gói mới rồi làm mới nội dung học")
                }.buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Chọn bộ học N2")
        .navigationBarTitleDisplayMode(.inline)
    }
}
