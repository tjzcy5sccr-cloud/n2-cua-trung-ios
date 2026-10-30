import Foundation
import UserNotifications
import Combine

/// Nhắc ôn tự nguyện, lập lịch trên iPhone: không cần máy chủ hay Internet.
/// iOS có thể trì hoãn/ẩn thông báo theo Focus và quyền người dùng.
@MainActor
final class StudyReminders: ObservableObject {
    static let shared = StudyReminders()

    @Published private(set) var enabled: Bool
    @Published private(set) var perDay: Int
    @Published private(set) var status: String = ""

    private let center = UNUserNotificationCenter.current()
    private let keyEnabled = "N2Trung.reminders.enabled"
    private let keyCount = "N2Trung.reminders.perDay"
    private let keyStamp = "N2Trung.reminders.scheduleStamp"
    private let prefix = "N2Trung.study."

    private init() {
        enabled = UserDefaults.standard.bool(forKey: keyEnabled)
        let number = UserDefaults.standard.integer(forKey: keyCount)
        perDay = (1...4).contains(number) ? number : 2
    }

    func turnOn(using course: CourseData) async {
        let allowed = await requestPermission()
        guard allowed else {
            enabled = false
            UserDefaults.standard.set(false, forKey: keyEnabled)
            status = "iPhone chưa cho phép thông báo. Vào Cài đặt → Thông báo → N2 của Trung để bật."
            return
        }
        enabled = true
        UserDefaults.standard.set(true, forKey: keyEnabled)
        await schedule(course: course, force: true)
    }

    func turnOff() {
        enabled = false
        UserDefaults.standard.set(false, forKey: keyEnabled)
        UserDefaults.standard.removeObject(forKey: keyStamp)
        let service = center
        let ours = prefix
        service.getPendingNotificationRequests { requests in
            service.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier).filter { $0.hasPrefix(ours) })
        }
        status = "Đã tắt nhắc học."
    }

    func setFrequency(_ count: Int, using course: CourseData) async {
        perDay = min(4, max(1, count))
        UserDefaults.standard.set(perDay, forKey: keyCount)
        if enabled { await schedule(course: course, force: true) }
    }

    /// Gọi khi app mở. Lên lịch 14 ngày tới nhưng chỉ làm mới tối đa 1 lần/ngày.
    func refreshIfNeeded(using course: CourseData) async {
        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            status = "Quyền thông báo đang tắt trong cài đặt iPhone."
            return
        }
        await schedule(course: course, force: false)
    }

    private func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional { return true }
        if settings.authorizationStatus == .denied { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private func schedule(course: CourseData, force: Bool) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayString = "\(calendar.component(.year, from: today))-\(calendar.ordinality(of: .day, in: .era, for: today) ?? 0)"
        let stamp = "\(todayString):\(perDay):\(TimeZone.current.identifier)"
        if !force, UserDefaults.standard.string(forKey: keyStamp) == stamp { return }

        let existing = await center.pendingNotificationRequests()
        let ids = existing.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let vocab = course.vocab
        let kanji = course.kanji
        let grammar = course.grammar
        guard !vocab.isEmpty || !kanji.isEmpty || !grammar.isEmpty else {
            status = "Chưa có dữ liệu để nhắc học."
            return
        }

        var scheduled = 0
        // 14 x tối đa 4 = 56 lịch hẹn, không vượt ngưỡng thông báo chờ thường dùng của iOS.
        for day in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: day, to: today) else { continue }
            let daySeed = UInt64(calendar.ordinality(of: .day, in: .era, for: date) ?? day + 1)
            for slot in 0..<perDay {
                let seed = Self.mix(daySeed &+ UInt64(slot + 1) &* 0x9e3779b97f4a7c15)
                // Trải đều trong khoảng 9–21 giờ; phút ngẫu nhiên trong mỗi khoảng.
                let window = 12 * 60 / perDay
                let minuteOfDay = 9 * 60 + slot * window + Int(seed % UInt64(max(1, window)))
                let hour = minuteOfDay / 60
                let minute = minuteOfDay % 60
                guard let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date),
                      time > Date().addingTimeInterval(90) else { continue }

                let message = UNMutableNotificationContent()
                let pool = Int((seed >> 7) % 3)
                if pool == 0, !kanji.isEmpty {
                    let item = kanji[Int((seed >> 17) % UInt64(kanji.count))]
                    message.title = "☘ Kanji N2: \(item.char)"
                    message.body = "\(item.meaning) • On: \(item.on) • Kun: \(item.kun)"
                } else if pool == 1, !grammar.isEmpty {
                    let item = grammar[Int((seed >> 17) % UInt64(grammar.count))]
                    message.title = "☘ Ngữ pháp: \(item.pattern)"
                    message.body = "\(item.meaning) • \(item.example)"
                } else if !vocab.isEmpty {
                    let item = vocab[Int((seed >> 17) % UInt64(vocab.count))]
                    message.title = "☘ Từ mới: \(item.word)（\(item.reading)）"
                    message.body = "\(item.meaning) • \(item.example)"
                } else { continue }
                message.sound = .default
                message.userInfo = ["source": "n2-study", "day": day]
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: "\(prefix)\(day).\(slot)", content: message, trigger: trigger)
                do { try await center.add(request); scheduled += 1 }
                catch { status = "Không thể đặt nhắc học: \(error.localizedDescription)" }
            }
        }
        UserDefaults.standard.set(stamp, forKey: keyStamp)
        status = "Đã lên lịch \(scheduled) nhắc học ngẫu nhiên cho 14 ngày tới (9:00–21:00)."
    }

    private static func mix(_ value: UInt64) -> UInt64 {
        var x = value &+ 0x9e3779b97f4a7c15
        x = (x ^ (x >> 30)) &* 0xbf58476d1ce4e5b9
        x = (x ^ (x >> 27)) &* 0x94d049bb133111eb
        return x ^ (x >> 31)
    }
}