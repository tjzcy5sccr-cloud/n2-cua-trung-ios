import Foundation

@main
enum SouMatomeAudioCatalogTests {
    private static func check(_ condition: @autoclosure () -> Bool,
                              _ message: String) {
        precondition(condition(), message)
    }

    static func main() throws {
        let disc1 = SouMatomeAudioCatalog.locate(
            components: ["/", "Personal Books", "CD 1"], filename: "01.mp3")
        check(disc1?.key == "CD1/01.mp3", "CD1 source should resolve")
        let disc2 = SouMatomeAudioCatalog.locate(
            components: ["/", "Sou Matome CD1 CD2", "CD2"], filename: "52.MP3")
        check(disc2?.key == "CD2/52.mp3", "Closest CD folder takes precedence")
        check(SouMatomeAudioCatalog.locate(components: ["CD2"],
                                          filename: "53.mp3") == nil,
              "CD2 has exactly 52 tracks")
        check(SouMatomeAudioCatalog.locate(components: ["CD1"],
                                          filename: "65.mp3") == nil,
              "CD1 has exactly 64 tracks")
        check(SouMatomeAudioCatalog.locate(components: ["Unlabeled"],
                                          filename: "01.mp3") == nil,
              "An unknown disc must not be silently treated as CD1")
        check(SouMatomeAudioCatalog.locate(components: ["CD1"],
                                          filename: "lecture.mp3") == nil,
              "Non-numeric filenames must be rejected")
        check(SouMatomeAudioCatalog.locate(components: ["CD1+CD2"],
                                          filename: "01.mp3") == nil,
              "Ambiguous disc labels must be rejected")

        let missing = SouMatomeAudioCatalog.missingTracks(from: [
            "CD1/01.mp3", "CD2/52.mp3"
        ])
        check(missing.count == 114, "116 total minus two should be 114")
        check(!missing.contains("CD1/01.mp3"), "Present CD1 track")
        check(!missing.contains("CD2/52.mp3"), "Present CD2 track")

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sou-matome-test-" + UUID().uuidString,
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let one = directory.appendingPathComponent("one.mp3")
        let two = directory.appendingPathComponent("two.mp3")
        try Data(repeating: 33, count: 4096).write(to: one)
        try Data(repeating: 33, count: 4096).write(to: two)
        check(try SouMatomeAudioCatalog.fingerprint(one) ==
                  SouMatomeAudioCatalog.fingerprint(two),
              "Identical audio must keep its review approval")
        try Data(repeating: 42, count: 4096).write(to: two)
        check(try SouMatomeAudioCatalog.fingerprint(one) !=
                  SouMatomeAudioCatalog.fingerprint(two),
              "Changed audio must invalidate the linked listening question")
        print("PASS: 116-track inventory, strict CD classification and SHA256 replacement detection")
    }
}
