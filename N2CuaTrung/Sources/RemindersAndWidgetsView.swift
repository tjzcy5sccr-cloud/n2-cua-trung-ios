import SwiftUI
import WidgetKit

struct RemindersAndWidgetsView: View {
    @EnvironmentObject private var store: StudyStore
    @StateObject private var reminders = StudyReminders.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LessonPanel {
                    SectionTitle("Thông báo nhắc học", subtitle: "Kanji, ngữ pháp và từ vựng xuất hiện vào giờ ngẫu nhiên")
                    Toggle("Bật nhắc học trong ngày", isOn: Binding(
                        get: { reminders.enabled },
                        set: { value in
                            if value { Task { await reminders.turnOn(using: store.course) } }
                            else { reminders.turnOff() }
                        }
                    ))
                    .tint(Palette.teal)
                    Picker("Số lần mỗi ngày", selection: Binding(
                        get: { reminders.perDay },
                        set: { value in Task { await reminders.setFrequency(value, using: store.course) } }
                    )) {
                        Text("1 lần").tag(1)
                        Text("2 lần").tag(2)
                        Text("3 lần").tag(3)
                        Text("4 lần").tag(4)
                    }.pickerStyle(.segmented)
                    Text("Giờ thông báo thay đổi trong khoảng 09:00–21:00. iOS có thể hoãn hoặc ẩn khi bật chế độ Tập trung.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !reminders.status.isEmpty {
                        Text(reminders.status).font(.footnote).foregroundStyle(Palette.teal)
                    }
                }
                LessonPanel {
                    SectionTitle("Widget từ vựng", subtitle: "Chữ lớn, dễ đọc, không cần Internet")
                    HStack(spacing: 12) {
                        Image(systemName: "leaf.fill")
                            .font(.largeTitle).foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Widget ngang (Medium)").font(.headline)
                            Text("Đặt trên Màn hình chính để chiếm trọn một hàng.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Text("Widget thay từ theo lịch khoảng 15 phút/lần, có thể chậm hơn do iOS. Khi mở ứng dụng, app sẽ yêu cầu làm mới; không thể cưỡng bức thay từ mỗi lần mở khóa.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    MainButton(title: "Yêu cầu đổi từ trên widget", symbol: "arrow.triangle.2.circlepath", color: Palette.teal) {
                        WidgetCenter.shared.reloadTimelines(ofKind: "N2TrungWordWidget")
                    }
                    Text("Widget ở màn hình khóa do iOS giới hạn kích cỡ và thường bỏ nền màu. Chọn widget ngang trên Màn hình chính để có nền xanh đậm và chữ trắng rõ ràng.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if #available(iOS 16.1, *) {
                    WideLockScreenActivityPanel(course: store.course)
                }
            }.padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Nhắc học & Widget")
    }
}