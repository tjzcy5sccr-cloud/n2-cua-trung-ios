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
    @Published var rotateSeconds: Int {
        didSet { UserDefaults.standard.set(rotateSeconds, forKey: "N2LiveActivityRotation") }
    }
    private var lastChange = Date.distantPast
    private var previousWordID: String?

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "N2LiveActivityRotation")
        rotateSeconds = [0, 30, 60].contains(saved) ? saved : 60
        active = !Activity<StudyActivityAttributes>.activities.isEmpty
    }

    /// Không lặp lại ngay một từ, ưu tiên bộ từ đa dạng.
    private func newWord(from course: CourseData) -> Vocabulary? {
        let candidates = course.vocab.filter { $0.id != previousWordID }
        guard let word = candidates.randomElement() ?? course.vocab.randomElement() else { return nil }
        previousWordID = word.id
        lastChange = Date()
        return word
    }

    func tick(course: CourseData) async {
        guard active, rotateSeconds > 0,
              Date().timeIntervalSince(lastChange) >= Double(rotateSeconds) else { return }
        await next(course: course)
    }

    func start(course: CourseData) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            message = "Live Activities đang tắt trong Cài đặt iPhone."
            return
        }
        guard let word = newWord(from: course) else { return }
        // Ngăn bảng học bị trùng nhiều phiên trên màn hình khóa.
        for old in Activity<StudyActivityAttributes>.activities {
            await old.end(using: nil, dismissalPolicy: .immediate)
        }
        do {
            _ = try Activity<StudyActivityAttributes>.request(
                attributes: StudyActivityAttributes(title: "N2 của Trung"),
                contentState: .init(word: word.word, reading: word.reading, meaning: word.displayMeaning),
                pushType: nil
            )
            active = true
            message = "Đã bật bảng học rộng ở màn hình khóa."
        } catch {
            message = "Không mở được bảng học rộng: \(error.localizedDescription)"
        }
    }

    func next(course: CourseData) async {
        guard let next = newWord(from: course) else { return }
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.update(using: .init(word: next.word, reading: next.reading, meaning: next.displayMeaning))
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
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        LessonPanel {
            SectionTitle("Bảng học rộng trên màn hình khóa", subtitle: "Live Activity lớn, có nền xanh và chữ sáng")
            Text("Widget ở cạnh đồng hồ có kích cỡ cố định. Bảng Live Activity nằm phía dưới màn hình khóa và rộng hơn; bạn cần bật thủ công khi muốn ôn nhanh.")
                .font(.subheadline).foregroundStyle(.secondary)
            Picker("Đổi từ tự động", selection: $controller.rotateSeconds) {
                Text("Tắt").tag(0)
                Text("30 giây").tag(30)
                Text("60 giây").tag(60)
            }
            .pickerStyle(.segmented)
            Text("30/60 giây áp dụng khi ứng dụng đang mở. Sau khi khóa màn hình, iOS có thể tạm dừng app và không bảo đảm làm mới Live Activity theo chu kỳ.")
                .font(.caption).foregroundStyle(.secondary)
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
            Text("Khi quay lại ứng dụng, thẻ được kiểm tra và làm mới. Không thể tự đổi liên tục mỗi 30 giây khi iPhone đã khóa mà không có cơ chế cập nhật được iOS cho phép.")
                .font(.caption).foregroundStyle(.secondary)
            if !controller.message.isEmpty {
                Text(controller.message).font(.caption).foregroundStyle(Palette.teal)
            }
        }
        .onReceive(ticker) { _ in
            Task { await controller.tick(course: course) }
        }
    }
}