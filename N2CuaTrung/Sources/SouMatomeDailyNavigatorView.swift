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
                    SectionTitle("Đọc hiểu – 6 tuần",
                                 subtitle: "Theo mục lục của PDF sách chính")
                    if let doc = SouMatomeDocument.all.first(where: { $0.id == "dokkai" }),
                       let url = library.fileURL(for: doc) {
                        let starts = [12, 28, 44, 60, 78, 96]
                        ForEach(0..<starts.count, id: \.self) { index in
                            NavigationLink {
                                SouMatomePDFReader(book: doc, url: url,
                                                  initialPage: starts[index])
                            } label: {
                                HStack {
                                    Text("Tuần \(index + 1)")
                                    Spacer()
                                    Text("Trang \(starts[index])")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline)
                                .foregroundColor(Palette.navy)
                                .padding(.vertical, 5)
                            }
                        }
                    } else {
                        Text("Nhập PDF đọc hiểu trước khi chọn tuần.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                LessonPanel {
                    SectionTitle("Nghe hiểu – 5 chương",
                                 subtitle: "Theo mục lục của PDF nghe hiểu")
                    if let doc = SouMatomeDocument.all.first(where: { $0.id == "choukai" }),
                       let url = library.fileURL(for: doc) {
                        let starts = [12, 24, 40, 52, 64]
                        ForEach(0..<starts.count, id: \.self) { index in
                            NavigationLink {
                                SouMatomePDFReader(book: doc, url: url,
                                                  initialPage: starts[index])
                            } label: {
                                HStack {
                                    Text("Chương \(index + 1)")
                                    Spacer()
                                    Text("Trang \(starts[index])")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline)
                                .foregroundColor(Palette.navy)
                                .padding(.vertical, 5)
                            }
                        }
                    } else {
                        Text("Nhập PDF nghe hiểu trước khi chọn chương.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    NavigationLink {
                        SouMatomeLibraryView()
                    } label: {
                        ActionTile(icon: "waveform", color: Palette.blue,
                                   title: "Nghe các CD", detail: "64 track CD1 • 52 track CD2")
                    }.buttonStyle(.plain)
                    Text("Chưa tự gán track MP3 vào bài đọc/nghe khi chưa xác minh được từ nguồn.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .background(Palette.pale)
        .navigationTitle("Học Sou Matome theo ngày")
        .navigationBarTitleDisplayMode(.inline)
    }
}
