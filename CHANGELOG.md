# CHANGELOG

Quy ước: mỗi bước thêm một mục mới ở TRÊN CÙNG, gồm: ngày giờ, tên bước, các thay đổi, file bị ảnh hưởng.

## [Bước 4] Tích hợp AI OCR và Trích xuất Regex - 2026-10-06 19:58
### Đã thực hiện
- Xóa file giữ chỗ `lib/services/.gitkeep` và `lib/utils/.gitkeep`.
- Xây dựng `OcrService` (`lib/services/ocr_service.dart`): Tích hợp `google_mlkit_text_recognition` xử lý offline với `TextRecognizer(script: TextRecognitionScript.latin)` và giải phóng tài nguyên `close()`.
- Xây dựng `RegexHelper` (`lib/utils/regex_helper.dart`):
  - `extractAmount`: bóc tách số tiền với định dạng Việt Nam (`150.000`, `150,000 VND`, `150k`), áp dụng heuristic ưu tiên dòng chứa từ khóa tổng tiền và nửa dưới hóa đơn.
  - `extractDate`: bóc tách ngày tháng theo định dạng `dd/MM/yyyy`, `yyyy-MM-dd`, `dd-MM-yyyy`.
  - `extractMerchantName`: nhận diện thương hiệu/cửa hàng qua từ khóa đặc trưng (WinMart, Highlands, Circle K...) hoặc fallback dòng đầu tiên hợp lệ.
- Nâng cấp `ReviewTransactionScreen` (`lib/screens/review_transaction_screen.dart`) thành `StatefulWidget`:
  - Tự động gọi OCR và trích xuất dữ liệu khi có `imagePath`.
  - Hiển thị thumbnail ảnh hóa đơn ở nửa trên.
  - Form nhập liệu ở nửa dưới với các `TextFormField` cho phép người dùng kiểm tra và chỉnh sửa.
  - Nút "Lưu giao dịch" chuẩn bị cho tích hợp cơ sở dữ liệu.
- Viết bộ Unit Test toàn diện `test/regex_helper_test.dart` (15 test cases) kiểm thử các kịch bản bóc tách dữ liệu hóa đơn.
### File ảnh hưởng
- `lib/services/.gitkeep` (xóa)
- `lib/utils/.gitkeep` (xóa)
- `lib/services/ocr_service.dart` (tạo mới)
- `lib/utils/regex_helper.dart` (tạo mới)
- `lib/screens/review_transaction_screen.dart` (chỉnh sửa)
- `test/regex_helper_test.dart` (tạo mới)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- Pipeline OCR và bóc tách dữ liệu hoạt động 100% offline trên thiết bị Android, bảo đảm quyền riêng tư và tốc độ xử lý tức thì.

## [Bước 3] Xử lý Camera và Kính ngắm - 2026-10-06 19:48
### Đã thực hiện
- Khai báo quyền Camera trong `android/app/src/main/AndroidManifest.xml`: `<uses-permission android:name="android.permission.CAMERA"/>`.
- Nâng cấp `ScannerScreen` thành `StatefulWidget` tích hợp logic Camera:
  - Tự động phát hiện camera sau (`availableCameras()` + `CameraLensDirection.back`).
  - Khởi tạo `CameraController` với `ResolutionPreset.high`, `enableAudio: false`, và quản lý vòng đời `dispose()`.
  - Dựng giao diện phân lớp bằng `Stack`:
    - Lớp nền: `CameraPreview` (kèm loading indicator khi controller đang khởi tạo hoặc thông báo lỗi nếu không tìm thấy camera).
    - Lớp giữa: Kính ngắm Viewfinder (`CustomPainter`) dạng hình chữ nhật bo góc với viền màu nổi bật, góc nhấn trắng và vùng mờ xung quanh hướng dẫn căn chỉnh hóa đơn.
    - Lớp điều khiển: Nút bật/tắt đèn Flash (`setFlashMode`: torch/off) và nút chụp ảnh to ở giữa cạnh dưới.
  - Xử lý hành động chụp ảnh (`takePicture()`): lưu file ảnh và điều hướng sang `ReviewTransactionScreen` mang theo tham số đường dẫn ảnh `file.path`.
- Cập nhật `test/widget_test.dart`: tối ưu kiểm thử điều hướng sang ScannerScreen bằng `tester.pump(duration)` tránh timeout do hoạt họa loading vô hạn của `CircularProgressIndicator`.
### File ảnh hưởng
- `android/app/src/main/AndroidManifest.xml` (chỉnh sửa)
- `lib/screens/scanner_screen.dart` (chỉnh sửa)
- `test/widget_test.dart` (chỉnh sửa)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- Pipeline chụp ảnh và chuyển tiếp đường dẫn file ảnh sang ReviewTransactionScreen đã sẵn sàng để tích hợp Google ML Kit OCR ở Bước 4.

## [Bước 2] Dựng bộ khung UI và Routing - 2026-10-06 19:30
### Đã thực hiện
- Tạo các màn hình giao diện dạng StatelessWidget với routeName tĩnh:
  - `lib/screens/dashboard_screen.dart` (`routeName = '/'`): Scaffold gồm AppBar "Dashboard", FloatingActionButton icon camera chuyển hướng tới ScannerScreen.
  - `lib/screens/scanner_screen.dart` (`routeName = '/scanner'`): Scaffold gồm AppBar "Scanner".
  - `lib/screens/review_transaction_screen.dart` (`routeName = '/review'`): Scaffold gồm AppBar "Review Transaction", nhận tham số tùy chọn `imagePath`.
- Xóa `lib/screens/.gitkeep`.
- Cấu hình routing tại `lib/main.dart`:
  - `useMaterial3: true` và `ColorScheme.fromSeed(seedColor: Colors.deepPurple)`.
  - Thiết lập `initialRoute: DashboardScreen.routeName` (không dùng thuộc tính `home`).
  - Định nghĩa bảng `routes` cố định cho Dashboard và Scanner.
  - Cấu hình `onGenerateRoute` trích xuất `settings.arguments` truyền làm `imagePath` cho ReviewTransactionScreen.
  - Cấu hình `onUnknownRoute` điều hướng fallback về DashboardScreen.
- Cập nhật 3 widget tests trong `test/widget_test.dart` kiểm tra hiển thị Dashboard, chuyển màn hình khi bấm FAB, và dựng ReviewTransactionScreen khi imagePath là null.
### File ảnh hưởng
- `lib/screens/.gitkeep` (xóa)
- `lib/screens/dashboard_screen.dart` (tạo mới)
- `lib/screens/scanner_screen.dart` (tạo mới)
- `lib/screens/review_transaction_screen.dart` (tạo mới)
- `lib/main.dart` (chỉnh sửa)
- `test/widget_test.dart` (chỉnh sửa)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- Tách biệt rõ ràng static routes (không tham số) và dynamic route (`onGenerateRoute` nhận tham số ảnh chụp) tạo tiền đề vững chắc cho việc tích hợp Camera và OCR ở Bước 3.

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

