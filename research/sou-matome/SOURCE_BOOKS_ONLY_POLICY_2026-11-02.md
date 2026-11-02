# Sou Matome N2 — nguồn gốc duy nhất: sách người học cung cấp

## Quy tắc đã thống nhất ngày 02/11/2026

- **Chỉ dùng các tệp sách Sou Matome N2 do người học nhập vào thiết bị** (PDF gốc, PDF bổ trợ tiếng Việt, CD riêng). Mở đúng trang nguồn và xác minh nội dung trên trang đó. Không truy vấn, lấy nghĩa hoặc tự sửa chữ từ website/từ điển/AI ngoài giáo trình.
- Nếu lớp văn bản PDF thiếu hoặc tách chữ, **hình trang PDF mới là căn cứ cuối**. Giữ nguyên mục ở trạng thái chưa duyệt cho đến khi đọc được trang gốc; không đoán thêm nghĩa.
- Âm Hán–Việt của Kanji, âm On, âm Kun, nghĩa tiếng Việt, từ ghép và lời giải là những trường độc lập. **Không dùng âm Hán–Việt thay cho nghĩa** hoặc lấy nghĩa bộ thủ thay cho nghĩa chữ.
- Trong chế độ Sou Matome, không hiển thị dữ liệu tra cứu ngoài (kể cả danh sách bộ thủ tham khảo) như thể thuộc sách. Các giáo trình không phải Sou Matome không bị thay đổi.
- Các JSON cũ chứa `dictionaryHanViet`, `dictionaryReference` hoặc cảnh báo so sánh từ điển phải bị **bỏ qua khi nhập**. Nếu thẻ Kanji đã phê duyệt trước đây có âm Hán–Việt khác nhãn đọc từ chính PDF, giữ nội dung thẻ nháp nhưng **thu hồi phê duyệt** và yêu cầu kiểm tra lại.
- Học liệu trích tự động chỉ là **ứng viên**. Dù một chữ khớp lớp văn bản trên đúng trang thì điều đó không xác minh nghĩa Việt, furigana hay lời giải. Chỉ người kiểm duyệt sau khi mở trang sách mới xác nhận thẻ.
- Tách biệt toàn bộ giáo trình, không chia tuần, giữ lại lịch ôn và học liệu các bộ khác. Chưa build IPA khi học liệu chưa được duyệt.
- Không tải nguyên văn sách và MP3 lên kho GitHub công khai; sách và nội dung trích từ chúng chỉ ở thư viện cá nhân trên thiết bị người học.

## Tình trạng đối chiếu theo trang (không phải kiểm tra bản dịch)

| PDF bổ trợ | Trang nguồn | Ứng viên | Chữ Nhật khớp văn bản trên đúng trang | Nghĩa chưa trích được |
| --- | ---: | ---: | ---: | ---: |
| Từ vựng | 163 | 2.136 | 2.131 | 12 |
| Kanji | 208 | 654 | 654 | 654* |
| Ngữ pháp | 185 | 173 | 173 | 21 |

\* 654 mục Kanji có thể có nhãn âm Hán–Việt và cách đọc, nhưng chưa trích ra **nghĩa tiếng Việt độc lập**. Các mục vẫn được giữ ở dạng ứng viên. Với các trường hợp chữ Nhật bị phân đoạn bởi furigana, chỉ nhìn hình PDF để xác nhận.

Đã có công cụ `scripts/audit_sou_matome_book_only.py` đọc **duy nhất ba PDF sách tiếng Việt** và JSON nguồn riêng của người học; báo cáo chỉ có ID, số trang và loại bất thường, không chép nội dung sách. CI kiểm thử chế độ nguồn-sách-tuyệt-đối qua `scripts/test_sou_matome_book_source_contract.py`.

## Điều kiện đạt mức hoàn thiện

Hoàn thiện là khi từng mục có liên kết đúng tới trang sách, cách đọc và nghĩa Việt đã được đọc từ trang đó, không thiếu câu hỏi/giải thích cho kỹ năng tương ứng, và các tệp PDF/MP3 người học nhập đều kiểm tra được. **Hiện chưa đạt 100%**, đặc biệt còn 683 trang ảnh quét và chưa kiểm chứng toàn bộ dịch nghĩa, đọc/nghe.
