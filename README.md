# N2 của Trung — Ứng dụng iOS native (SwiftUI)

**Tác giả:** Trần Phước Trung  
**Bản quyền:** © 2026 Trần Phước Trung. Bảo lưu mọi quyền.  
**Tuyên bố trong ứng dụng:** “Ứng dụng học JLPT N2 do Trần Phước Trung tạo”. Thông tin tác giả và bản quyền hiển thị tại trang Giới thiệu, trang chủ, mục Tiến độ và metadata iOS (`NSHumanReadableCopyright`).

**Đây là dự án iPhone gốc (SwiftUI), không phải website, PWA hay WebView.** Mục tiêu iOS 16+; dữ liệu học được đóng gói nội bộ, không gọi API hay yêu cầu đăng nhập/mạng để học.

## Đã lập trình trong bản native đầu tiên

- Màn hình trang chủ cá nhân hóa `N2 của Trung`, tổng quan tuần học và kết quả ban đầu **3/6** (ghi nhận riêng).
- Flashcard từ vựng lật thẻ, phát âm câu ví dụ, bộ lọc đến tuần/cần ôn/toàn bộ, ôn cách quãng 1/3/7/14/30/60/90 ngày.
- Flashcard ngữ pháp, danh sách ngữ pháp và nội dung chi tiết Nhật–Việt.
- Danh sách Kanji kèm nghĩa, âm On/Kun, từ ghép và phát âm.
- Trắc nghiệm từ vựng, ngữ pháp, Kanji, đọc hiểu và nghe hiểu, chấm điểm và giải thích.
- Đề luyện tập 20 câu, có bộ đếm 12 phút và thống kê kết quả.
- Lộ trình 35 tuần (02/11/2026 – 04/07/2027), có chọn tuần thủ công.
- Điểm và tiến độ lưu bằng `UserDefaults` trên thiết bị, có xuất và nhập sao lưu JSON trong mục Tiến độ.
- Giọng Nhật `AVSpeechSynthesizer` của iOS; để hoạt động offline cần thiết bị có giọng Nhật tương thích được cài sẵn. Không bao gồm tệp MP3 gốc của đề thi.

**Nội dung học hiện có:** 125 từ vựng, 59 ngữ pháp, 65 Kanji, 8 bài đọc, 6 bài nghe, 35 tuần. Đây là dữ liệu bước đầu, chưa đủ toàn bộ kiến thức N2. Nội dung từ bộ app trước được chuyển nguyên sang `N2CuaTrung/Resources/content.json`.

## Trạng thái build

- Swift models đã được `swiftc -typecheck` và chạy kiểm tra dữ liệu/bộ câu hỏi trên Linux.
- Các file SwiftUI đã được `swiftc -frontend -parse` để kiểm tra cú pháp.
- **Chưa biên dịch và thử trên iPhone/iOS SDK trong môi trường tạo gói** (không có Xcode/macOS). GitHub Actions được tạo để chạy bước này trên máy Mac của GitHub.
- **ZIP này là mã nguồn iOS native và cấu hình CI; chưa chứa IPA đã biên dịch/ký.**

## Cách tạo IPA qua GitHub Actions bằng Windows (không cần Mac riêng)

1. Giải nén tệp ZIP, tạo một repository GitHub mới.
2. Upload **các file bên trong thư mục `N2_cua_Trung_Native_iOS`** vào thư mục gốc repository, bao gồm thư mục ẩn `.github`.
3. Vào tab **Actions** → chọn **Build Native iOS IPA (unsigned)** → **Run workflow**. Hoặc commit vào nhánh `main` sẽ chạy workflow tự động.
4. Chờ GitHub Actions biên dịch (log hiển thị trong job `build-ios`). Nếu build thành công, ở phần **Artifacts** sẽ có `N2-cua-Trung-iOS-unsigned-IPA`.
5. Tải Artifact ZIP, giải nén lấy `N2_cua_Trung_unsigned.ipa`.

Workflow tự cài XcodeGen (nếu cần), tạo project Xcode, gọi `xcodebuild` trên macOS runner và đóng gói app native. IPA đầu ra **chưa ký** và không thể chỉ chạm để cài trực tiếp trên iPhone.

### Cài IPA trên iPhone bằng Windows

1. Dùng **Sideloadly chính thức** https://sideloadly.io/ trên Windows hoặc AltStore qua hướng dẫn https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows.
2. Kết nối iPhone bằng cáp, chọn tin cậy máy tính (Trust); cần phiên bản driver Apple được công cụ hỗ trợ.
3. Chọn IPA từ GitHub Actions và ký ứng dụng bằng Apple Account của bạn trong công cụ. **Không gửi mật khẩu cho người khác hoặc nhập vào website không đáng tin.**
4. Trên iPhone, nếu cần, vào **Cài đặt → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển** và bật theo hướng dẫn hệ thống; xác nhận ứng dụng nhà phát triển trong **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị**.
5. Mở biểu tượng **N2 của Trung**. Sau khi tải app vào máy, các bài học trong `content.json` sử dụng offline.

**Giới hạn tài khoản Apple miễn phí:** hồ sơ cài ứng dụng có thời hạn 7 ngày và phải ký/cài lại để tiếp tục sử dụng. Đây là quy định của Apple, không thể giải quyết chỉ bằng một IPA unsigned. Luôn sao lưu tiến độ trước khi gỡ cài đặt. Nếu muốn phân phối qua TestFlight/App Store hoặc ký ổn định dài hạn, phải thiết lập Apple Developer Program và quy trình ký hợp lệ.

## Xcode trên Mac (nếu có sau này)

```bash
brew install xcodegen
xcodegen generate --spec project.yml
open N2CuaTrung.xcodeproj
```

Trong Signing & Capabilities chọn tài khoản Apple, kiểm tra Bundle ID `vn.trung.n2master2027`, chọn iPhone và Run.

## Cấu trúc dự án

- `project.yml`: cấu hình XcodeGen, iOS 16+.
- `.github/workflows/build-ios.yml`: CI build iPhone IPA unsigned.
- `N2CuaTrung/Sources/`: mã SwiftUI gốc, models, ôn cách quãng, bài tập, âm thanh hệ thống, sao lưu, màn hình Giới thiệu và bản quyền.
- `N2CuaTrung/Resources/content.json`: nội dung bài học đóng gói nội bộ.
- `N2CuaTrung/Assets.xcassets/`: biểu tượng app.
- `LO_TRINH_35_TUAN.md`: mục tiêu học theo tuần.
- `INSTALL_IPHONE_WINDOWS.md`: thao tác triển khai ngắn gọn.

## Các giới hạn còn lại

Ứng dụng chưa có ngân hàng đề N2 đầy đủ, audio MP3 bản quyền, viết Kanji bằng tay, nhận dạng phát âm và đồng bộ iCloud. Nội dung luyện đề được biên soạn độc lập, không sử dụng nguyên đề thi hoặc nội dung sách trả phí khi chưa được phép. Mỗi đợt nâng cấp nội dung phải kiểm tra độ chính xác của bài học.

## Kho dữ liệu cập nhật độc lập (v1.2)

- Vào **Tiến độ → Cập nhật kho bài học**, chọn **Kiểm tra bài học mới** khi có mạng.
- Có thể tải riêng `content-packs/n2-expansion-01.json` vào iPhone qua ứng dụng Tệp và chọn **Nhập gói học JSON từ Tệp**.
- Nội dung mới được lưu trong Application Support, tiếp tục học offline sau khi tải. Dữ liệu lịch ôn và điểm số nằm trong kho riêng, không bị xóa khi cập nhật.
- `content-packs/manifest.json` công bố các gói mới để ứng dụng tải về theo phiên bản. Có thể bổ sung gói và cập nhật manifest mà không cần build IPA mới.
- Mỗi mục có ID ổn định; bản cập nhật gói có cùng ID, phiên bản tăng sẽ thay thế nội dung cùng ID mà giữ lịch sử thẻ.
- Bài nghe trong gói khởi đầu dùng giọng đọc tiếng Nhật có sẵn trên máy, không phải audio chính thức của JLPT.
- Đây là nội dung luyện thi JLPT N2 định hướng, **không phải danh sách từ vựng chính thức do JLPT công bố**.

**Tác giả:** Trần Phước Trung — © 2026 Trần Phước Trung. Bảo lưu mọi quyền.

## iOS 1.4 — Nhắc học + Widget dễ đọc

- Trong tab **Tiến độ → Nhắc học & Widget**, bật thông báo (quyền iOS) và chọn 1–4 lần/ngày; lập lịch tối đa 14 ngày tới trong khoảng 09:00–21:00. Hoạt động offline khi đã được cấp quyền. App sẽ tự gia hạn lịch khi người dùng mở lại.
- Widget màn hình chính hỗ trợ **Medium (trọn một hàng)** và Large, nền xanh đậm chữ trắng. Widget màn hình khóa iOS `accessoryRectangular` có kích thước và cách hiển thị nền do iOS quản lý, không thể kéo dài bằng mã ứng dụng.
- Widget lên trước các mục `TimelineEntry` cách nhau 15 phút, nội dung đổi luân phiên; iOS có thể làm mới muộn. Không có API chính thức để nhận sự kiện khóa/mở khóa và buộc widget cập nhật ngay.
- **Bảng học rộng Live Activity** (iOS 16.1+) là tùy chọn do người dùng bật thủ công, xuất hiện ở khu vực lớn hơn phía dưới đồng hồ. Live Activity hoạt động tối đa 8 giờ, có thể lưu trên màn hình khóa thêm tối đa 4 giờ; không tự thay đổi ở mỗi lần mở khóa.
- Không sử dụng máy chủ, push token, Apple App Groups hay quyền đặc biệt. Thông báo và dữ liệu đều ở thiết bị.
- Tác giả và bản quyền: **© 2026 Trần Phước Trung. Bảo lưu mọi quyền.**

## iOS v1.5 — Giọng đọc tự nhiên và kho N2 mở rộng

- Flashcard tự phát âm Hiragana khi vừa lật sang mặt sau; có nút nghe lại từ và nghe câu ví dụ.
- Phần Giọng đọc cho phép chọn giọng Nhật offline cài trên iPhone, mặc định ưu tiên Premium/Enhanced; mô phỏng hội thoại nam/nữ bằng giọng tương ứng nếu có.
- Gói bổ sung `openjlpt-n2-core.json` phiên bản 2 có đầy đủ 3 ví dụ cho từng ngữ pháp; có 1.756 từ vựng, 93 ngữ pháp, 376 Kanji mới sau khi lọc trùng. Tải qua mục **Tiến độ → Cập nhật kho bài học** sau khi có mạng, rồi sử dụng offline.
- Tổng kho lý thuyết sau khi cài cả hai gói: 1.974 từ vựng, 176 ngữ pháp, 471 Kanji (chưa kiểm chứng chuyên môn từng mục). Nhiều mục mới có nghĩa tiếng Anh (`EN ·`), đang chờ biên tập Nhật–Việt.
- Dữ liệu mở N2 phân phối CC BY-SA 4.0 (đọc `content-packs/OPENJLPT_SOURCES_AND_LICENSE.md`) và không phải nội dung chính thức của kỳ thi JLPT.
- Không tự động lấy audio từ các website thương mại. Không kèm nhạc/âm thanh không rõ giấy phép.

## iOS v1.6 — Chế độ offline mặc định

- Hai gói `n2-expansion-01.json` và `openjlpt-n2-core.json` được đóng gói sẵn trong bản IPA để học ngay không cần Internet. Bản cập nhật tải sau ưu tiên phiên bản mới hơn.
- Vuốt lên/xuống trên mặt thẻ từ vựng để sang thẻ đã xáo trộn, không lặp lại trong cùng một lượt.
- Trắc nghiệm tự chuyển sau 0,85 giây xem đáp án, nút tiếp vẫn hoạt động.
- Live Activity căn giữa, chữ lớn; tùy chọn 30/60 giây chỉ chạy khi app còn hoạt động ở foreground. iOS không cho phép bảo đảm đổi mỗi 30/60 giây khi thiết bị khóa.
- Mục giấy phép dữ liệu được tách khỏi giao diện học nhưng luôn có thể truy cập trong Giới thiệu, theo điều kiện nguồn CC BY-SA 4.0.

## Bổ sung học liệu N2 do N2 của Trung biên soạn — v1.7

- Đã có sẵn trong ứng dụng offline: **28 từ vựng mới, 4 mẫu ngữ pháp có 3 ví dụ mỗi mẫu, 6 bài đọc hiểu có câu hỏi và 6 bài nghe hiểu có lời thoại, đáp án và giải thích**.
- Màn hình Flashcard lật mặt sau: từ, Hiragana, nghĩa tiếng Việt và câu Nhật kèm dịch tiếng Việt.
- Bài nghe dùng chức năng phát giọng Nhật của iOS (TTS); không bao gồm tệp audio đã thu âm từ website hoặc bản ghi JLPT chính thức.
- Kho học mới được lưu tại `content-packs/vn26-original-practice-01.json` và được đóng gói trực tiếp vào IPA và widget; có thể dùng offline.
- Các website Nhật–Việt trong `research/NGUON_HOC_NHAT_VIET_CHO_N2.md` chỉ được tham khảo để xác minh khái niệm và tự biên soạn, không sao chép nguyên bài giảng/sách/audio từ các trang chưa cấp phép.
- Để cải thiện chất lượng, tiếp tục kiểm tra ngữ pháp và những bản dịch do máy tạo ra trong `content-packs/openjlpt-n2-core.json`.
