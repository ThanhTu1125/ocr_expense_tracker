# CHANGELOG

Quy ước: mỗi bước thêm một mục mới ở TRÊN CÙNG, gồm: ngày giờ, tên bước, các thay đổi, file bị ảnh hưởng.

## [Bước 1] Khởi tạo dự án - 2026-10-02 00:54
### Đã thực hiện
- Khởi tạo dự án Flutter `ocr_expense_tracker` (chỉ Android, org: `com.example`).
- Thêm dependencies:
  - `camera`: ^0.12.1 (thực tế: 0.12.1)
  - `google_mlkit_text_recognition`: ^0.17.1 (thực tế: 0.17.1)
  - `path_provider`: ^2.1.6 (thực tế: 2.1.6)
  - `provider`: ^6.1.5+1 (thực tế: 6.1.5+1)
  - `path`: ^1.9.1 (thực tế: 1.9.1)
  - `intl`: ^0.20.3 (thực tế: 0.20.3)
  - `isar_community`: ^3.3.2 (thực tế: 3.3.2)
  - `isar_community_flutter_libs`: ^3.3.2 (thực tế: 3.3.2)
  - `cupertino_icons`: ^1.0.8 (thực tế: 1.0.9)
- Thêm dev_dependencies:
  - `flutter_test`: sdk flutter (thực tế: 0.0.0)
  - `flutter_lints`: ^6.0.0 (thực tế: 6.0.0)
  - `build_runner`: ^2.4.13 (thực tế: 2.15.1)
  - `isar_community_generator`: ^3.3.2 (thực tế: 3.3.2)
- Cấu hình Android: đặt `minSdk = 21` trong `android/app/build.gradle.kts` (thay thế `flutter.minSdkVersion`) do yêu cầu minSdk của `camera`, `google_mlkit_text_recognition` và `isar_community_flutter_libs`. Giữ nguyên `compileSdk` và `targetSdk`.
- Tạo cấu trúc thư mục trong `lib/`: `models/`, `screens/`, `services/`, `utils/`, `widgets/` với mỗi thư mục chứa file `.gitkeep` rỗng.
- Thay màn hình demo counter mặc định trong `lib/main.dart` bằng `MaterialApp` tối giản hiển thị tiêu đề "OCR Expense Tracker" và dòng text "Project initialized".
- Cập nhật smoke test trong `test/widget_test.dart` khớp với UI tối giản mới.
### File ảnh hưởng
- `pubspec.yaml`
- `pubspec.lock`
- `android/app/build.gradle.kts`
- `lib/main.dart`
- `test/widget_test.dart`
- `lib/models/.gitkeep`
- `lib/screens/.gitkeep`
- `lib/services/.gitkeep`
- `lib/utils/.gitkeep`
- `lib/widgets/.gitkeep`
- `CHANGELOG.md`
- `DEV_HISTORY.md`
### Ghi chú
- Do `isar_flutter_libs 3.1.0+1` thiếu thuộc tính `namespace` trong `build.gradle` khi biên dịch với Android Gradle Plugin 8.x+, dự án đã được thống nhất chuyển sang bản fork chính thức tương thích `isar_community` (v3.3.2) cùng `isar_community_flutter_libs` và `isar_community_generator`.
- Từ Bước 2 trở đi, các file model và service sẽ import thư viện Isar dưới dạng `package:isar_community/isar.dart`.

