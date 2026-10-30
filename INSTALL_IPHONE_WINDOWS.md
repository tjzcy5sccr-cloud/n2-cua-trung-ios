# Đưa N2 của Trung lên iPhone từ Windows

1. Giải nén ZIP mã nguồn native, mở GitHub → New repository → tạo `n2-cua-trung-ios`.
2. Upload **toàn bộ** file vào gốc repo, đặc biệt `.github/workflows/build-ios.yml`, `project.yml` và `N2CuaTrung/`.
3. GitHub → **Actions** → **Build Native iOS IPA (unsigned)** → **Run workflow**.
4. Khi workflow thành công, vào lần chạy → **Artifacts** → tải `N2-cua-Trung-iOS-unsigned-IPA` → giải nén lấy `.ipa`.
5. Mở Sideloadly trên Windows (https://sideloadly.io), cắm iPhone, chọn IPA và dùng Apple Account của chính bạn để ký/cài.
6. Nếu iOS hỏi, bật Developer Mode và tin cậy hồ sơ ứng dụng theo hướng dẫn cài đặt. Sau đó mở **N2 của Trung** từ màn hình chính.

**Lưu ý:** Apple Account miễn phí phải làm mới chữ ký mỗi 7 ngày. IPA unsigned từ Actions chưa cài trực tiếp bằng cách bấm vào file. Muốn TestFlight/App Store cần tư cách nhà phát triển và hồ sơ ký phù hợp.

**Đã kiểm tra:** dữ liệu JSON, models Swift và cấu trúc trắc nghiệm. **Chưa xác nhận:** build Xcode trên GitHub hoặc cài trên iPhone thật.
