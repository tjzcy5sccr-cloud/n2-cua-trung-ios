import SwiftUI
import ActivityKit

/// Live Activity: thẻ học rộng ở phía dưới Lock Screen, khác với widget nhỏ cạnh đồng hồ.
/// Chỉ hoạt động khi người dùng chủ động bật, tối đa 8 giờ hoạt động (+ tối đa 4 giờ lưu trên màn hình khóa).
@available(iOS 16.1, *)
@MainActor
final class WideStudyController: ObservableObject {
    static let shared = WideStudyController()
    @Published private(set) var message: String = ""
    @Published private(set) var active: Bool = false

    private init() { active = !Activity<StudyActivityAttributes>.activities.isEmpty }

    func start(course: CourseData) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "Live Activities đang tắt trong Cài đặt iPhone."
            return
        }
        guard let word = course.vocab.randomElement() else { return }
        // Ngăn bảng học bị trùng nhiều phiên trên màn hình khóa.
        for old in Activity<StudyActivityAttributes>.activities {
            await old.end(using: nil, dismissalPolicy: .immediate)
        }
        do {
            _ = try Activity<StudyActivityAttributes>.request(
                attributes: StudyActivityAttributes(title: "N2 của Trung"),
                contentState: .init(word: word.word, reading: word.reading, meaning: word.meaning),
                pushType: nil
            )
            active = true
            message = "Đã bật bảng học rộng ở màn hình khóa."
        } catch {
            message = "Không mở được bảng học rộng: \(error.localizedDescription)"
        }
    }

    func next(course: CourseData) async {
        guard let next = course.vocab.randomElement() else { return }
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.update(using: .init(word: next.word, reading: next.reading, meaning: next.meaning))
        }
        active = !Activity<StudyActivityAttributes>.activities.isEmpty
        message = active ? "Đã thay từ cho bảng học rộng." : "Hãy bật bảng học rộng trước."
    }

    func stop() async {
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.end(using: nil, dismissalPolicy: .immediate)
        }
        active = false
        message = "Đã tắt bảng học rộng."
    }
}

@available(iOS 16.1, *)
struct WideLockScreenActivityPanel: View {
    let course: CourseData
    @StateObject private var controller = WideStudyController.shared

    var body: some View {
        LessonPanel {
            SectionTitle("Bảng học rộng trên màn hình khóa", subtitle: "Live Activity lớn, có nền xanh và chữ sáng")
            Text("Widget ở cạnh đồng hồ có kích cỡ cố định. Bảng Live Activity nằm phía dưới màn hình khóa và rộng hơn; bạn cần bật thủ công khi muốn ôn nhanh.")
                .font(.subheadline).foregroundStyle(.secondary)
            if controller.active {
                MainButton(title: "Đổi ngay sang từ ngẫu nhiên", symbol: "shuffle", color: Palette.teal) {
                    Task { await controller.next(course: course) }
                }
                MainButton(title: "Dừng bảng học rộng", symbol: "xmark.circle", color: Palette.navy) {
                    Task { await controller.stop() }
                }
            } else {
                MainButton(title: "Bật bảng học rộng", symbol: "rectangle.expand.vertical", color: Palette.teal) {
                    Task { await controller.start(course: course) }
                }
            }
            Text("Live Activity không thể tự đổi từ mỗi lần mở khóa; chỉ thay khi app cập nhật nó. iOS tự kết thúc phiên sau tối đa 8 giờ.")
                .font(.caption).foregroundStyle(.secondary)
            if !controller.message.isEmpty {
                Text(controller.message).font(.caption).foregroundStyle(Palette.teal)
            }
        }
    }
}