# Chuẩn phát triển nội dung — N2 của Trung

Ngày phê duyệt: 2026-10-31
Nhánh phát triển: develop/n2-curriculum-vietnam-2026

## Mốc tham chiếu
- Mimikara Oboeru N2: phương pháp học từ vựng theo nhóm, từ liên quan, ví dụ và nghe.
- Shin Kanzen Master N2: phân tầng ngữ pháp, Kanji, đọc hiểu và luyện đề.
- Nihongo So-Matome N2 (日本語総まとめ N2): lộ trình học theo ngày/tuần, nhóm chủ đề, bài ôn tập định kỳ.
- JLPT chính thức: cấu trúc kỹ năng và dạng câu hỏi.
- Các website dạy tiếng Nhật tại Việt Nam: tham khảo cách diễn giải, kiểm chứng chéo nghĩa tiếng Việt; không mặc định nguồn nào luôn đúng.

Không sao chép nguyên văn nội dung, ví dụ, bài tập hoặc bài đọc có bản quyền. Biên soạn nội dung gốc và ghi rõ xuất xứ tham khảo trong hồ sơ kiểm chứng.

## Thiết kế lộ trình kết hợp
- Học hằng ngày theo nhịp So-Matome: từ vựng + Kanji + ngữ pháp, xen kẽ đọc và nghe.
- Học sâu theo Mimikara: từ liên quan, cách dùng, ví dụ tự biên soạn và phát âm.
- Luyện nâng cao theo Shin Kanzen: phân tích bẫy đáp án và lý do đúng/sai.
- Dạng câu hỏi bám khung JLPT chính thức, không sao chép đề hoặc sách có bản quyền.
- Trình tự triển khai: kiểm kê kho dữ liệu hiện có → kiểm chứng nghĩa → biên soạn bổ sung → kiểm thử → duyệt hình → build.

## Điều kiện đưa mục học vào app
1. Cách viết, cách đọc và nghĩa tiếng Việt đã được kiểm chứng; nghĩa đa nghĩa phải có ngữ cảnh.
2. Ví dụ tiếng Nhật và bản dịch tiếng Việt được đối chiếu; đánh dấu đúng từ mục tiêu.
3. Kanji: âm On/Kun, âm Hán Việt, bộ thủ, từ ghép và nghĩa từ ghép khi có dữ liệu xác thực.
4. Nội dung chưa duyệt chỉ ở vùng nghiên cứu/source, không được xuất hiện trong giao diện học.
5. ID ổn định qua các bản cập nhật; không làm mất tiến độ học.
6. Ghi thống kê số mục gốc, số mục từ các gói, trùng ID, mục bị loại và mục cuối cùng theo từng kỹ năng.

## Ưu tiên kỹ thuật
- P0: Sửa cặp ví dụ Nhật–Việt trong Flashcard: cùng một khối, căn chỉnh thống nhất, khoảng cách nhỏ, không nhảy khung khi lật.
- P0: Không để nút Chưa thuộc/Đã thuộc bị thanh tab che; hỗ trợ màn hình iPhone nhỏ và Dynamic Type.
- P0: Kiểm tra đủ bốn gói nội dung khi đóng gói IPA, đối chiếu thống kê thực tế sau merge/filter.
- P1: Flashcard, Kanji và các kỹ năng có điều khiển nhất quán: Bỏ qua, Tiếp, Kết quả, giải thích.
- P1: Bổ sung kiểm thử dữ liệu tiếng Nhật/tiếng Việt và kiểm thử UI trước mỗi build.

## Quy trình phát hành
- Phát triển trên nhánh riêng, không tự ý thay đổi bản đã duyệt.
- Trình hình ảnh xem trước để người dùng duyệt trước khi build IPA.
- Chỉ công bố build thành công sau khi GitHub Actions hoàn tất và có artifact IPA.
- Không gửi email nếu người dùng không yêu cầu.
