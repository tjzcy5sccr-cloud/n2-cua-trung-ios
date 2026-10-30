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
                }

                NavigationLink {
                    DataLicensesView()
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Thông tin pháp lý và giấy phép dữ liệu")
                            .font(.caption)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
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

/// Thông báo bắt buộc cho dữ liệu bên thứ ba theo CC BY-SA 4.0.
/// Đặt tại trang pháp lý riêng để không ảnh hưởng giao diện học.
private struct DataLicensesView: View {
    var body: some View {
        List {
            Section("Quyền tác giả ứng dụng") {
                Text("© 2026 Trần Phước Trung. Bảo lưu mọi quyền đối với mã nguồn và nội dung tự biên soạn.")
            }
            Section("Giấy phép dữ liệu được sử dụng") {
                Text("Bộ dữ liệu N2 mở rộng có nội dung biên soạn từ OpenJLPT, JMdict/KANJIDIC2 (EDRDG), Jonathan Waller và Tatoeba. Dữ liệu được chia sẻ theo giấy phép tương ứng; phần phái sinh OpenJLPT tuân thủ CC BY-SA 4.0.")
                Link("OpenJLPT và thông báo nguồn", destination: URL(string: "https://github.com/evanclan/OpenJLPT/blob/main/NOTICE.md")!)
                Link("CC BY-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                Text("Ghi công nguồn dữ liệu Nhật–Việt mở: Bunchaway (CC BY-SA 4.0). Các nội dung đang hiệu đính được quản lý riêng trong mã nguồn dự án.")
                    .font(.caption)
                Link("Từ điển Nhật–Việt mở · Bunchaway", destination: URL(string: "https://github.com/bunchaway/tu-dien-nhat-viet")!)
                Text("Mazii, Jdict, Kanji.vn và các nguồn học tiếng Nhật tại Việt Nam được dùng để tra cứu, đối chiếu thủ công; ứng dụng không sao chép nguyên kho của các trang này.")
                    .font(.caption)
                Text("Các nguồn gốc giữ nguyên quyền tác giả của họ. Dữ liệu mở không chuyển thành sở hữu độc quyền của tác giả ứng dụng.")
                    .font(.caption)
            }
        }
        .navigationTitle("Giấy phép dữ liệu")
    }
}