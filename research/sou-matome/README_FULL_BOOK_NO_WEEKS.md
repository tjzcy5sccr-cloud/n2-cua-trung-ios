# Sou Matome N2 – chuyển sang TOÀN BỘ SÁCH, không chia tuần

## Chế độ học đã thay đổi

Khi người dùng chọn Nihongo Sou Matome, ứng dụng chuyển sang:
- Toàn bộ từ vựng, ngữ pháp và Kanji **đã được duyệt trong gói JSON** (không còn khóa theo tuần).
- Trình đọc toàn bộ 5 sách chính và 3 tài liệu bổ trợ theo **kỹ năng** và **trang**, không hiện menu lịch tuần.
- Tìm kiếm toàn bộ nội dung có lớp văn bản từ 8 PDF được nhập trong thư viện cá nhân, kể cả trang OCR đã lưu.
- Danh sách mục học tạm trích từ **cả 163 trang tài liệu từ vựng**, **208 trang tài liệu Kanji** và **185 trang tài liệu ngữ pháp** của người dùng. Danh sách này hiển thị chữ Nhật, có nút mở nghĩa/nghe bằng giọng Nhật, tìm kiếm, và liên kết về trang sách gốc.
- Đọc hiểu mở trọn 121 trang, nghe hiểu mở trọn 73 trang và phát đầy đủ 116 MP3 sau khi người dùng nhập vào app.
- Tab `Lộ trình` trở thành `Toàn bộ sách` khi Sou Matome được chọn, trong khi lộ trình của những bộ giáo trình khác không thay đổi.

## Số liệu nguồn chính xác

| Loại nguồn | Số trang |
|---|---:|
| 5 PDF chính, chỉ có ảnh quét | 683 |
| 3 PDF bổ trợ Việt–Nhật, có lớp chữ | 556 |
| **Tổng 8 PDF** | **1.239** |

Nghe hiểu có **116 MP3** (CD1: 64, CD2: 52). Toàn bộ 1.239 trang đã được đánh số trong `content-packs/sou-matome-full-book-page-index.json` mà **không đưa chữ sách hoặc nội dung audio có bản quyền lên repository công khai**.

Kiểm tra trích xuất ở môi trường phát triển từ ba PDF có chữ phát hiện khoảng **1.602 ứng viên từ vựng, 654 vị trí Kanji và 128 tiêu đề ngữ pháp**. ĐÂY LÀ SỐ LƯỢNG PHÁT HIỆN THÔ, KHÔNG PHẢI SỐ MỤC HỌC CHUẨN VÀ CÀNG KHÔNG PHẢI SỐ MỤC ĐÃ ĐƯỢC DUYỆT. PDFKit trên iOS có thể tách câu/đầu mục khác chương trình kiểm tra Python, đặc biệt khi bảng có nhiều cột.

## Chỉ số KHÔNG được làm sai lệch

- Gói flashcard/trắc nghiệm Sou Matome được kiểm duyệt trước đây **không trở thành bản đầy đủ của sách** chỉ vì bỏ giới hạn theo tuần. Không được trộn ứng viên tách từ PDF chưa hiệu đính vào danh sách "đã kiểm chứng".
- 683 trang ảnh quét chưa được đối chiếu toàn văn và đáp án; app có công cụ Vision OCR cục bộ và lưu từng trang, nhưng OCR tự động có thể nhận sai chữ, furigana, cột và câu hỏi.
- Danh mục đọc/nghe nguồn PDF/MP3 không đồng nghĩa với đã tạo đầy đủ câu hỏi, bản dịch, đáp án và ánh xạ track chính xác.
- Nhập đủ PDF chỉ bảo đảm **toàn bộ sách có thể đọc** trong thư viện riêng, chưa bảo đảm **toàn bộ mục tương tác đã qua QA**.

## Các file chính

- `N2CuaTrung/Sources/SouMatomeWholeBooksView.swift`: toàn bộ 5 kỹ năng và tìm kiếm trong mọi cuốn.
- `N2CuaTrung/Sources/SouMatomeSourceEntriesView.swift`: trích ứng viên từng mục từ toàn bộ ba PDF bổ trợ, chỉ trên thiết bị.
- `N2CuaTrung/Sources/SouMatomePageWorkbenchView.swift`: nhận dạng/hiệu đính 683 trang quét (nếu người dùng yêu cầu).
- `N2CuaTrung/Sources/SouMatomeLibraryView.swift`: PDF, điều hướng trang, MP3.
- `N2CuaTrung/Sources/StudyStore.swift`: các màn học dùng toàn bộ nội dung có trong series Sou Matome.
- `content-packs/sou-matome-full-book-page-index.json`: ledger 1.239 trang, không chia tuần.
- `qa-reports/sou-matome-full-book-candidate-audit.json`: số liệu phát hiện và những giới hạn.
- CI kiểm tra metadata, cú pháp Swift và biên dịch iOS Simulator; **không xuất IPA**.

Không thay đổi nhánh `main`, không xóa các bộ Mimikara/Shin Kanzen/Speed Master hoặc tiến độ đã lưu.
