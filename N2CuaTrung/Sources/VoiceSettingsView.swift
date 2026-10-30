import SwiftUI
import AVFoundation

struct VoiceSettingsView: View {
    @ObservedObject private var voice = JapaneseVoice.shared
    @State private var sample = "日本語の勉強を続けましょう。毎日少しずつ、上達していきます。"

    var body: some View {
        Form {
            Section("Giọng Nhật tự nhiên") {
                Text("Ưu tiên giọng Premium hoặc Enhanced đã tải sẵn trên iPhone; không gửi văn bản lên Internet.")
                    .font(.subheadline)
                Picker("Chọn giọng phát âm", selection: $voice.voiceIdentifier) {
                    Text("Tự chọn giọng chất lượng cao nhất").tag("")
                    ForEach(voice.installedVoices, id: \.identifier) { item in
                        Text("\(item.name) • \(voice.qualityName(item))").tag(item.identifier)
                    }
                }
                .pickerStyle(.navigationLink)
                if voice.installedVoices.isEmpty {
                    Text("Chưa thấy giọng Nhật ja-JP trên thiết bị.").foregroundColor(.orange)
                }
                Button("Nghe thử") { voice.speak(sample) }
                Button("Dừng") { voice.stop() }
            }
            Section("Tải giọng chất lượng cao") {
                Text("Trên iPhone, mở Cài đặt → Trợ năng → Nội dung được đọc → Giọng nói → Tiếng Nhật, chọn giọng chất lượng cao (nếu khả dụng). Sau khi tải, ứng dụng phát âm offline.")
                    .font(.subheadline)
                Text("Đoạn hội thoại có nhãn 男：/女： sẽ thử phát bằng hai giọng Nhật khác nhau nếu thiết bị có đủ giọng.")
                    .font(.caption)
            }
        }
        .navigationTitle("Giọng đọc tiếng Nhật")
    }
}