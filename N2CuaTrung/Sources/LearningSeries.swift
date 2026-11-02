import Foundation

/// Các bộ học riêng trong cùng ứng dụng. Tên bộ sách chỉ xác định định hướng
/// luyện tập, không phải sản phẩm hoặc học liệu số chính thức của nhà xuất bản.
enum LearningSeries: String, CaseIterable, Identifiable {
    case all
    case mimikara
    case shinKanzen = "shin-kanzen"
    case souMatome = "sou-matome"
    case speedMaster = "speed-master"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .all: return "Tổng hợp N2"
        case .mimikara: return "Mimikara Oboeru"
        case .shinKanzen: return "Shin Kanzen Master"
        case .souMatome: return "Nihongo Sou Matome"
        case .speedMaster: return "Speed / Kanji Master"
        }
    }

    var subtitle: String {
        switch self {
        case .all: return "Toàn bộ dữ liệu ứng dụng, gồm các gói đã cài"
        case .mimikara: return "Từ vựng – giao tiếp – nghe qua ngữ cảnh"
        case .shinKanzen: return "Ngữ pháp – Kanji – đọc và giải thích kỹ"
        case .souMatome: return "PDF cá nhân và bài luyện N2 độc lập, học không khóa theo tuần"
        case .speedMaster: return "Kanji, từ ghép và luyện phản xạ"
        }
    }

    /// Same book silhouette for every curriculum. Color and title distinguish
    /// the series; unrelated SF Symbols no longer look like different logos.
    var icon: String { "books.vertical.fill" }


    var packFilename: String? {
        self == .all ? nil : "n2-series-\(rawValue)"
    }
}
