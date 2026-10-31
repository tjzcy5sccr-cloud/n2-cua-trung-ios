import SwiftUI

/// Lesson-day navigator derived from headers in three user-provided Vietnamese
/// supplementary PDFs. It never contains or redistributes book passages.
private struct SouMatomeDayBook: Decodable {
    let expectedWeeks: Int
    let daysPerWeek: Int
    let weeks: [[Int?]]
}
private struct SouMatomeDayIndex: Decodable {
    let sources: [String: SouMatomeDayBook]
    static let bundled: SouMatomeDayIndex? = {
        guard let url = Bundle.main.url(forResource: "sou-matome-day-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SouMatomeDayIndex.self, from: data)
    }()
}

struct SouMatomeDailyNavigatorView: View {
    @StateObject private var library = SouMatomeLibraryStore()
    @State private var selectedWeek = 1

    private let books: [(id: String, name: String)] = [
        ("kanji-vi", "Kanji – bản bổ trợ"),
        ("goi-vi", "Từ vựng – bản bổ trợ"),
        ("bunpou-vi", "Ngữ pháp – bản bổ trợ")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                SectionTitle("Chương trình Sou Matome theo tuần",
                             subtitle: "Chọn đúng ngày và mở trang PDF nguồn")
                LessonPanel {
                    Picker("Tuần", selection: $selectedWeek) {
                        ForEach(1...8, id: \.self) { value in
                            Text("Tuần \(value)").tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    Text("Các mốc dưới đây được lấy từ tiêu đề bài học trong ba tài liệu tiếng Việt. Nội dung vẫn nằm trong các PDF do bạn nhập, không phải gói flashcard đã số hóa.")
                        .font(.caption).foregroundColor(.secondary)
                }

                if let index = SouMatomeDayIndex.bundled {
                    ForEach(books, id: \.id) { summary in
                        if let bookIndex = index.sources[summary.id],
                           let document = SouMatomeDocument.all.first(where: { $0.id == summary.id }) {
                            LessonPanel {
                                SectionTitle(summary.name,
                                             subtitle: "\(bookIndex.daysPerWeek) ngày / tuần")
                                if let sourceFile = library.fileURL(for: document) {
                                    let pages = bookIndex.weeks[selectedWeek - 1]
                                    ForEach(0..<pages.count, id: \.self) { dayIndex in
                                        if let pageNumber = pages[dayIndex] {
                                            HStack(alignment: .center, spacing: 12) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Ngày \(dayIndex + 1)")
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundColor(Palette.navy)
                                                    Text("Bắt đầu ở trang \(pageNumber)")
                                                        .font(.caption).foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                NavigationLink {
                                                    SouMatomePDFReader(book: document, url: sourceFile,
                                                                      initialPage: pageNumber)
                                                } label: {
                                                    Image(systemName: "book.closed")
                                                }.buttonStyle(.bordered)
                                                NavigationLink {
                                                    SouMatomePageWorkbenchView(book: document, url: sourceFile,
                                                                               initialPage: pageNumber)
                                                } label: {
                                                    Image(systemName: "text.viewfinder")
                                                }.buttonStyle(.bordered)
                                            }
                                            .padding(.vertical, 3)
                                        } else {
                                            HStack {
                                                Text("Ngày \(dayIndex + 1)")
                                                Spacer()
                                                Text("Chưa xác minh trang")
                                                    .font(.caption).foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                } else {
                                    Text("Chưa nhập PDF tiếng Việt của phần này. Nhập sách ở Thư viện Sou Matome để mở các ngày.")
                                        .font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    LessonPanel {
                        Text("Thiếu chỉ mục tuần/ngày trong bộ cài. Kiểm tra Resources.")
                            .foregroundColor(.secondary)
                    }
                }

                LessonPanel {
                    SectionTitle("Đọc hiểu và nghe hiểu")
                    Text("Hai sách chính này có bố cục riêng, chưa có lớp văn bản. Mở thư viện để đọc PDF, sử dụng CD nghe và hiệu đính từng trang.")
                        .font(.subheadline).foregroundColor(.secondary)
                    NavigationLink {
                        SouMatomeLibraryView()
                    } label: {
                        ActionTile(icon: "books.vertical", color: Palette.blue,
                                   title: "Thư viện PDF và CD", detail: "Đọc hiểu • Nghe hiểu • 116 MP3")
                    }.buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Học Sou Matome theo ngày")
        .navigationBarTitleDisplayMode(.inline)
    }
}
