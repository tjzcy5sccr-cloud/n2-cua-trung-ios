# N2 của Trung — Chương trình N2 theo 4 hướng học

## Trạng thái nhánh

- **Nhánh phát triển độc lập:** `feature/n2-four-series-roadmap-2027`
- **Không sửa nhánh `main`**, không thay bản IPA đã gửi.
- **Đã triển khai:** lộ trình JSON 35 tuần, 210 nhiệm vụ hằng ngày, màn hình SwiftUI có lối vào từ Trang chủ và Lộ trình, ghi nhớ trạng thái đánh dấu từng ngày trên iPhone, chuyển sang kỹ năng sẵn có.
- **Chưa triển khai:** toàn bộ 6.000 từ, 1.100 Kanji và 150 mẫu ngữ pháp như nội dung mới được biên tập/đối chiếu; các mốc này **là chỉ tiêu**, không được coi là dữ liệu hoàn thiện. Từ/ngữ pháp đang hiển thị là kho có sẵn của dự án.
- **Chưa build IPA cho nhánh này**. Quy trình bắt buộc phải xem hình trước khi build.

## Diễn giải các mốc trong ảnh

| Kỹ năng | Mốc thiết kế chương trình | Ghi chú |
|---|---:|---|
| Từ vựng | 6.000 mục tích lũy | Gồm từ nền tảng N3 đã học + mở rộng hướng N2; đây không phải danh sách JLPT chính thức. |
| Kanji | 1.100 chữ tích lũy | Nằm trong khoảng 1.000–1.250 đề xuất, bao gồm chữ nền đã biết. |
| Ngữ pháp | 150 cấu trúc | Nằm trong khoảng 110–170 theo hình tham khảo. |
| Đọc hiểu | 70 lượt luyện theo kế hoạch | Không đồng nghĩa với 70 bài mới được biên soạn. |
| Nghe hiểu | 70 lượt luyện theo kế hoạch | Tài nguyên hiện có sử dụng giọng đọc iOS; không phải audio giáo trình. |
| Lộ trình | 35 tuần, 6 ngày/tuần | 90 phút/ngày; chủ nhật ôn nhẹ hoặc nghỉ. |

Các con số trên là **mục tiêu cá nhân**, không phải tiêu chuẩn số lượng từ/kanji chính thức được JLPT công bố. Chỉ số thật của app được tính trực tiếp từ `store.course`.

## Bốn hướng học và chức năng app

### 1. Mimikara Oboeru — nghe, nói lại, nhớ qua ngữ cảnh

- Dùng từ vựng và câu ví dụ sẵn có của app; nghe tiếng Nhật, lật thẻ, phát âm lại.
- Mục tiêu cho từng bài tự biên soạn: từ chính, cách đọc, một nghĩa Việt phù hợp ngữ cảnh, câu Nhật, câu Việt, bài kiểm tra.
- Dùng `FlashcardDeckView` và `FreshPracticeSessionView(type: "Nghe hiểu")`.
- **Không** nhập lại danh sách từ, câu mẫu hoặc audio từ sách Mimikara.

### 2. Shin Kanzen Master — phân tích sâu và giải thích vì sao đúng/sai

- Ngữ pháp: nghĩa, cách dùng, sắc thái, điều kiện hạn chế, so sánh mẫu dễ nhầm.
- Đọc hiểu: tìm chủ đề, từ nối, luận điểm và bằng chứng; sau đó chữa đáp án.
- Nghe hiểu: nắm ý chính, mục đích người nói và thông tin quyết định.
- Kanji: nhận diện cách đọc, ngữ nghĩa và từ ghép trong bối cảnh.
- Dùng `GrammarFlashcardView`, `FreshPracticeSessionView` và bộ đề hiện có. **Không** tái bản đề/câu chữ của Shin Kanzen.

### 3. Nihongo Sou Matome — lịch học nhỏ, đều đặn

- Sáu ngày học trong tuần, mỗi ngày **20 + 20 + 25 + 15 + 10 = 90 phút**.
- Chủ nhật ôn và nghỉ. App lưu checkbox từng ngày trong UserDefaults.
- Các chủ đề mỗi tuần được viết mới trong `n2-four-series-curriculum.json`, không phải mục lục hoặc lời giải sách.

### 4. Speed Master / Kanji Master — phản xạ và thời gian

- Làm trắc nghiệm có thời gian, xem lại từ yếu và phân biệt đáp án gần nghĩa.
- Luyện chữ Hán qua câu ngắn, sau đó luyện đọc/nghe có áp lực thời gian.
- Phân tích lỗi và ôn theo chu kỳ, không sao chép bài test hoặc bản scan của sách.

## Các giai đoạn của 35 tuần

1. **Tuần 1–7:** củng cố kiến thức N3, chuyển sang ngữ pháp N2 thông dụng.
2. **Tuần 8–14:** mở rộng theo chủ đề, dùng từ trong tình huống.
3. **Tuần 15–21:** so sánh cấu trúc, diễn đạt nguyên nhân–kết quả, lập luận.
4. **Tuần 22–28:** đọc/nghe dài, nắm ý chính và quyết định.
5. **Tuần 29–35:** đề trộn, bấm giờ, thống kê lỗi và tổng ôn.

Chi tiết **từng tuần và từng ngày**: `N2CuaTrung/Resources/n2-four-series-curriculum.json`.

## Bảo vệ dữ liệu và bản quyền

- Tên bốn series chỉ là **tài liệu định hướng phương pháp**, không đồng nghĩa với việc có giấy phép số hóa các sách đó.
- Không sao chép nguyên văn phần bài học, bảng từ, đoạn đọc, đề, đáp án, ảnh minh họa hoặc audio sách.
- Nội dung bổ sung cho app sẽ phải là bài do dự án tự biên soạn hoặc nguồn có giấy phép phù hợp; ghi nguồn và trạng thái đối chiếu trong mã, không thêm nhãn "tham khảo/chưa duyệt" lên thẻ học.
- Mọi thay đổi cần kiểm tra Nhật–Việt trước khi phát hành.

### Nguồn tham khảo xuất bản

- 3A Corporation: [Shin Kanzen Masuta N2 Vocabulary](https://www.3anet.co.jp/np/en/books/3632/) — mô tả hướng học theo chủ đề, ngữ cảnh và cách dùng.
- 3A Corporation: [Shin Kanzen Masuta N2 Kanji](https://www.3anet.co.jp/np/en/books/3622/) — mô tả hướng học chữ Hán và luyện ứng dụng.
- Các bộ Mimikara Oboeru, Nihongo Sou Matome, Speed Master/Kanji Master được nhắc tên theo yêu cầu người dùng, không khẳng định sách được cấp phép sử dụng.

## Dữ liệu kỹ thuật

- `N2CuaTrung/Sources/FourSeriesCurriculumView.swift`: UI học offline, liên kết kỹ năng.
- `N2CuaTrung/Resources/n2-four-series-curriculum.json`: 4 tracks, 35 weeks, 210 days.
- `project.yml`: đóng gói JSON khi build app.
- `scripts/validate_four_series_curriculum.py`: kiểm tra 35 tuần, 6 ngày và tổng các chỉ tiêu.

**Tác giả ứng dụng:** Trần Phước Trung  
**Bản quyền mã và nội dung gốc của dự án:** © 2026 Trần Phước Trung. Bảo lưu mọi quyền. Thương hiệu và sách tham khảo vẫn thuộc các chủ sở hữu của chúng.
