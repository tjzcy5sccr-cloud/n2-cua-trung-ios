import Foundation
import SwiftUI
import AVFoundation

final class StudyStore: ObservableObject {
    @Published var course: CourseData
    @Published var installedPacks: [CoursePack]
    @Published private(set) var saved: SavedProgress
    private let key = "N2CuaTrung.progress.v1"

    init() {
        let packs = CoursePackManager.readInstalled()
        self.installedPacks = packs
        self.course = CoursePackManager.mergedCourse(packs: packs)
        if let bytes = UserDefaults.standard.data(forKey: key),
           let model = try? JSONDecoder().decode(SavedProgress.self, from: bytes) {
            self.saved = model
        } else {
            self.saved = SavedProgress()
        }
    }

    var week: Int {
        if let week = saved.overrideWeek { return week }
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2)) ?? Date()
        let days = calendar.dateComponents([.day], from: start, to: Date()).day ?? 0
        return min(35, max(1, days / 7 + 1))
    }

    var dueCount: Int { course.vocab.filter { isDue("v:\($0.id)") && $0.week <= week }.count }
    var mastered: Int { saved.reviews.values.filter { $0.streak >= 3 }.count }
    var reviewedCount: Int { saved.reviews.count }
    var averageScore: Int {
        let earned = saved.tests.reduce(0) { $0 + $1.correct }
        let total = saved.tests.reduce(0) { $0 + $1.total }
        return total == 0 ? 0 : Int(Double(earned) * 100.0 / Double(total))
    }

    func isDue(_ id: String) -> Bool {
        guard let review = saved.reviews[id] else { return true }
        return review.nextReview <= Date()
    }

    func review(_ id: String, known: Bool) {
        let previous = saved.reviews[id]
        let streak = known ? min((previous?.streak ?? 0) + 1, 20) : 0
        let steps = [1, 3, 7, 14, 30, 60, 90]
        let interval = known ? steps[min(max(0, streak - 1), steps.count - 1)] : 1
        let date = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
        saved.reviews[id] = ReviewRecord(streak: streak, interval: interval,
                                         nextReview: date, lastReviewed: Date())
        persist()
    }

    func recordTest(correct: Int, total: Int, type: String) {
        saved.tests.insert(TestRecord(correct: correct, total: total, type: type), at: 0)
        if saved.tests.count > 100 { saved.tests = Array(saved.tests.prefix(100)) }
        persist()
    }

    func selectWeek(_ week: Int?) {
        saved.overrideWeek = week
        persist()
    }

    func exportJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(saved)
    }

    func importJSON(_ bytes: Data) throws {
        let decoded = try JSONDecoder().decode(SavedProgress.self, from: bytes)
        saved = decoded
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Sử dụng giọng Nhật sẵn có trên iOS; không yêu cầu Internet hay server audio.
/// AudioSession `.playback` khắc phục việc máy để im lặng khiến bài nghe không phát.
final class JapaneseVoice: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = JapaneseVoice()
    private let synthesizer = AVSpeechSynthesizer()
    @Published private(set) var speaking = false
    @Published private(set) var lastError: String?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Float = 0.46) {
        let cleaned = text
            .replacingOccurrences(of: "女：", with: "")
            .replacingOccurrences(of: "男：", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            lastError = "Không tìm thấy văn bản tiếng Nhật để phát."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            lastError = nil
        } catch {
            lastError = "Không kích hoạt được loa: \(error.localizedDescription). Hãy kiểm tra loa, âm lượng và thiết bị Bluetooth."
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: cleaned)
        // Nếu chưa cài giọng ja-JP, iOS sẽ dùng giọng Nhật có sẵn khi phù hợp.
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = min(0.62, max(0.35, rate))
        utterance.pitchMultiplier = 1.0
        // Đưa vào vòng sự kiện kế tiếp, tránh lỗi stop+speak cùng một nhịp.
        DispatchQueue.main.async { [weak self] in self?.synthesizer.speak(utterance) }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speaking = true }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speaking = false }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speaking = false }
    }
}