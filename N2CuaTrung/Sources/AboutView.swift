import SwiftUI

/// Thông tin tác giả và bản quyền của ứng dụng N2 của Trung.
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 104, height: 104)
                        .background(
                            LinearGradient(colors: [Palette.blue, Palette.navy],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 26)
                        )
                        .accessibilityHidden(true)

                    Text("N2 của Trung")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundColor(Palette.navy)
                    Text("Ứng dụng học JLPT N2 do Trần Phước Trung tạo")
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Text("Phiên bản \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)

                LessonPanel {
                    SectionTitle("Tác giả và bản quyền")
                    Label("Tác giả: Trần Phước Trung", systemImage: "person.crop.circle")
                        .foregroundColor(Palette.navy)
                    Label("Ứng dụng được tạo bởi Trần Phước Trung", systemImage: "checkmark.seal")
                        .foregroundColor(Palette.navy)
                    Divider()
                    Text("Bản quyền thuộc về Trần Phước Trung")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.navy)
                    Text("© 2026 Trần Phước Trung. Bảo lưu mọi quyền.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.navy)
                    Text("Copyright © 2026 Trần Phước Trung. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                LessonPanel {
                    SectionTitle("Về ứng dụng")
                    Text("N2 của Trung hỗ trợ học từ vựng, Kanji, ngữ pháp, đọc hiểu và nghe hiểu theo lộ trình 35 tuần hướng đến JLPT N2 tháng 7/2027.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Ứng dụng hoạt động offline với dữ liệu bài học lưu trên iPhone.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("JLPT là tên kỳ thi của các đơn vị tổ chức kỳ thi và không hàm ý ứng dụng được họ bảo trợ hay chứng nhận.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Giới thiệu")
        .navigationBarTitleDisplayMode(.inline)
    }
}
