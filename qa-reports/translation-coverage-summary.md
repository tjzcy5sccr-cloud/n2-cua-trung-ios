# Báo cáo rà soát tiếng Việt — N2 của Trung

Ngày đối chiếu mã nguồn: 2026-10-31. Nguồn dữ liệu: `N2CuaTrung/Resources/content.json` và bốn gói `content-packs/*.json`. Đây là **số lượng bản ghi theo gói**, chưa loại các mục trùng giữa gói.

| Nhóm nội dung | Tổng bản ghi | Nghĩa/bản dịch chưa kiểm duyệt |
|---|---:|---|
| Từ vựng | 2.002 | Trong gói N2 lõi: 1.378 nghĩa từ điển khớp mặt chữ chưa xác minh kana/ngữ cảnh; 1.654 câu ví dụ dịch máy chưa kiểm duyệt |
| Ngữ pháp | 180 | Gói N2 lõi 93 nghĩa/cách dùng và 93 ví dụ chính đã biên tập; 186 ví dụ phụ trong gói lõi chưa duyệt, 8 ví dụ phụ ở gói VN26 chưa gắn trạng thái duyệt |
| Kanji | 471 | 281 nghĩa trong gói N2 lõi còn `machine_unreviewed`; bộ thủ và âm Hán–Việt phải được kiểm riêng |
| Đọc hiểu | 74 | 74 bài có câu hỏi/lời giải nhưng mô hình dữ liệu chưa có bản dịch toàn đoạn `textVi` |
| Nghe hiểu | 70 | 70 bài có hội thoại/lời giải nhưng mô hình dữ liệu chưa có bản dịch toàn hội thoại `scriptVi` |

**Kiểm tra chỗ trống:** 0 giá trị trống trong các trường cơ bản `meaning`, `exampleVi`, `grammar.translation`, `kanji.meaning`, `question`, `explanation` ở 5 gói tại thời điểm kiểm tra. Nhưng **có chữ tiếng Việt không đồng nghĩa với nghĩa chính xác**. Còn **144 đoạn/hội thoại chưa có bản dịch toàn văn độc lập**. Các gói ngoài N2 lõi thiếu metadata kiểm chứng từng mục nên chưa được công nhận là đã thẩm định.

**Bản dịch chưa duyệt vẫn có thể chứa lỗi:** những trường `machine_translated_unreviewed`, `dictionary_matched_unverified`, `machine_unreviewed`, `needs_sentence_review`, hoặc không có nhãn thẩm định không được tự đánh dấu đạt 100%.

**Nguồn dùng để đối chiếu thủ công:** Mazii, Jdict, Kanji.vn và các website học tiếng Nhật của Việt Nam. Kiểm riêng mặt chữ, cách đọc kana, nghĩa theo ngữ cảnh và bản dịch toàn câu.

**Danh sách đầy đủ từng mục:** workflow `.github/workflows/build-ios.yml` chạy `scripts/audit_all_course_content.py` và xuất hai tệp `qa-reports/n2-content-audit.json`, `qa-reports/n2-untranslated-audit.json` trong artifact `N2-translation-audit-report`. Đây là bảng mục cần kiểm duyệt, không phải chứng nhận các mục đều sai hoặc chưa dịch.

**Hành vi luyện tập sửa trong code:** Nghe hiểu và Kanji có Bỏ qua/Tiếp/Kết quả; Đọc hiểu/Nghe hiểu/Kanji tạo câu hỏi ngẫu nhiên mỗi lượt vào. Flashcard tạo bộ đọc mới và vô hiệu hóa phiên cũ khi chuyển, vẫn cần thử trên iPhone để xác nhận.
