# Sou Matome N2 – đối soát toàn bộ học liệu người dùng cung cấp

## Phạm vi thực sự đã xử lý – 01/11/2026

Đối chiếu trực tiếp 5 tệp đầu vào (4 RAR và 1 PDF), đã giải nén kiểm tra toàn bộ nguồn:

| Tài liệu | Số trang | Văn bản có thể trích xuất |
|---|---:|---:|
| Kanji – sách chính | 177 | 0 |
| Từ vựng – sách chính | 156 | 0 |
| Ngữ pháp – sách chính | 156 | 0 |
| Đọc hiểu – sách chính | 121 | 0 |
| Nghe hiểu – sách chính | 73 | 0 |
| Kanji tiếng Việt | 208 | 208 |
| Từ vựng tiếng Việt | 163 | 163 |
| Ngữ pháp tiếng Việt | 185 | 185 |
| **Tổng** | **1.239** | **556** |

- **683 trang chính** là PDF quét ảnh, chưa có chữ số hóa/đối chiếu.
- **556 trang bổ trợ** có text layer, đã lấy được mốc 8 tuần học từng tài liệu.
- Kiểm kê đủ **116 MP3**, gồm CD1 64 tệp và CD2 52 tệp. Tất cả 116 file đọc được metadata MP3. Tổng thời lượng khoảng **125,20 phút**, không trùng nội dung byte nguyên vẹn giữa các track. Chưa đối chiếu track với câu hỏi và transcript.
- Chỉ mục cục bộ `SouMatome_N2_source_coverage_index.zip` chứa các bản ghi nguồn **1.239 trang** và **116 track**, số trang, gợi ý tuần/ngày, tình trạng nhận dạng và nhận diện thiếu dữ liệu. Chỉ mục **không chứa** toàn văn sách, hình ảnh, CD hoặc các bản dịch có bản quyền.

## Kết quả kiểm tra tiêu đề bài theo tuần/ngày

- **Kanji tiếng Việt:** xác nhận đủ 8 tuần × 6 ngày từ tiêu đề tìm thấy.
- **Từ vựng tiếng Việt:** tìm thấy tiêu đề 47/48 ngày (8 tuần × 6 ngày), **chưa tìm thấy tiêu đề Tuần 5 – Ngày 5**. Điều này không chứng minh rằng nội dung của ngày đó bị mất; cần so sánh trang nguồn trước khi điền mốc.
- **Ngữ pháp tiếng Việt:** xác nhận đủ 8 tuần × 7 ngày từ tiêu đề tìm thấy.

`N2CuaTrung/Resources/sou-matome-day-index.json` giữ nguyên mốc còn thiếu dưới dạng `null`, tuyệt đối không đoán trang.

## Mã nguồn đã triển khai trên nhánh riêng

- `SouMatomeLibraryView.swift`: nhập nhiều PDF, nhập từng thư mục CD, đọc PDF, nghe offline, mở chương trình ngày học.
- `SouMatomeDailyNavigatorView.swift`: chọn tuần 1–8, ngày học theo trang sách Việt, mở đúng trang đọc và hiệu đính.
- `SouMatomePageWorkbenchView.swift`: trích văn bản PDF; nhận dạng trang ảnh bằng Vision **ngay trên iPhone**, sửa lỗi OCR, lưu văn bản/đánh dấu đối chiếu theo từng trang, tìm kiếm, **nhận dạng toàn bộ một cuốn sách theo lần chạy có thể dừng và tiếp tục**. Văn bản nguồn và kết quả sửa lưu **trong bộ nhớ riêng của ứng dụng**.
- Khi thay PDF, tự vô hiệu hóa các dấu đã đối chiếu và bản chữ đã hiệu đính cũ, tránh ghép nhầm nguồn.
- `qa-reports/sou-matome-source-coverage.json` và `qa-reports/sou-matome-audio-integrity.json`: tình trạng chính xác của đầu vào.
- `check-sou-matome-library.yml`: kiểm tra cấu trúc, metadata, Swift parse. **Workflow build IPA đã được đặt chế độ chạy thủ công, không kích hoạt tự động trong giai đoạn làm học liệu**.

## Những việc không được phép gắn nhãn hoàn thành

Việc đánh số đầy đủ 1.239 trang **không phải** đã chuyển 1.239 trang thành bài tương tác. OCR của PDF gốc, tự kiểm tra nghĩa Việt, phân tách từng mục, gắn câu hỏi/đáp án, gắn từng bài CD và QA bằng bản gốc **chưa hoàn tất**.

Kho bài tập JSON Sou Matome v7 là nội dung nguyên gốc/tuyển chọn từ dự án trước; **không có chứng cứ chứng minh trùng với 100% từng bài trong sách**. Không được đếm nó như thể đã số hóa toàn bộ 5 sách.

**Tiêu chuẩn hoàn thành cuối:** từng bài/tuần/ngày được đối chiếu hai nguồn, đủ nghĩa Việt, furigana, câu hỏi và đáp án khi nguồn hỗ trợ, liên kết audio chính xác, không còn mục chưa duyệt, và báo cáo số liệu từ dữ liệu thực sự được ứng dụng sử dụng. Không chép sách/CD thương mại vào repository công khai.

Bản này giữ nguyên nhánh `main`, bộ Mimikara, Shin Kanzen, Speed Master và lịch sử học cũ.
