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

/// Ưu tiên các giọng tiếng Nhật chất lượng Premium/Enhanced đã được người dùng cài sẵn.
/// TTS chạy trên thiết bị và hoạt động offline. Không phân phối trái phép audio của đơn vị khác.
final class JapaneseVoice: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = JapaneseVoice()
    private let synthesizer = AVSpeechSynthesizer()
    private let preferenceKey = "N2CuaTrung.japaneseVoice.v1"
    private var speechGeneration = 0
    @Published private(set) var speaking = false
    @Published private(set) var lastError: String?
    @Published var voiceIdentifier: String = "" {
        didSet { UserDefaults.standard.set(voiceIdentifier, forKey: preferenceKey) }
    }

    private override init() {
        super.init()
        voiceIdentifier = UserDefaults.standard.string(forKey: preferenceKey) ?? ""
        synthesizer.delegate = self
    }

    var installedVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("ja") }
            .sorted {
                if $0.quality.rawValue != $1.quality.rawValue {
                    return $0.quality.rawValue > $1.quality.rawValue
                }
                return $0.name < $1.name
            }
    }

    func qualityName(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Tiêu chuẩn"
        }
    }

    private func japaneseVoice(gender: AVSpeechSynthesisVoiceGender? = nil) -> AVSpeechSynthesisVoice? {
        let options = installedVoices
        if let chosen = options.first(where: { $0.identifier == voiceIdentifier }) {
            if gender == nil || chosen.gender == gender { return chosen }
        }
        if let gender = gender, let alternative = options.first(where: { $0.gender == gender }) {
            return alternative
        }
        return options.first ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }

    private func ready() -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            lastError = nil
            return true
        } catch {
            lastError = "Không phát được âm thanh: \(error.localizedDescription). Kiểm tra âm lượng và Bluetooth."
            return false
        }
    }

    func speak(_ text: String, rate: Float = 0.47) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            lastError = "Không có nội dung tiếng Nhật để phát."
            return
        }
        guard ready() else { return }
        let utterance = makeUtterance(clean, rate: rate, gender: nil)
        speakSequence([utterance])
    }

    /// Mỗi dòng 男：và 女：được đọc bằng một giọng khác nhau khi thiết bị có sẵn.
    func speakConversation(_ text: String, rate: Float = 0.47) {
        let split = text
            .replacingOccurrences(of: "男：", with: "\n男：")
            .replacingOccurrences(of: "女：", with: "\n女：")
            .replacingOccurrences(of: "男:", with: "\n男:")
            .replacingOccurrences(of: "女:", with: "\n女:")
        var utterances: [AVSpeechUtterance] = []
        for line in split.components(separatedBy: .newlines) {
            var clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty { continue }
            var gender: AVSpeechSynthesisVoiceGender? = nil
            if clean.hasPrefix("女：") || clean.hasPrefix("女:") {
                gender = .female
                clean = String(clean.dropFirst(2))
            } else if clean.hasPrefix("男：") || clean.hasPrefix("男:") {
                gender = .male
                clean = String(clean.dropFirst(2))
            }
            if !clean.trimmingCharacters(in: .whitespaces).isEmpty {
                utterances.append(makeUtterance(clean, rate: rate, gender: gender))
            }
        }
        if utterances.isEmpty { speak(text, rate: rate); return }
        guard ready() else { return }
        speakSequence(utterances)
    }

    private func makeUtterance(_ text: String, rate: Float,
                               gender: AVSpeechSynthesisVoiceGender?) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = japaneseVoice(gender: gender)
        utterance.rate = min(0.59, max(0.36, rate))
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.postUtteranceDelay = 0.22
        return utterance
    }

    private func speakSequence(_ utterances: [AVSpeechUtterance]) {
        speechGeneration += 1
        let generation = speechGeneration
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.speechGeneration == generation else { return }
            for utterance in utterances { self.synthesizer.speak(utterance) }
        }
    }

    func stop() {
        speechGeneration += 1
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