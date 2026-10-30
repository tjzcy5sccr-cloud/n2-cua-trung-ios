import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: StudyStore
    private var thisWeek: WeeklyPlan? {
        store.course.weeks.first { $0.n == store.week }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Pill(text: "JLPT N2 • 2027", color: .white)
                        Spacer()
                        Image(systemName: "character.book.closed.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Text("N2 của Trung")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("Mỗi ngày một bước đến N2.")
                        .font(.subheadline).foregroundColor(.white.opacity(0.82))
                    HStack {
                        Label("Tuần \(store.week)/35", systemImage: "calendar")
                        Spacer()
                        Text("Mục tiêu: 07/2027")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                }
                .padding(22)
                .background(
                    LinearGradient(colors: [Palette.navy, Palette.blue],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22)
                )

                HStack(spacing: 10) {
                    StatBox(number: "\(store.dueCount)", label: "Thẻ cần ôn", symbol: "rectangle.stack")
                    StatBox(number: "\(store.mastered)", label: "Đã nhớ vững", symbol: "checkmark.seal")
                    StatBox(number: "\(store.saved.tests.count)", label: "Bài đã làm", symbol: "pencil.line")
                }

                if let item = thisWeek {
                    LessonPanel {
                        HStack {
                            SectionTitle("Trọng tâm tuần \(store.week)", subtitle: item.date)
                            Image(systemName: "flag.checkered").foregroundColor(Palette.orange)
                        }
                        Text(item.focus).font(.body.weight(.semibold)).foregroundColor(Palette.navy)
                        Text("Bối cảnh: \(item.context)")
                            .font(.subheadline).foregroundColor(.secondary)
                        Text("Kiểm tra: \(item.exam)")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }

                LessonPanel {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.fill").font(.title2).foregroundColor(.green)
                        SectionTitle("Từ vựng trên màn hình khóa", subtitle: "Widget N2 của Trung tự đổi từ mỗi giờ khi iOS cho phép")
                    }
                    Text("Chạm giữ màn hình khóa → Tùy chỉnh → Thêm tiện ích → N2 của Trung. Mở lại app sẽ yêu cầu widget làm mới, nhưng iOS không đảm bảo đổi từ sau từng lần bật/tắt màn hình.")
                        .font(.caption).foregroundColor(.secondary)
                }
                SectionTitle("Bắt đầu học", subtitle: "90 phút/ngày • 6 ngày/tuần")
                NavigationLink {
                    FlashcardDeckView()
                } label: {
                    ActionTile(icon: "rectangle.on.rectangle", color: Palette.teal,
                               title: "Từ vựng và flashcard", detail: "Ôn cách quãng 1–3–7–14 ngày")
                }.buttonStyle(.plain)
                NavigationLink {
                    GrammarListView()
                } label: {
                    ActionTile(icon: "text.book.closed", color: Palette.blue,
                               title: "Ngữ pháp có ví dụ", detail: "Giải thích Nhật – Việt, phát âm")
                }.buttonStyle(.plain)
                NavigationLink {
                    ExamStartView()
                } label: {
                    ActionTile(icon: "checkmark.circle", color: Palette.orange,
                               title: "Luyện đề tổng hợp", detail: "20 câu • Đọc, nghe, từ, ngữ pháp, Kanji")
                }.buttonStyle(.plain)
                NavigationLink {
                    AboutView()
                } label: {
                    VStack(spacing: 5) {
                        Text("Ứng dụng học JLPT N2 do Trần Phước Trung tạo")
                            .font(.caption.weight(.medium))
                        Text("Bản quyền thuộc về Trần Phước Trung")
                            .font(.caption2)
                        Text("© 2026 Trần Phước Trung. Bảo lưu mọi quyền.")
                            .font(.caption2)
                        Text("Giới thiệu & bản quyền")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Palette.blue)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Học hôm nay")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    AboutView()
                } label: {
                    Image(systemName: "info.circle")
                        .accessibilityLabel("Giới thiệu ứng dụng và bản quyền")
                }
            }
        }
    }
}

struct ActionTile: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 45, height: 45)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.bold)).foregroundColor(Palette.navy)
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.secondary)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}