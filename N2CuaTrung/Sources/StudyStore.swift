import Foundation
import SwiftUI
import AVFoundation

final class StudyStore: ObservableObject {
    @Published var course: CourseData
    @Published var installedPacks: [CoursePack]
    @Published private(set) var selectedSeries: LearningSeries
    @Published var contentRevision = UUID()
    @Published private(set) var saved: SavedProgress
    private let key = "N2CuaTrung.progress.v1"
    private let seriesPreferenceKey = "N2CuaTrung.activeStudySeries.v1"

    init() {
        let packs = CoursePackManager.allAvailablePacks()
        let storedSeries = UserDefaults.standard.string(forKey: "N2CuaTrung.activeStudySeries.v1") ?? "all"
        let series = LearningSeries(rawValue: storedSeries) ?? .all
        self.installedPacks = packs
        self.selectedSeries = series
        self.course = CoursePackManager.course(for: series, packs: packs)
        if let bytes = UserDefaults.standard.data(forKey: key),
           let model = try? JSONDecoder().decode(SavedProgress.self, from: bytes) {
            self.saved = model
        } else {
            self.saved = SavedProgress()
        }
    }

    /// Mọi tab đều quan sát StudyStore.course nên cập nhật cùng lúc khi đổi bộ.
    /// Lịch sử ôn vẫn ở UserDefaults và giữ nguyên các ID gốc.
    func selectSeries(_ series: LearningSeries) {
        guard series != selectedSeries else { return }
        JapaneseVoice.shared.stop()
        selectedSeries = series
        UserDefaults.standard.set(series.rawValue, forKey: seriesPreferenceKey)
        course = CoursePackManager.course(for: series, packs: installedPacks)
        contentRevision = UUID()
    }

    func itemCount(for series: LearningSeries) -> Int {
        let data = CoursePackManager.course(for: series, packs: installedPacks)
        return data.vocab.count + data.grammar.count + data.kanji.count
            + data.readings.count + data.listening.count
    }

    var week: Int {
        if let week = saved.overrideWeek { return week }
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2)) ?? Date()
        let days = calendar.dateComponents([.day], from: start, to: Date()).day ?? 0
        return min(35, max(1, days / 7 + 1))
    }

    /// Mỗi giáo trình có lịch ôn riêng. Giữ nguyên khóa lịch sử từ bản ứng dụng cũ
    /// trong chế độ Tổng hợp để không mất tiến độ của người học.
    private func scopedReviewID(_ id: String) -> String {
        selectedSeries == .all ? id : "series:\(selectedSeries.rawValue):\(id)"
    }

    private var activeReviews: [ReviewRecord] {
        if selectedSeries == .all {
            return saved.reviews.filter { !$0.key.hasPrefix("series:") }.map(\.value)
        }
        let prefix = "series:\(selectedSeries.rawValue):"
        return saved.reviews.filter { $0.key.hasPrefix(prefix) }.map(\.value)
    }

    var dueCount: Int { course.vocab.filter { isDue("v:\($0.id)") && $0.week <= week }.count }
    var mastered: Int { activeReviews.filter { $0.streak >= 3 }.count }
    var reviewedCount: Int { activeReviews.count }
    var averageScore: Int {
        let filtered = selectedSeries == .all
            ? saved.tests.filter { !$0.type.hasPrefix("series:") }
            : saved.tests.filter { $0.type.hasPrefix("series:\(selectedSeries.rawValue):") }
        let earned = filtered.reduce(0) { $0 + $1.correct }
        let total = filtered.reduce(0) { $0 + $1.total }
        return total == 0 ? 0 : Int(Double(earned) * 100.0 / Double(total))
    }

    func isDue(_ id: String) -> Bool {
        guard let review = saved.reviews[scopedReviewID(id)] else { return true }
        return review.nextReview <= Date()
    }

    func review(_ id: String, known: Bool) {
        let key = scopedReviewID(id)
        let previous = saved.reviews[key]
        let streak = known ? min((previous?.streak ?? 0) + 1, 20) : 0
        let steps = [1, 3, 7, 14, 30, 60, 90]
        let interval = known ? steps[min(max(0, streak - 1), steps.count - 1)] : 1
        let date = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
        saved.reviews[key] = ReviewRecord(streak: streak, interval: interval,
                                         nextReview: date, lastReviewed: Date())
        persist()
    }

    func recordTest(correct: Int, total: Int, type: String) {
        let scopedType = selectedSeries == .all ? type : "series:\(selectedSeries.rawValue):\(type)"
        saved.tests.insert(TestRecord(correct: correct, total: total, type: scopedType), at: 0)
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
    private var synthesizer = AVSpeechSynthesizer()
    private let preferenceKey = "N2CuaTrung.japaneseVoice.v1"
    private var speechGeneration = 0
    /// Chỉ giữ lệnh phát mới nhất; hủy mọi lần phát/khởi chạy còn chờ.
    private var pendingSpeech: [AVSpeechUtterance] = []
    private var pendingSpeechWork: DispatchWorkItem?

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

    /// Tạo phiên synthesizer mới mỗi khi thay thẻ. Lệnh đang chờ của phiên trước
    /// bị vô hiệu hóa theo generation và không thể phát sau khi người dùng đã vuốt.
    private func speakSequence(_ utterances: [AVSpeechUtterance]) {
        speechGeneration += 1
        let generation = speechGeneration
        pendingSpeechWork?.cancel()
        pendingSpeechWork = nil
        pendingSpeech.removeAll()

        let previous = synthesizer
        previous.delegate = nil
        previous.stopSpeaking(at: .immediate)
        let newSynthesizer = AVSpeechSynthesizer()
        newSynthesizer.delegate = self
        synthesizer = newSynthesizer
        speaking = false

        let task = DispatchWorkItem { [weak self, weak newSynthesizer] in
            guard let self = self, let activeSynth = newSynthesizer,
                  self.speechGeneration == generation,
                  self.synthesizer === activeSynth else { return }
            for utterance in utterances {
                activeSynth.speak(utterance)
            }
        }
        pendingSpeechWork = task
        // Một khoảng nhỏ chống nhảy âm khi người dùng lướt liên tục.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: task)
    }

    func stop() {
        speechGeneration += 1
        pendingSpeechWork?.cancel()
        pendingSpeechWork = nil
        pendingSpeech.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard synthesizer === self.synthesizer else { return }
        DispatchQueue.main.async { self.speaking = true }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard synthesizer === self.synthesizer else { return }
        DispatchQueue.main.async { self.speaking = false }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speaking = false }
    }
}