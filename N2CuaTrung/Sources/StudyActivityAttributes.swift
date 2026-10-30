import ActivityKit
import Foundation

/// Shared by iPhone app and its widget extension.
@available(iOS 16.1, *)
struct StudyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var word: String
        var reading: String
        var meaning: String
    }
    var title: String
}