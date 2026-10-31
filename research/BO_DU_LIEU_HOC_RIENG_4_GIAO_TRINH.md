# N2 của Trung — Chọn bộ học độc lập bên trong ứng dụng cũ

## Thiết kế đã triển khai trên nhánh

**Không tạo app mới** và không thay đổi nhánh `main`. Cùng ứng dụng iOS, giao diện và kho dữ liệu cũ được mở rộng với các bộ học chọn được ngay trên iPhone.

Người dùng chọn trong **Trang chủ → Chọn bộ dữ liệu**, **Luyện tập** hoặc **Tiến độ → Cập nhật kho học**.

| Bộ học | Từ vựng | Ngữ pháp | Kanji | Đọc | Nghe | Tổng |
|---|---:|---:|---:|---:|---:|---:|
| Mimikara Oboeru – hướng học nghe/ngữ cảnh | 32 | 15 | 16 | 2 | 2 | 67 |
| Shin Kanzen Master – hướng phân tích kỹ năng | 31 | 15 | 16 | 2 | 2 | 66 |
| Nihongo Sou Matome – chia theo ngày/tuần | 31 | 15 | 17 | 2 | 1 | 66 |
| Speed / Kanji Master – hướng luyện phản xạ | 31 | 14 | 16 | 2 | 1 | 64 |

**Đây là số mục khởi tạo từ bộ dữ liệu gốc tự biên soạn của app**, không phải kho nội dung đầy đủ hoặc bản số hóa chính thức của các bộ sách. Các bộ học có JSON riêng, không trùng ID; tổng bộ chia lại đúng **125 từ vựng, 59 ngữ pháp, 65 Kanji, 8 bài đọc, 6 bài nghe gốc**, không thêm bớt dữ liệu ở bước phân loại ban đầu. Nội dung khác trong các gói N2 mở rộng vẫn còn khi chọn **Tổng hợp N2**.

## Cơ chế hoạt động

1. **Tổng hợp N2:** giữ nguyên dữ liệu `content.json` và toàn bộ các gói bổ sung từng có trong IPA; đồng thời nhận thêm gói học mới sau khi cập nhật.
2. **Chọn bộ riêng:** chỉ lấy gói có `seriesId` tương ứng; không chèn thêm từ bộ khác khi thiếu bài.
3. **Lưu lựa chọn:** `N2CuaTrung.activeStudySeries.v1` trong UserDefaults. Đóng và mở lại ứng dụng vẫn nhớ bộ đang học.
4. **Mọi màn học dùng cùng `store.course`:** Flashcard từ, Flashcard ngữ pháp, Kanji, các danh sách, câu hỏi, đọc/nghe và luyện đề lấy đúng bộ được chọn.
5. **Khi đổi bộ/cập nhật:** `contentRevision` phát sự kiện; Flashcard/Kanji và màn luyện đọc/nghe nạp lại câu hỏi, không dùng bộ cũ đang giữ trong bộ nhớ.
6. **Không mất tiến độ:** lịch ôn và điểm vẫn lưu trong file sao lưu `SavedProgress` với ID thẻ ổn định.

## Định dạng một gói riêng

Ví dụ:

```json
{
  "id": "n2-series-shin-kanzen",
  "version": 1,
  "seriesId": "shin-kanzen",
  "title": "Shin Kanzen – Bộ phân tích do N2 của Trung tuyển chọn",
  "vocab": [],
  "grammar": [],
  "kanji": [],
  "readings": [],
  "listening": []
}
```

- Phải có ít nhất một nội dung hợp lệ trước khi nhập.
- Gói mới phải tăng `version` để thay thế phiên bản cũ cùng `id`, không thay đổi ID của mục học khi cập nhật.
- `seriesId` nhận `mimikara`, `shin-kanzen`, `sou-matome`, `speed-master`.
- Khi có dữ liệu mới cho một bộ, chỉnh đúng JSON đó và tăng số phiên bản tương ứng trong `content-packs/manifest-series.json`.
- Bấm **Cập nhật dữ liệu** trong app để nạp các cập nhật riêng của bốn bộ cùng các gói mở rộng cũ trên `main`. Có thể nhập JSON thủ công từ Tệp trên iPhone.

### Quyền tác giả và kiểm duyệt

Tên Mimikara, Shin Kanzen, Sou Matome, Speed/Kanji Master chỉ được dùng như **nhãn định hướng phương pháp học** theo yêu cầu; không gán nội dung do dự án tạo/tuyển chọn thành bản trích sách. Chưa có quyền dùng nguyên văn bài học, danh mục từ, đoạn đọc, bài nghe hay audio thương mại thì không đưa nội dung đó vào gói.

Bất kỳ nội dung mới nào cần được kiểm tra chính xác nghĩa Nhật–Việt, furigana và đáp án trước khi nhập. Bản nháp chưa kiểm chứng chỉ lưu trong `research/` và mã nguồn, không tự tuyên bố đã duyệt.

### Bước tiếp theo và giới hạn

- Cần biên soạn thêm nội dung **thực sự riêng** cho từng hướng học; các gói hiện là bộ tuyển chọn ban đầu từ dữ liệu N2 gốc.
- Bộ chọn áp dụng cho các màn học **bên trong ứng dụng**. WidgetKit nằm ở extension riêng, chưa được đồng bộ bộ đang chọn vì cần cơ chế chia sẻ dữ liệu giữa app và widget.
- Chưa biên dịch IPA cho nhánh này. Bản xem trước hình ảnh phải được người dùng duyệt trước khi build.
- **Nhánh `main` và IPA đã gửi trước đây vẫn giữ nguyên**.

## Đường dẫn mã

- `N2CuaTrung/Sources/LearningSeries.swift`: các loại bộ học.
- `N2CuaTrung/Sources/LearningSeriesPickerView.swift`: giao diện chọn bộ.
- `N2CuaTrung/Sources/StudyStore.swift`: lưu lựa chọn và tải nội dung theo bộ.
- `N2CuaTrung/Sources/ContentUpdates.swift`: gộp/tải/cập nhật gói và refresh.
- `content-packs/n2-series-*.json`: 4 gói dữ liệu độc lập.
- `content-packs/manifest-series.json`: danh sách tải cập nhật từ GitHub.
- `scripts/validate_series_packs.py`: kiểm tra dữ liệu không bị thiếu/trùng.
- `scripts/render_series_selector_preview.py`: xem trước trước khi duyệt build.

© 2026 Trần Phước Trung. Bảo lưu mọi quyền với mã và nội dung tự biên soạn của dự án.
