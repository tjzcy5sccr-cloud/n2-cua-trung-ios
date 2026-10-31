# N2 của Trung — Kho nghiên cứu 6.000 từ · 1.100 Kanji · 150 ngữ pháp

**Trạng thái:** ĐÃ TẬP HỢP NGUỒN, **CHƯA THẨM ĐỊNH TỪNG MỤC VÀ CHƯA ĐƯỢC ĐƯA VÀO IPA**.

Nhánh: `feature/n2-four-series-roadmap-2027`. Nhánh `main` và IPA cũ không thay đổi.

## Kết quả chạy nguồn dữ liệu mở đã khóa phiên bản

| Loại | Ứng viên trong hàng đợi | Thuộc N5–N2 / N3 chuyển tiếp | Mở rộng N1 (tùy chọn) | Gợi ý nghĩa Việt (chưa duyệt) |
|---|---:|---:|---:|---:|
| Từ vựng | **6.000** | **4.741** mục N5–N2 | 1.259 | 5.626 |
| Kanji | **1.100** | **1.038** chữ N5–N2 | 62 | 925 |
| Ngữ pháp | **150** | **123 mẫu N2 + 27 mẫu N3** | 0 | Chưa có bản dịch Việt đã duyệt |

Bộ thủ: **214 mục theo Unicode U+2F00–U+2FD5**, có ánh xạ chữ gốc, không tự đoán tên Hán–Việt.

### Các giới hạn cần phân biệt

- **6.000/1.100/150 là quy mô hàng đợi biên tập, không phải 6.000/1.100/150 bài học đã đúng 100% trong ứng dụng.** Mọi mục trong hàng đợi mang `reviewStatus: candidate_only_not_approved` và `canPublishInIPA: false`.
- **N1 extension** chỉ để đạt mốc tích lũy theo yêu cầu; không nên học như phần bắt buộc của N2. Những mục đó có cờ `N1_extension_not_required_for_N2`. Bộ duyệt không nhập tự động N1 vào app.
- Cách đọc kana được lấy từ nguồn OpenJLPT nhưng nghĩa Việt từ điển Bunchaway chỉ khớp mặt chữ Nhật, **chưa xác minh đồng âm khác nghĩa, ngữ cảnh, từ loại hoặc cách đọc**.
- Ngữ pháp N2 đã ưu tiên đúng 123 mẫu N2 theo nguồn cộng đồng; 27 mẫu N3 để ôn chuyển tiếp. Không lấy N5/N4 lấp quota.
- JLPT không công bố danh sách từ vựng/Kanji/ngữ pháp chính thức sau năm 2010. Các mức trên là phân loại ước lượng từ nguồn mở.
- Không chép nội dung bốn bộ sách có bản quyền. `mimikara`, `shin-kanzen`, `sou-matome`, `speed-master` là **hướng học của ứng dụng**, không phải nội dung do các nhà xuất bản cấp phép.

## Cấu trúc

- `vocab-source-only.jsonl`: 6.000 ứng viên, cách đọc, nghĩa Anh OpenJLPT, gợi ý nghĩa Việt từ Bunchaway và cờ cần duyệt.
- `kanji-source-only.jsonl`: 1.100 chữ, On/Kun, nghĩa Anh và gợi ý nghĩa Việt chưa duyệt.
- `grammar-source-only.jsonl`: 150 cấu trúc cần biên tập nội dung Việt/giải thích/ví dụ.
- `214-radicals-source-only.json`: 214 bộ thủ Unicode, chưa thêm nghĩa Việt khi thiếu xác minh.
- `35-week-review-index.json`: ID từng mục được giao vào hàng đợi biên tập theo 35 tuần.
- `summary.json`: số liệu thật, mã commit nguồn, quyền tác giả và chất lượng.

## Quy trình đưa vào ứng dụng an toàn

1. Người biên tập kiểm **mặt chữ Nhật, kana, từ loại và nghĩa đúng theo ngữ cảnh**, ít nhất hai tham chiếu có nguồn rõ ràng.
2. Viết lại **một ví dụ tiếng Nhật và bản dịch Việt toàn câu** có nghĩa khớp mục đang học; ngữ pháp phải có giải thích và điều kiện dùng; Kanji có từ ghép chính xác.
3. Lưu quyết định kiểm tra vào một tệp JSONL `editorial-decisions.jsonl` theo định dạng dưới đây. Đó là dữ liệu cá nhân do dự án biên tập, **không tự tải một nguồn từ điển là mặc nhiên 'đã duyệt'**.
4. Chạy `python3 scripts/promote_reviewed_cumulative_candidates.py --decisions <file>` để xem trước, sau đó dùng `--apply` chỉ khi đã kiểm tra bản quyết định.
5. Chạy `scripts/validate_series_packs.py`, cập nhật manifest, xuất hình xem trước và **được người dùng duyệt** mới build IPA.
6. Trong app, **chế độ Tổng hợp và bốn bộ chọn riêng** vẫn chỉ lấy nội dung được duyệt. Tiến độ đã lưu không bị mất vì ID học liệu ổn định.

Ví dụ về cấu trúc tệp quyết định (giá trị minh họa, không được sử dụng làm chứng nhận học liệu):

```json
{
  "sourceId": "research-v-<mã đã có>",
  "series": "shin-kanzen",
  "week": 15,
  "reviewStatus": "editorial_reviewed",
  "meaningVi": "<nghĩa Việt đã kiểm trong ngữ cảnh>",
  "exampleJa": "<câu Nhật tự biên soạn>",
  "exampleVi": "<bản dịch Việt toàn câu>",
  "kanaChecked": true,
  "contextChecked": true,
  "reviewer": "<người biên tập>",
  "reviewedOn": "2026-10-31",
  "sourceReferences": ["https://<nguồn-1>", "https://<nguồn-2>"]
}
```

Không tạo tệp quyết định giả để chạy hàng loạt; dữ liệu nguồn mở cần kiểm duyệt độc lập từng trường.

## Quyền sử dụng

- **OpenJLPT**, commit `0d1d3410bec90bd4098a7c72de820543cb4f707c`: https://github.com/evanclan/OpenJLPT, CC BY-SA 4.0, bao gồm nguồn gốc có ghi công trong NOTICE.
- **Bunchaway Japanese–Vietnamese Dictionary**, commit `6b1e9248c5382949115ccf1f5e8846d0fc85d6ad`: https://github.com/bunchaway/tu-dien-nhat-viet, CC BY-SA 4.0.
- Sử dụng và phân phối lại **phần dữ liệu phái sinh** phải tuân thủ các điều kiện ghi công/chia sẻ tương tự; mã app độc lập thuộc dự án của Trần Phước Trung.

**Ứng dụng học JLPT N2 do Trần Phước Trung tạo**. © 2026 Trần Phước Trung — áp dụng với mã và nội dung nguyên gốc của dự án, không nhận bản quyền độc quyền của dữ liệu bên thứ ba.
