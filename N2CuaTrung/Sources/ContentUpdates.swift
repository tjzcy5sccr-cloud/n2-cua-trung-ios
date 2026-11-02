import Foundation

/// Gói học độc lập, không làm thay đổi dữ liệu tiến độ đã lưu trên thiết bị.
/// ID của từng thẻ phải ổn định qua các lần cập nhật để giữ lịch ôn tập.
struct CoursePack: Decodable, Identifiable {
    let id: String
    let version: Int
    let title: String
    /// nil = gói gốc dùng trong chế độ Tổng hợp. Giá trị khác = bộ học riêng.
    let seriesId: String?
    let vocab: [Vocabulary]?
    let grammar: [Grammar]?
    let kanji: [Kanji]?
    let readings: [ReadingLesson]?
    let listening: [ListeningLesson]?

    var itemCount: Int {
        let a = vocab?.count ?? 0
        let b = grammar?.count ?? 0
        let c = kanji?.count ?? 0
        let d = readings?.count ?? 0
        let e = listening?.count ?? 0
        return a + b + c + d + e
    }
}

private struct CourseManifest: Decodable {
    let schemaVersion: Int
    let packs: [RemoteCoursePack]
}

private struct RemoteCoursePack: Decodable {
    let id: String
    let version: Int
    let url: String
}

enum CoursePackError: LocalizedError {
    case invalidIdentifier
    case invalidData(String)
    case tooLarge
    case oldVersion
    case invalidSource
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier: return "Mã gói không hợp lệ."
        case .invalidData(let detail): return "Dữ liệu bài học lỗi: \(detail)"
        case .tooLarge: return "Gói học vượt quá 8 MB. Hãy chia thành nhiều gói."
        case .oldVersion: return "Gói này đã được cài hoặc phiên bản cũ hơn."
        case .invalidSource: return "Nguồn cập nhật không được phép."
        case .serverError: return "Không thể tải dữ liệu mới từ GitHub."
        }
    }
}

enum CoursePackManager {
    private static let maxBytes = 8 * 1024 * 1024
    private static let directoryName = "N2CoursePacks"

    private static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    static func readInstalled() -> [CoursePack] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder,
            includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> CoursePack? in
                guard let bytes = try? Data(contentsOf: url),
                      let pack = try? validate(bytes) else { return nil }
                return pack
            }
            .sorted { $0.id < $1.id }
    }

    /// Hai gói N2 đi kèm IPA, học offline ngay khi cài mà không cần bấm cập nhật.
    static func bundledPacks() -> [CoursePack] {
        (["n2-expansion-01", "openjlpt-n2-core", "vn26-original-practice-01", "n2-reading-listening-02"] +
         LearningSeries.allCases.compactMap(\.packFilename)).compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? validate(data)
        }
    }

    /// The legacy Sou Matome pack has no page-level provenance to the
    /// user's books. Keep its JSON intact for possible future source review,
    /// but never present it as an approved lesson of the book-only series.
    /// The two private reviewed packs have source-linked PDFs and quizzes.
    private static func bookOnlyEligiblePacks(_ packs: [CoursePack]) -> [CoursePack] {
        let approvedBookPackIDs: Set<String> = [
            "sou-matome-personal-reviewed",
            "sou-matome-personal-exercises"
        ]
        return packs.filter { pack in
            pack.seriesId != LearningSeries.souMatome.rawValue ||
            approvedBookPackIDs.contains(pack.id)
        }
    }

    /// Bản mới hơn được ưu tiên. Không mất lịch ôn vì thẻ dùng ID ổn định.
    static func allAvailablePacks() -> [CoursePack] {
        var byID: [String: CoursePack] = [:]
        for pack in bundledPacks() + readInstalled() {
            if let old = byID[pack.id], old.version >= pack.version { continue }
            byID[pack.id] = pack
        }
        return byID.values.sorted { $0.id < $1.id }
    }

    static func mergedCourse(packs: [CoursePack]) -> CourseData {
        let packs = bookOnlyEligiblePacks(packs)
        let original = CourseData.load()
        return CourseData(
            // Dữ liệu gốc vẫn ở GitHub; chỉ nội dung được duyệt đi vào màn học.
            vocab: merge(original.vocab, packs.flatMap { $0.vocab ?? [] })
                .filter { $0.isApprovedForStudy },
            grammar: merge(original.grammar, packs.flatMap { $0.grammar ?? [] })
                .filter { $0.isApprovedForStudy },
            kanji: merge(original.kanji, packs.flatMap { $0.kanji ?? [] })
                .filter { $0.isApprovedForStudy },
            readings: merge(original.readings, packs.flatMap { $0.readings ?? [] }),
            listening: merge(original.listening, packs.flatMap { $0.listening ?? [] }),
            weeks: original.weeks
        )
    }

    /// Tổng hợp lấy nguyên dữ liệu app cũ và mọi gói; chọn một series chỉ đọc
    /// dữ liệu mang seriesId đó. Không tự mượn dữ liệu bộ khác khi series rỗng.
    static func course(for series: LearningSeries, packs: [CoursePack]) -> CourseData {
        if series == .all { return mergedCourse(packs: packs) }
        let selected = bookOnlyEligiblePacks(packs)
            .filter { $0.seriesId == series.rawValue }
        let weeks = CourseData.load().weeks
        return CourseData(
            vocab: merge([], selected.flatMap { $0.vocab ?? [] })
                .filter { $0.isApprovedForStudy },
            grammar: merge([], selected.flatMap { $0.grammar ?? [] })
                .filter { $0.isApprovedForStudy },
            kanji: merge([], selected.flatMap { $0.kanji ?? [] })
                .filter { $0.isApprovedForStudy },
            readings: merge([], selected.flatMap { $0.readings ?? [] }),
            listening: merge([], selected.flatMap { $0.listening ?? [] }),
            weeks: weeks
        )
    }

    private static func merge<T: Identifiable>(_ base: [T], _ additions: [T]) -> [T]
        where T.ID == String {
        var items = base
        var indices = Dictionary(uniqueKeysWithValues: base.enumerated().map { ($0.element.id, $0.offset) })
        for entry in additions {
            if let index = indices[entry.id] {
                items[index] = entry
            } else {
                indices[entry.id] = items.count
                items.append(entry)
            }
        }
        return items
    }

    static func validate(_ bytes: Data) throws -> CoursePack {
        guard bytes.count <= maxBytes else { throw CoursePackError.tooLarge }
        let pack: CoursePack
        do { pack = try JSONDecoder().decode(CoursePack.self, from: bytes) }
        catch { throw CoursePackError.invalidData(error.localizedDescription) }

        guard pack.id.range(of: "^[a-zA-Z0-9_-]{1,64}$", options: .regularExpression) != nil else {
            throw CoursePackError.invalidIdentifier
        }
        if let seriesID = pack.seriesId,
           !LearningSeries.allCases.contains(where: { $0 != .all && $0.rawValue == seriesID }) {
            throw CoursePackError.invalidData("Bộ dữ liệu không có mã series hợp lệ.")
        }
        guard pack.version > 0, !pack.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              pack.itemCount > 0, pack.itemCount <= 15_000 else {
            throw CoursePackError.invalidData("Thiếu tên, phiên bản hoặc nội dung bài học.")
        }
        func unique(_ ids: [String]) -> Bool {
            Set(ids).count == ids.count && ids.allSatisfy { !$0.isEmpty }
        }
        guard unique((pack.vocab ?? []).map(\.id)),
              unique((pack.grammar ?? []).map(\.id)),
              unique((pack.kanji ?? []).map(\.id)),
              unique((pack.readings ?? []).map(\.id)),
              unique((pack.listening ?? []).map(\.id)) else {
            throw CoursePackError.invalidData("Mã bài học bị trùng trong một nhóm.")
        }
        guard (pack.vocab ?? []).allSatisfy({ (1...35).contains($0.week) }),
              (pack.grammar ?? []).allSatisfy({ (1...35).contains($0.week) }),
              (pack.readings ?? []).allSatisfy({ $0.choices.count >= 2 && $0.choices.indices.contains($0.answer) }),
              (pack.listening ?? []).allSatisfy({ $0.choices.count >= 2 && $0.choices.indices.contains($0.answer) }) else {
            throw CoursePackError.invalidData("Tuần học hoặc đáp án không hợp lệ.")
        }
        return pack
    }

    /// Revoke the local reviewed-only pack when a source PDF or approved meaning
    /// changes. Never remove other series or the user's spaced-repetition history.
    static func uninstallPersonalReviewedPack() throws {
        let file = folder.appendingPathComponent("sou-matome-personal-reviewed.json")
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    static func uninstallPersonalExercisePack() throws {
        let file = folder.appendingPathComponent("sou-matome-personal-exercises.json")
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    @discardableResult
    static func install(_ bytes: Data, alreadyInstalled: [CoursePack]) throws -> CoursePack {
        let pack = try validate(bytes)
        if let previous = alreadyInstalled.first(where: { $0.id == pack.id }),
           previous.version >= pack.version { throw CoursePackError.oldVersion }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try bytes.write(to: folder.appendingPathComponent(pack.id + ".json"), options: .atomic)
        return pack
    }
}

extension StudyStore {
    /// Cho phép nhập gói JSON từ Files trên iPhone, không cần Internet.
    func importContentPack(_ bytes: Data) throws {
        _ = try CoursePackManager.install(bytes, alreadyInstalled: installedPacks)
        reloadCoursePacks()
    }

    func revokePersonalReviewedPack() throws {
        try CoursePackManager.uninstallPersonalReviewedPack()
        reloadCoursePacks()
    }

    func revokePersonalExercisePack() throws {
        try CoursePackManager.uninstallPersonalExercisePack()
        reloadCoursePacks()
    }

    private func reloadCoursePacks() {
        let packs = CoursePackManager.allAvailablePacks()
        installedPacks = packs
        course = CoursePackManager.course(for: selectedSeries, packs: packs)
        contentRevision = UUID()
    }

    /// Tải cả gói truyền thống trên main và các gói học riêng của nhánh mới.
    /// Cập nhật xong mới đổi course một lần để các màn hình cùng hiển thị dữ liệu mới.
    @MainActor
    func downloadCourseUpdates() async throws -> Int {
        let allowedPrefixes = [
            "/tjzcy5sccr-cloud/n2-cua-trung-ios/main/content-packs/",
            "/tjzcy5sccr-cloud/n2-cua-trung-ios/feature/n2-four-series-roadmap-2027/content-packs/",
            "/tjzcy5sccr-cloud/n2-cua-trung-ios/feature/n2-sou-matome-library-2026/content-packs/"
        ]
        let manifests = [
            "https://raw.githubusercontent.com/tjzcy5sccr-cloud/n2-cua-trung-ios/main/content-packs/manifest.json",
            "https://raw.githubusercontent.com/tjzcy5sccr-cloud/n2-cua-trung-ios/feature/n2-four-series-roadmap-2027/content-packs/manifest-series.json",
            "https://raw.githubusercontent.com/tjzcy5sccr-cloud/n2-cua-trung-ios/feature/n2-sou-matome-library-2026/content-packs/manifest-sou-matome.json"
        ]
        var count = 0
        // Duy trì bản cập nhật chung khi nhánh mới đang trong giai đoạn thử nghiệm.
        for (index, manifestAddress) in manifests.enumerated() {
            guard let url = URL(string: manifestAddress) else { throw CoursePackError.invalidSource }
            do {
                let (manifestBytes, response) = try await URLSession.shared.data(from: url)
                guard let result = response as? HTTPURLResponse, (200...299).contains(result.statusCode),
                      manifestBytes.count < 100_000 else { throw CoursePackError.serverError }
                let manifest = try JSONDecoder().decode(CourseManifest.self, from: manifestBytes)
                guard manifest.schemaVersion == 1 else { throw CoursePackError.invalidData("Định dạng manifest không hợp lệ.") }
                for item in manifest.packs {
                    let oldVersion = installedPacks.first(where: { $0.id == item.id })?.version ?? 0
                    guard item.version > oldVersion else { continue }
                    guard let itemURL = URL(string: item.url),
                          itemURL.scheme == "https", itemURL.host == "raw.githubusercontent.com",
                          allowedPrefixes.contains(where: { itemURL.path.hasPrefix($0) })
                    else { throw CoursePackError.invalidSource }

                    let (bytes, packResponse) = try await URLSession.shared.data(from: itemURL)
                    guard let http = packResponse as? HTTPURLResponse, (200...299).contains(http.statusCode)
                    else { throw CoursePackError.serverError }
                    let pack = try CoursePackManager.validate(bytes)
                    guard pack.id == item.id && pack.version == item.version
                    else { throw CoursePackError.invalidData("Mã hoặc phiên bản gói không trùng manifest.") }
                    // Bảo đảm gói series thực sự thuộc đúng bộ, không lẫn nội dung.
                    if itemURL.path.hasPrefix(allowedPrefixes[1]) || itemURL.path.hasPrefix(allowedPrefixes[2]) {
                        guard pack.seriesId != nil && pack.id == "n2-series-" + pack.seriesId! else {
                            throw CoursePackError.invalidData("Gói học riêng có metadata không nhất quán.")
                        }
                    }
                    _ = try CoursePackManager.install(bytes, alreadyInstalled: installedPacks)
                    installedPacks = CoursePackManager.allAvailablePacks()
                    count += 1
                }
            } catch {
                // Gói series không khả dụng: giữ nguyên kho đã cài, nhưng vẫn báo lỗi
                // để người học biết không thể đồng bộ toàn bộ các bộ dữ liệu.
                if index > 0 { reloadCoursePacks() }
                throw error
            }
        }
        reloadCoursePacks()
        return count
    }
}
