# SETUP HISTORY - Nhật ký thiết lập môi trường Flutter

Quy ước: ghi lại việc đã làm, lỗi gặp phải, cách sửa, quyết định kỹ thuật. Mục mới nhất nằm TRÊN CÙNG. Không xóa hay viết đè lịch sử cũ.

## [Bước 0] Cài đặt môi trường Flutter - 2026-10-01 14:59
### Mục tiêu
Cài đặt, cấu hình hoàn chỉnh Flutter SDK (3.x, Dart 3) cho nền tảng Android trên Windows mà không cần quyền Administrator, đảm bảo lệnh `flutter` hoạt động trơn tru trong terminal và VS Code.

### Hiện trạng ban đầu
- Git đã được cài đặt (`git version 2.44.0.windows.1`).
- Flutter SDK: Chưa có trong PATH hệ thống. Đường dẫn cũ trong VS Code `C:\JavaWED\TestFlu\flutter` đã bị xóa.
- Thư mục `C:\src\flutter` tồn tại nhưng chỉ chứa dữ liệu git clone dở dang (`tmp_pack_ZO9HkN`), không có `bin/flutter.bat`.
- Android SDK: Đã có sẵn tại `C:\Users\ASUS\AppData\Local\Android\Sdk`, nhưng chưa cấu hình biến môi trường `ANDROID_HOME`.
- Java JDK: Đã có OpenJDK Temurin-21 tại `C:\Program Files\Eclipse Adoptium\jdk-21.0.8.9-hotspot`.
- VS Code: Version 1.139.1, chưa cài đặt tiện ích mở rộng `Dart-Code.dart-code` và `Dart-Code.flutter`.

### Các việc đã làm
1. **Kiểm tra ban đầu**: Kiểm tra Git (`git --version`), kiểm tra thư mục `C:\src\flutter` và kiểm tra lệnh `flutter` trong PATH.
2. **Xử lý thư mục dở dang**: Hỏi ý kiến người dùng và thực hiện dọn dẹp sạch sẽ thư mục `C:\src\flutter` cũ bằng `Remove-Item -Path "C:\src\flutter" -Recurse -Force`.
3. **Tải Flutter SDK**: Thực hiện `git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter`.
4. **Cấu hình biến môi trường PATH (User)**: Đọc PATH hiện tại, bổ sung `C:\src\flutter\bin` và lưu lại thông qua `[Environment]::SetEnvironmentVariable("Path", ..., "User")`. Làm mới PATH cho phiên làm việc hiện tại.
5. **Khởi tạo Flutter SDK**: Chạy `flutter --version` để Flutter tự động tải Dart SDK (3.13.4) và build các công cụ cần thiết.
6. **Cấu hình Android SDK & JDK**:
   - Chạy `flutter config --android-sdk "C:\Users\ASUS\AppData\Local\Android\Sdk"`.
   - Chạy `flutter config --jdk-dir "C:\Program Files\Eclipse Adoptium\jdk-21.0.8.9-hotspot"`.
   - Hỏi ý kiến người dùng và thiết lập biến môi trường User `ANDROID_HOME` trỏ tới `C:\Users\ASUS\AppData\Local\Android\Sdk`.
   - Tắt analytics: `flutter config --no-analytics`.
   - Tắt các nền tảng không dùng (chỉ giữ Android): `flutter config --no-enable-web --no-enable-windows-desktop --no-enable-linux-desktop --no-enable-macos-desktop`.
7. **Chấp nhận Android licenses**: Chạy `flutter doctor --android-licenses` và cấp quyền chấp thuận toàn bộ license của Android SDK.
8. **Cấu hình VS Code**:
   - Sao lưu `C:\Users\ASUS\AppData\Roaming\Code\User\settings.json` thành `settings.json.bak`.
   - Cập nhật key `"dart.flutterSdkPath": "C:\\src\\flutter"`.
   - Cài đặt tiện ích mở rộng cho VS Code: `code --install-extension Dart-Code.dart-code` và `code --install-extension Dart-Code.flutter`.
9. **Kiểm tra Developer Mode**: Kiểm tra registry `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\AllowDevelopmentWithoutDevLicense`, xác nhận đã bật (`0x1`).
10. **Kiểm tra tổng thể**: Chạy `flutter doctor -v` và `flutter devices` để xác thực toàn bộ môi trường.

### Sự cố & cách sửa
| # | Lỗi/vấn đề (trích log ngắn) | Nguyên nhân | Cách sửa | Kết quả |
|---|---|---|---|---|
| 1 | `C:\src\flutter` đã tồn tại nhưng không có `bin/flutter.bat` (chỉ có `.git/objects/pack/tmp_pack_ZO9HkN`) | Clone trước đó bị gián đoạn giữa chừng | Hỏi ý kiến người dùng, dùng `Remove-Item` xóa sạch thư mục dở dang rồi thực hiện `git clone` lại từ đầu | Thư mục được clone hoàn chỉnh, file `C:\src\flutter\bin\flutter.bat` tồn tại |
| 2 | Biến môi trường `ANDROID_HOME` chưa được thiết lập | Hệ thống chưa cấu hình biến môi trường này ở mức User | Hỏi ý kiến người dùng và thiết lập `ANDROID_HOME` = `C:\Users\ASUS\AppData\Local\Android\Sdk` ở mức User | `ANDROID_HOME` nhận diện chính xác trong `flutter doctor` |

### Quyết định kỹ thuật
- **Vị trí cài đặt**: Đặt tại `C:\src\flutter` để tránh đường dẫn có khoảng trắng (space) và tránh các thư mục bảo vệ quyền hạn chế như `C:\Program Files`, giúp Flutter update và chạy tool mà không đòi hỏi quyền Admin.
- **Phương thức cài đặt**: Sử dụng `git clone -b stable` theo chuẩn của Flutter, giúp dễ quản lý branch và nâng cấp sau này (`flutter upgrade`).
- **Phiên bản**: Flutter 3.47.5 (Dart 3.13.4), phù hợp hoàn hảo với yêu cầu dự án Flutter 3.x / Dart 3.
- **Tối ưu nền tảng**: Tắt các tính năng build desktop (Windows, Linux, macOS) và Web trong cấu hình Flutter để giảm thời gian build và dung lượng cache, chỉ tập trung vào Android.

### Thay đổi hệ thống
- **User PATH**: Thêm `C:\src\flutter\bin` (không ghi đè, không trùng lặp).
- **User ANDROID_HOME**: Đặt giá trị `C:\Users\ASUS\AppData\Local\Android\Sdk`.
- **VS Code settings.json**: Cập nhật `"dart.flutterSdkPath": "C:\\src\\flutter"`. Đã sao lưu bản dự phòng `settings.json.bak`.
- **VS Code Extensions**: Cài đặt `Dart-Code.dart-code` (v3.144.0) và `Dart-Code.flutter` (v3.144.0).
- **Flutter Config**: Cấu hình Android SDK, JDK, tắt analytics và desktop/web platforms.

### Kết quả kiểm tra
- `flutter --version`:
  - Flutter 3.47.5 (channel stable)
  - Dart 3.13.4
  - DevTools 2.60.0
- `flutter doctor -v`:
  - [√] Flutter: Đạt (channel stable 3.47.5, framework revision 6a19cca564)
  - [√] Windows Version: Đạt (Windows 11)
  - [√] Android toolchain: Đạt (Android SDK 35.0.0, platform android-36, build-tools 35.0.0, JDK 21 Temurin, toàn bộ license đã được chấp thuận)
  - [√] Network resources: Đạt
  - [!] Connected device: Chưa phát hiện thiết bị kết nối (sẵn sàng kết nối ở bước sau)
- Developer Mode: Đã bật (`0x1`).
- VS Code Extensions: Cả 2 tiện ích Dart và Flutter đều đã cài đặt thành công.

### Việc tồn đọng / lưu ý cho Bước 1
- Chuẩn bị thiết bị: Kết nối điện thoại Android vật lý (bật tính năng Developer options & USB Debugging) hoặc tạo máy ảo Android Emulator nếu muốn test chạy app ở Bước 1.
- Tích hợp lịch sử: Nội dung nhật ký Bước 0 này sẽ được chuyển vào `DEV_HISTORY.md` của dự án khi bắt đầu Bước 1.
