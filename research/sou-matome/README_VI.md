# Sou Matome N2 – nhánh dữ liệu và thư viện sách cá nhân

## Trạng thái thực tế

- Đã kiểm kê **5 cuốn chính**, **3 PDF bổ trợ** và **116 MP3** từ 5 tệp người dùng cung cấp (4 RAR, 1 PDF).
- Sách chính: Kanji (177 trang), Goi (156), Bunpou (156), Dokkai (121), Choukai (73).
- Bổ trợ: Kanji tiếng Việt (208 trang), Goi bổ trợ (163), Bunpou tiếng Việt (185).
- CD1 có 64 tệp MP3, CD2 có 52 tệp MP3, đều đánh số liên tục từ 01.
- Tổng PDF: **1.239 trang**. Đây là tổng số trang tệp, không phải số bài học đã chuyển thành dữ liệu.
- Mục lục tuần/chương của 5 sách chính đã đối chiếu, có nút nhảy trang; tài liệu tiếng Việt có bố cục khác nên không tự ghép trang chưa xác minh.
- Gói riêng Sou Matome **phiên bản 7** có 346 bản ghi nguồn: 203 từ vựng, 62 ngữ pháp, 74 Kanji, 4 đọc, 3 nghe. Sau lọc nội dung đã duyệt, IPA đóng gói **172 từ vựng, 47 ngữ pháp, 57 Kanji, 4 đọc, 3 nghe = 283 mục học**. Không khẳng định đây là bản số hóa đầy đủ sách.

## Thao tác trên app iOS mới

1. Vào **Hôm nay → Chọn bộ dữ liệu → Nihongo Sou Matome**. Các màn flashcard/luyện tập sẽ thay kho JSON theo bộ đã chọn; tiến độ được giữ.
2. Bấm **Sou Matome – Sách và CD của bạn**; cũng có phím tắt từ Trang chủ khi đang chọn Sou Matome.
3. Trong **Thư viện cá nhân**, bấm **Chọn nhiều PDF cùng lúc** để nhập cả 8 cuốn theo tên/số trang, hoặc nhập từng cuốn bằng nút **Nhập PDF**, rồi **Đọc sách**. Có nút chọn tuần/chương, chuyển trang, ghi nhớ trang đang đọc.
4. Chọn **Nhập thư mục audio CD** để nhập folder CD1, CD2 hoặc thư mục mẹ có cả hai (cần giải nén RAR trước). Nghe trực tiếp offline, dừng/tạm dừng và tua thanh thời gian.
5. Các sách và CD nhập vào được **sao chép riêng vào Application Support** của app trên thiết bị; không được upload lên GitHub. Phải có đủ dung lượng trống trên iPhone.

### Chuẩn bị từ Windows

Chạy `scripts/prepare_sou_matome_for_iphone.ps1` từ thư mục chứa 5 file nguồn và có 7-Zip. Script chỉ giải nén/copy về thư mục cá nhân `SouMatome_N2_Import_iPhone`, chia `Books/` và `Audio-CD/CD1`, `Audio-CD/CD2`. Chuyển thư mục này vào **Tệp** trên iPhone qua phương thức đồng bộ riêng của người dùng. Dùng các nút nhập trong app để tải vào bộ nhớ ứng dụng.

### Giới hạn bản hiện tại

**Chưa phải bản chuyển đổi 100% từng từ, từng ngữ pháp, từng câu hỏi từ sách thành bài học tương tác.** Các sách chính là PDF scan nên cần trích xuất, rà soát từng mục, kiểm tra nghĩa và đáp án; không thể coi một bộ flashcard mẫu 275 mục là đã trùng khớp toàn bộ 1.239 trang sách. Thư viện hiện cho phép truy cập toàn bộ **tài liệu riêng của người dùng** ở dạng sách đọc/MP3, không sao chép nội dung thương mại vào GitHub công khai.

Nguồn dữ liệu JSON đã có từ nhánh gốc và có thể tiếp tục mở rộng riêng bằng những bài học tự biên soạn, được phép sử dụng hoặc đã kiểm duyệt. Việc sửa nội dung JSON chỉ tăng version cùng id của bộ Sou Matome; giữ lại dữ liệu của Mimikara, Shin Kanzen, Speed Master và chế độ Tổng hợp N2.

### Về IPA

Nhánh riêng tạo từ `feature/n2-four-series-roadmap-2027` và không sửa `main`. Có kiểm thử mã/dữ liệu `check-sou-matome-library.yml`, và workflow macOS `build-sou-matome-test.yml` biên dịch IPA thử nghiệm **1.9.2 (build 12)**. File IPA này **chưa ký số**; phải được ký hợp lệ trước khi cài lên iPhone thông thường. Chỉ sách và MP3 mà người dùng nhập từ Tệp mới nằm trong thư viện riêng, không nằm trong IPA tải trên GitHub.
