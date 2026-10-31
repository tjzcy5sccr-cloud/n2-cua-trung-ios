import SwiftUI
import ActivityKit
import UIKit

/// Live Activity hiển thị thẻ học trên màn hình khóa.
@available(iOS 16.1, *)
@MainActor
final class WideStudyController: ObservableObject {
    static let shared = WideStudyController()

    @Published private(set) var message = ""
    @Published private(set) var active = false
    @Published private(set) var permissionGranted = false
    @Published private(set) var isBusy = false
    @Published var rotateSeconds: Int {
        didSet { UserDefaults.standard.set(rotateSeconds, forKey: "N2LiveActivityRotation") }
    }

    private var lastChange = Date.distantPast
    private var previousWordID: String?

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "N2LiveActivityRotation")
        rotateSeconds = [0, 3, 30, 60].contains(saved) ? saved : 60
        refreshStatus()
    }

    private var runningActivities: [Activity<StudyActivityAttributes>] {
        Activity<StudyActivityAttributes>.activities.filter { activity in
            if activity.activityState == .active { return true }
            if #available(iOS 16.2, *) {
                return activity.activityState == .stale
            }
            return false
        }
    }

    /// Đồng bộ trạng thái từ hệ thống, không tin vào biến active đã lưu lâu.
    func refreshStatus() {
        let allowed = ActivityAuthorizationInfo().areActivitiesEnabled
        let running = !runningActivities.isEmpty
        if permissionGranted != allowed { permissionGranted = allowed }
        if active != running { active = running }
    }

    private func newWord(from course: CourseData) -> Vocabulary? {
        let candidates = course.vocab.filter { $0.id != previousWordID }
        guard let word = candidates.randomElement() ?? course.vocab.randomElement() else { return nil }
        previousWordID = word.id
        lastChange = Date()
        return word
    }

    func tick(course: CourseData) async {
        guard !isBusy else { return }
        refreshStatus()
        guard active, rotateSeconds > 0,
              Date().timeIntervalSince(lastChange) >= Double(rotateSeconds) else { return }
        await next(course: course)
    }

    func start(course: CourseData) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        refreshStatus()
        guard permissionGranted else {
            message = "iPhone đang chặn Hoạt động trực tiếp. Hãy mở Cài đặt của N2 của Trung và bật Live Activities."
            return
        }
        guard let word = newWord(from: course) else {
            message = "Không tìm thấy từ vựng để bắt đầu Live Activity."
            return
        }

        // Kể cả khi giao diện báo đang chạy, vẫn cho phép bật lại sau lỗi/phiên cũ.
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.end(using: nil, dismissalPolicy: .immediate)
        }
        do {
            let activity = try Activity<StudyActivityAttributes>.request(
                attributes: StudyActivityAttributes(title: "N2 của Trung"),
                contentState: .init(word: word.word, reading: word.reading,
                                    meaning: word.displayMeaning),
                pushType: nil
            )
            active = true
            message = "Đã tạo Live Activity (\(String(activity.id.prefix(8)))). Khóa iPhone để xem bảng học phía dưới đồng hồ."
        } catch {
            refreshStatus()
            message = "Không thể bật Live Activity: \(error.localizedDescription)"
        }
    }

    func next(course: CourseData) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        refreshStatus()
        let running = runningActivities
        guard !running.isEmpty else {
            message = "Không có Live Activity đang hoạt động. Nhấn Bật / Khởi động lại."
            return
        }
        guard let word = newWord(from: course) else {
            message = "Kho từ vựng đang trống."
            return
        }
        for activity in running {
            await activity.update(using: .init(word: word.word, reading: word.reading,
                                                meaning: word.displayMeaning))
        }
        refreshStatus()
        message = active ? "Đã gửi từ mới tới màn hình khóa. iOS có thể cập nhật chậm." :
                           "Phiên Live Activity đã hết hạn. Hãy khởi động lại."
    }

    func stop() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.end(using: nil, dismissalPolicy: .immediate)
        }
        refreshStatus()
        active = false
        message = "Đã dừng bảng Live trên màn hình khóa."
    }
}

@available(iOS 16.1, *)
struct WideLockScreenActivityPanel: View {
    let course: CourseData
    @StateObject private var controller = WideStudyController.shared
    @Environment(\.openURL) private var openURL
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        LessonPanel {
            SectionTitle("Live màn hình khóa", subtitle: "Từ vựng lớn, cách đọc và nghĩa tiếng Việt")
            Text("Bảng Live xuất hiện dưới đồng hồ trên Màn hình khóa sau khi bạn bật. Nếu từng bật nhưng không thấy, dùng nút Khởi động lại.")
                .font(.subheadline).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: controller.permissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(controller.permissionGranted ? Palette.teal : Palette.orange)
                Text(controller.permissionGranted ?
                     (controller.active ? "Đang hoạt động trên iOS" : "Đã cho phép • Chưa bật Live") :
                     "Live Activities chưa được cho phép")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tự động đổi từ (Live Activity)")
                    .font(.subheadline.weight(.semibold))
                Picker("Đổi từ tự động", selection: $controller.rotateSeconds) {
                    Text("Tắt").tag(0)
                    Text("3 giây").tag(3)
                    Text("30 giây").tag(30)
                    Text("60 giây").tag(60)
                }
                .pickerStyle(.segmented)
            }
            Text("Thử đổi mỗi 3 giây khi app đang mở. Khi khóa màn hình hoặc chạy nền, iOS giới hạn tốc độ cập nhật Live Activity; không thể bảo đảm mỗi 3 giây.")
                .font(.caption).foregroundStyle(.secondary)

            // Nút này luôn khả dụng, kể cả sau khi iOS hủy phiên mà trạng thái cũ chưa đồng bộ.
            MainButton(title: controller.active ? "Khởi động lại Live Activity" : "Bật Live trên màn hình khóa",
                       symbol: "rectangle.expand.vertical", color: Palette.teal) {
                Task { await controller.start(course: course) }
            }
            .disabled(controller.isBusy)

            if controller.active {
                MainButton(title: "Đổi ngay sang từ ngẫu nhiên", symbol: "shuffle", color: Palette.blue) {
                    Task { await controller.next(course: course) }
                }
                .disabled(controller.isBusy)
                MainButton(title: "Dừng bảng học Live", symbol: "xmark.circle", color: Palette.navy) {
                    Task { await controller.stop() }
                }
                .disabled(controller.isBusy)
            }

            if !controller.permissionGranted {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Mở Cài đặt ứng dụng để bật Live Activities", systemImage: "gearshape.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }

            if !controller.message.isEmpty {
                Text(controller.message)
                    .font(.caption)
                    .foregroundStyle(Palette.navy)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { controller.refreshStatus() }
        .onReceive(ticker) { _ in
            Task { await controller.tick(course: course) }
        }
    }
}
