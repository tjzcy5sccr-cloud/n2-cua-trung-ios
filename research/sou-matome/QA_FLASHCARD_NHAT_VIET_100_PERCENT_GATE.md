# QA học liệu Sou Matome N2 – chưa phát hành IPA

## Yêu cầu cốt lõi

Không chia theo tuần. Mọi chữ Nhật, cách đọc, nghĩa Việt, ví dụ, câu hỏi và đáp án phải có nguồn và được duyệt trước khi hiển thị trong ngân hàng luyện thi. Không biến kết quả OCR thành một câu trả lời "100% đúng" nếu chưa kiểm tra.

## Đã triển khai vào mã nguồn

1. `SouMatomePersonalReview.swift`: lưu các thẻ do chủ sở hữu kiểm tra **ngay trên iPhone**. Với từng mục, người học xem PDF gốc, sửa chữ/cách đọc/giải nghĩa và xác nhận riêng hai bước: (a) tiếng Nhật + cách đọc, (b) nghĩa/cách dùng tiếng Việt. Ghi bản nháp không đồng nghĩa phê duyệt.
2. Chỉ các mục đã duyệt mới được đóng thành gói `sou-matome-personal-reviewed`, sau đó nhập vào `StudyStore` để hiển thị ở các flashcard và câu hỏi luyện tập hiện có. Dữ liệu cá nhân không đưa lên GitHub.
3. Không tạo trắc nghiệm nghĩa từ/Ngữ pháp/Kanji nếu dữ liệu chỉ có dưới **bốn nghĩa phân biệt**. Phần giải thích và ví dụ hai ngôn ngữ phải có đủ hai vế mới được bật.
4. Thay nguồn PDF sẽ hủy hiệu lực phê duyệt trước đó cho các thẻ liên quan.
5. `SouMatomeSourceEntriesView.swift` cho phép nhập JSON ứng viên máy tính tạo ra, nhưng **không tự duyệt**. Hỗ trợ sửa, nghe từ và đối chiếu từng trang.
6. `scripts/extract_sou_matome_private_candidates.py` trích các ứng viên từ ba PDF bổ trợ theo vị trí cột, không dựa vào nhãn tuần và không lưu tệp nguồn lên repo.
7. `scripts/audit_sou_matome_personal_pack.py` kiểm định gói đã duyệt theo cấu trúc, ID, cách đọc, nghĩa, đáp án, liên kết trang nguồn và lựa chọn nhiễu; chỉ tạo báo cáo lỗi/đếm, **không bao giờ xác nhận độ chính xác 100% bằng tự động**.

## Kiểm tra thực tế trên tài liệu đã được người dùng cung cấp

Bộ ứng viên máy tính phát hiện khoảng **2.188 dòng từ vựng, 654 vị trí Kanji và 56 tiêu đề bài ngữ pháp** (2.898 ứng viên). Trong đó có 72 dòng từ vựng **không trích được nghĩa Việt**. Số lượng là **vị trí trích máy**, có thể có dòng bị ghép/sai hoặc trùng; KHÔNG phải 2.898 mục đã kiểm duyệt. Ngữ pháp 56 tiêu đề **không phải** 56 quy tắc ngữ pháp đã phân tích.

Năm PDF chính gồm **683 trang ảnh** chưa số hóa/đối chiếu toàn văn; phần đọc hiểu, nghe hiểu và 116 track cũng chưa có dữ liệu câu hỏi/đáp án đã hiệu đính tương ứng 100%.

## Khả năng kiểm tra trước khi hoàn tất

Các workflow GitHub kiểm tra cú pháp Swift, cấu trúc JSON và test audit nguồn ở nhánh riêng. Biên dịch iOS Simulator có thể chạy không tạo IPA. Workflow tạo IPA vẫn là thủ công.

Mọi file PDF, MP3, kết quả OCR, thẻ riêng và bản dịch ở thư viện cá nhân phải nằm ngoài repository công khai. `.gitignore` ngăn vô tình commit các file nguồn.

## Điều kiện mới được ghi “ĐÃ HOÀN THÀNH 100%”

- Tất cả mục học trong từng kỹ năng được xác định, không bỏ sót hoặc nhập trùng.
- Mỗi mục đã đối chiếu chữ Nhật, cách đọc và nghĩa Việt đúng ngữ cảnh.
- Ví dụ Nhật–Việt (nếu có) đã được rà soát và giải thích rõ.
- Mỗi câu hỏi có đáp án duy nhất, lời giải chính xác và phương án nhiễu hợp lệ.
- Đọc hiểu/nghe hiểu đều có bản dịch, câu hỏi, giải thích, kèm đúng đoạn âm thanh.
- Kiểm định toàn bộ nguồn và dữ liệu được app thực sự dùng; chỉ phát hành khi không còn mục chờ duyệt.

**Hiện tại chưa đạt các điều kiện trên.** Dùng từ “đầy đủ” cho danh sách trang sách không có nghĩa đã hoàn thành kho câu hỏi tương tác.
