import Foundation
import Combine

/// A manifest references audio hosted in a GitHub repository for which the
/// user has streaming/redistribution rights. This does not ship source CD
/// recordings. AVPlayer handles HTTPS streaming.
struct SouMatomeOnlineAudioManifest: Decodable {
    let schemaVersion: Int
    let tracks: [Entry]

    struct Entry: Decodable {
        let cd: String
        let track: Int
        let url: String
    }
}

@MainActor
final class SouMatomeOnlineAudioSource: ObservableObject {
    @Published private(set) var tracks: [SouMatomeTrack] = []
    @Published private(set) var message = ""
    @Published private(set) var loading = false

    static let defaultManifest = "https://raw.githubusercontent.com/tjzcy5sccr-cloud/n2-cua-trung-ios/feature/n2-sou-matome-library-2026/content-packs/sou-matome-audio-streams.json"

    func refresh(from address: String = defaultManifest) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            tracks = try await Self.fetch(from: address)
            message = tracks.isEmpty
                ? "Chưa có URL MP3 trực tuyến trong danh mục GitHub. Hãy thêm đường dẫn bản ghi âm được phép chia sẻ."
                : "Đã nhận \(tracks.count)/116 đường dẫn MP3 từ GitHub. Chạm track để phát trực tuyến."
        } catch {
            message = "Không tải được danh sách CD: \(error.localizedDescription)"
        }
    }

    static func fetch(from address: String) async throws -> [SouMatomeTrack] {
        guard let url = URL(string: address),
              url.scheme == "https",
              url.host == "raw.githubusercontent.com",
              url.path.hasSuffix(".json"),
              url.pathComponents.count >= 5 else {
            throw SouMatomeOnlineAudioError.invalidManifest
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode), data.count < 100_000 else {
            throw SouMatomeOnlineAudioError.unavailable
        }
        let manifest = try JSONDecoder().decode(SouMatomeOnlineAudioManifest.self, from: data)
        guard manifest.schemaVersion == 1 && manifest.tracks.count <= 116 else {
            throw SouMatomeOnlineAudioError.invalidManifest
        }
        var seen: Set<String> = []
        var tracks: [SouMatomeTrack] = []
        for item in manifest.tracks {
            guard let maximum = SouMatomeAudioCatalog.expectedCounts[item.cd],
                  (1...maximum).contains(item.track),
                  let mp3URL = URL(string: item.url),
                  mp3URL.scheme == "https",
                  mp3URL.host == "raw.githubusercontent.com",
                  mp3URL.pathExtension.lowercased() == "mp3",
                  mp3URL.user == nil, mp3URL.password == nil else {
                throw SouMatomeOnlineAudioError.invalidTrack
            }
            let key = "\(item.cd)/" + String(format: "%02d.mp3", item.track)
            guard seen.insert(key).inserted else {
                throw SouMatomeOnlineAudioError.duplicateTrack
            }
            tracks.append(SouMatomeTrack(url: mp3URL, cd: item.cd))
        }
        return tracks.sorted {
            if $0.cd == $1.cd { return $0.name < $1.name }
            return $0.cd < $1.cd
        }
    }
}

enum SouMatomeOnlineAudioError: LocalizedError {
    case invalidManifest, invalidTrack, duplicateTrack, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidManifest: return "Danh mục GitHub không hợp lệ. Cần JSON v1 trên raw.githubusercontent.com."
        case .invalidTrack: return "Đường dẫn MP3 hoặc số track không hợp lệ."
        case .duplicateTrack: return "Danh mục có track CD bị lặp."
        case .unavailable: return "GitHub không trả về danh mục hợp lệ."
        }
    }
}
