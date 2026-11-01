import Foundation
import CryptoKit

/// Strict, offline CD inventory. Only numbered MP3s in CD1 or CD2 are
/// accepted; foreign audio can never silently count toward the 116 tracks.
enum SouMatomeAudioCatalog {
    struct LocatedTrack: Hashable {
        let disc: String
        let track: Int

        var filename: String { String(format: "%02d.mp3", track) }
        var key: String { disc + "/" + filename }
    }

    static let expectedCounts: [String: Int] = ["CD1": 64, "CD2": 52]

    static func locate(components: [String], filename: String) -> LocatedTrack? {
        guard (filename as NSString).pathExtension.lowercased() == "mp3" else {
            return nil
        }
        let stem = (filename as NSString).deletingPathExtension
        guard let number = Int(stem), number > 0,
              String(format: "%02d", number) == stem ||
              String(number) == stem else {
            return nil
        }

        // Prefer the closest CD folder, even if the outer archive folder
        // mentions both discs. Ambiguous folders are never guessed.
        for component in components.reversed() {
            let wide = component.folding(options: [.widthInsensitive, .caseInsensitive],
                                         locale: Locale(identifier: "en_US_POSIX"))
            let normalized = wide.uppercased().filter { $0.isLetter || $0.isNumber }
            let isFirst = normalized.contains("CD1") || normalized.contains("DISC1")
            let isSecond = normalized.contains("CD2") || normalized.contains("DISC2")
            guard isFirst != isSecond else { continue }
            let disc = isFirst ? "CD1" : "CD2"
            guard let maxNumber = expectedCounts[disc],
                  (1...maxNumber).contains(number) else { return nil }
            return LocatedTrack(disc: disc, track: number)
        }
        return nil
    }

    /// Stream the full MP3 instead of trusting filenames or sizes. This is
    /// used solely to revoke approvals if the user replaces an audio source.
    static func fingerprint(_ url: URL) throws -> String {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var sha = SHA256()
        while true {
            let bytes = try input.read(upToCount: 64 * 1024) ?? Data()
            if bytes.isEmpty { break }
            sha.update(data: bytes)
        }
        return sha.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func missingTracks(from keys: Set<String>) -> [String] {
        ["CD1", "CD2"].flatMap { disc -> [String] in
            let maxNumber = expectedCounts[disc] ?? 0
            return (1...maxNumber).compactMap { number in
                let key = LocatedTrack(disc: disc, track: number).key
                return keys.contains(key) ? nil : key
            }
        }
    }
}
