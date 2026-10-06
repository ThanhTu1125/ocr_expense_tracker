# DEV HISTORY - Nhật ký phát triển OCR Expense Tracker
Quy ước: ghi lại việc đã làm, lỗi gặp phải, cách sửa, quyết định kỹ thuật. Mục mới nhất nằm TRÊN CÙNG. Không xóa hay viết đè lịch sử cũ.

## [Bước 2] Dựng bộ khung UI và Routing - 2026-10-06 19:30
### Mục tiêu
Xây dựng khung giao diện cơ bản (UI skeleton) cho 3 màn hình cốt lõi (Dashboard, Scanner, Review Transaction), thiết lập hệ thống điều hướng đặt tên (named routes) kết hợp route động, và cập nhật bộ kiểm thử tự động (widget test).

### Các việc đã làm
1. **Kiểm tra Pre-flight**:
   - `git ls-files android/build/`: Không có file build nào bị theo dõi bởi Git.
   - `git status`: Working tree hoàn toàn sạch (`nothing to commit, working tree clean`).
   - `git log --oneline -n 3`: Ghi nhận commit gần nhất `3adce3c chore: init flutter project, libraries, folder structure`.
   - `flutter --version`: Xác nhận Flutter 3.47.5 stable, Dart 3.13.4.
2. **Tạo các màn hình giao diện (StatelessWidget)**:
   - Xóa file giữ chỗ: `Remove-Item -Path "lib/screens/.gitkeep" -Force`.
   - Tạo `lib/screens/dashboard_screen.dart` với `static const routeName = '/'`, AppBar "Dashboard", và FloatingActionButton icon `Icons.camera_alt` chuyển hướng tới `ScannerScreen.routeName`.
   - Tạo `lib/screens/scanner_screen.dart` với `static const routeName = '/scanner'`, AppBar "Scanner".
   - Tạo `lib/screens/review_transaction_screen.dart` với `static const routeName = '/review'`, nhận tham số tùy chọn `final String? imagePath`, AppBar "Review Transaction".
3. **Cấu hình định tuyến tại `lib/main.dart`**:
   - Khởi tạo MaterialApp với `useMaterial3: true` và `ColorScheme.fromSeed(seedColor: Colors.deepPurple)`.
   - Cấu hình `initialRoute: DashboardScreen.routeName`, không dùng thuộc tính `home`.
   - Bảng `routes`: đăng ký `DashboardScreen` và `ScannerScreen`.
   - Hàm `onGenerateRoute`: bắt route `ReviewTransactionScreen.routeName`, trích xuất `settings.arguments` kiểm tra kiểu `String` để gán vào `imagePath`.
   - Hàm `onUnknownRoute`: bắt các route không hợp lệ và fallback về `DashboardScreen`.
4. **Cập nhật và thực thi kiểm thử (`test/widget_test.dart`)**:
   - Viết 3 test case: (1) Dashboard hiển thị đúng AppBar & FAB; (2) Nhấn FAB điều hướng sang Scanner; (3) ReviewTransactionScreen dựng thành công khi `imagePath` là null.
   - Chạy kiểm thử: `flutter test`.
5. **Kiểm tra chất lượng và build APK**:
   - Chạy `flutter analyze`: Đạt 0 issues.
   - Chạy `flutter test`: Đạt 3/3 tests passed.
   - Chạy `flutter build apk --debug`: Build thành công ra `app-debug.apk` trong 136.4s.
   - Kiểm tra thiết bị: `flutter devices` (chưa có thiết bị kết nối).

### Sự cố & cách sửa
| # | Lỗi/vấn đề (trích log ngắn) | Nguyên nhân | Cách sửa | Kết quả |
|---|---|---|---|---|
| 1 | `Expected: exactly one matching candidate. Actual: Found 2 widgets with text "Dashboard"` và `Found 2 widgets with text "Review Transaction"` khi chạy `flutter test` lần 1 | Tiêu đề trong AppBar và nội dung placeholder trong body của màn hình đều cùng mang chuỗi text giống nhau ("Dashboard", "Review Transaction"), khiến matcher `find.text()` tìm thấy 2 widget | Bỏ placeholder trùng lặp trong body của `DashboardScreen` và `ReviewTransactionScreen`, giữ nguyên AppBar để tiêu đề là duy nhất | Cả 3 test case trong `flutter test` pass 100% |

### Quyết định kỹ thuật
- **Kết hợp `routes` và `onGenerateRoute`**:
  - Đối với các màn hình không cần tham số khởi tạo (`DashboardScreen`, `ScannerScreen`), khai báo trực tiếp trong bảng `routes` giúp code ngắn gọn, rõ ràng và hiệu năng tra cứu O(1).
  - Đối với màn hình cần nhận dữ liệu động (`ReviewTransactionScreen` cần nhận `imagePath` từ bước chụp hóa đơn), sử dụng `onGenerateRoute` cho phép ép kiểu an toàn và truyền đối số qua constructor thay vì phụ thuộc vào `ModalRoute.of(context)` bên trong widget, giúp widget dễ test độc lập và tuân thủ nguyên lý Dependency Injection.
- **Khai báo `static const routeName` trong từng màn hình**:
  - Đảm bảo tính đóng gói (encapsulation): màn hình tự quản lý định danh đường dẫn của chính nó, tránh magic strings phân tán rải rác trong ứng dụng và giúp IDE hỗ trợ autocomplete/refactoring chính xác.
- **Cấu hình `onUnknownRoute`**:
  - Đảm bảo cơ chế fallback an toàn, ngăn app bị crash nếu có lỗi điều hướng bất thường trong runtime.

### File tạo / sửa / xóa
- Tạo:
  - `lib/screens/dashboard_screen.dart`
  - `lib/screens/scanner_screen.dart`
  - `lib/screens/review_transaction_screen.dart`
- Sửa:
  - `lib/main.dart`
  - `test/widget_test.dart`
  - `CHANGELOG.md`
  - `DEV_HISTORY.md`
- Xóa:
  - `lib/screens/.gitkeep`

### Kết quả kiểm tra
- `flutter analyze`: Không có cảnh báo hoặc lỗi nào (No issues found!).
- `flutter test`: 3/3 test cases passed hoàn toàn.
- `flutter build apk --debug`: Thành công 100% (`√ Built build\app\outputs\flutter-apk\app-debug.apk` trong 136.4s).
- `flutter devices`: Chưa có thiết bị Android thật kết nối (ghi chú và bỏ qua).

### Việc tồn đọng cho Bước 3
- Tích hợp package `camera`: khởi tạo camera controllers, hiển thị CameraPreview trên `ScannerScreen`, chụp ảnh và lưu tạm thời vào bộ nhớ file hệ thống.
- Thêm quyền Camera vào `android/app/src/main/AndroidManifest.xml`.
- Điều hướng từ `ScannerScreen` sang `ReviewTransactionScreen` mang theo `imagePath` thực tế sau khi chụp.

---

## [Bước 1] Khởi tạo dự án - 2026-10-02 00:54
### Mục tiêu
Khởi tạo cấu trúc dự án Flutter `ocr_expense_tracker` nhắm nền tảng Android, cài đặt đầy đủ các thư viện phụ thuộc (Camera, ML Kit, Isar, Provider, v.v.), thiết lập cấu hình Gradle minSdk, dọn dẹp mã nguồn mặc định và xác thực việc build thành công bản debug APK.

### Các việc đã làm
1. **Kiểm tra môi trường ban đầu**:
   - `git --version`: Git v2.44.0.
   - `flutter --version`: Flutter 3.47.5 stable, Dart 3.13.4.
   - `flutter doctor -v`: Android toolchain và SDK 35.0.0, JDK 21 Temurin đạt chuẩn.
   - `flutter devices`: Xác nhận chưa có thiết bị kết nối.
2. **Khởi tạo dự án Flutter**:
   - Lệnh: `flutter create --platforms android --org com.example ocr_expense_tracker`.
3. **Thay thế mã nguồn mặc định**:
   - Viết lại `lib/main.dart` với `MaterialApp` tối giản hiển thị `AppBar` tiêu đề "OCR Expense Tracker" và `Center(child: Text('Project initialized'))`.
   - Cập nhật test smoke trong `test/widget_test.dart` khớp với `main.dart` mới.
4. **Cài đặt thư viện**:
   - Thêm ban đầu: `flutter pub add camera google_mlkit_text_recognition isar isar_flutter_libs path_provider provider path intl`.
   - Thêm dev: `flutter pub add --dev isar_generator build_runner`.
   - Xử lý lỗi namespace AGP 8: Gỡ bỏ gói cũ (`flutter pub remove isar isar_flutter_libs isar_generator`), chuyển sang bộ thư viện `isar_community` tương thích với `flutter pub add isar_community isar_community_flutter_libs` và `flutter pub add --dev isar_community_generator`.
   - `flutter pub get`.
5. **Cấu hình Android build**:
   - Mở `android/app/build.gradle.kts`, chỉnh `minSdk = 21` (thay thế `flutter.minSdkVersion`) để thỏa mãn yêu cầu của `camera`, `google_mlkit_text_recognition` và `isar_community_flutter_libs`.
   - Giữ nguyên `compileSdk = flutter.compileSdkVersion` và `targetSdk = flutter.targetSdkVersion`.
   - Xác nhận `namespace = "com.example.ocr_expense_tracker"` đã tồn tại.
6. **Tạo cấu trúc thư mục kiến trúc trong `lib/`**:
   - Tạo các thư mục: `lib/models/`, `lib/screens/`, `lib/services/`, `lib/utils/`, `lib/widgets/`.
   - Đặt file `.gitkeep` rỗng vào mỗi thư mục để Git theo dõi.
7. **Kiểm tra chất lượng**:
   - Chạy `flutter test`: 1/1 test passed.
   - Chạy `flutter analyze`: 0 issues found.
   - Chạy `flutter build apk --debug`: Build thành công ra file `app-debug.apk`.

### Sự cố & cách sửa
| # | Lỗi/vấn đề (trích log ngắn) | Nguyên nhân | Cách sửa | Kết quả |
|---|---|---|---|---|
| 1 | `A problem occurred configuring project ':isar_flutter_libs'. > Namespace not specified. Specify a namespace in the module's build file: ...\isar_flutter_libs-3.1.0+1\android\build.gradle` khi chạy `flutter build apk --debug` | Android Gradle Plugin (AGP) 8.x yêu cầu mọi subproject Android bắt buộc phải khai báo thuộc tính `namespace`. Thư viện `isar_flutter_libs 3.1.0+1` đã cũ, chỉ khai báo `package` trong `AndroidManifest.xml` mà thiếu `namespace` trong `build.gradle` | Dừng lại báo cáo người dùng và đề xuất 3 phương án: (1) Cấu hình Gradle `subprojects` inject namespace; (2) Sửa trực tiếp Pub Cache; (3) Chuyển sang dùng fork cộng đồng `isar_community` được bảo trì. Người dùng đã phê duyệt Phương án 3, loại bỏ hoàn toàn hack Gradle và sửa cache | Chuyển sang `isar_community: 3.3.2` và `isar_community_flutter_libs: 3.3.2`, build debug APK thành công 100% |

### Quyết định kỹ thuật
- **Nền tảng nhắm tới**: Chỉ nhắm Android (`--platforms android`), vô hiệu hóa các nền tảng desktop và web nhằm giảm thiểu tài nguyên build và tập trung tối đa cho ứng dụng di động.
- **Giá trị minSdk = 21**: CameraX (camera package), Google ML Kit Text Recognition và Isar Android Native Libs đều yêu cầu tối thiểu Android 5.0 (API Level 21) để hoạt động với 64-bit ABI và camera pipeline hiện đại.
- **Lựa chọn `isar_community`**: Bản fork `isar_community` (v3.3.2) giải quyết triệt để vấn đề tương thích AGP 8+ và Gradle hiện đại, giữ nguyên chuẩn API của Isar Database.
- **Quy ước Import Isar**: Từ Bước 2 trở đi, toàn bộ schema model và service thao tác database sẽ sử dụng câu lệnh import: `import 'package:isar_community/isar.dart';`.

### File tạo / sửa / xóa
- Tạo:
  - `lib/models/.gitkeep`
  - `lib/screens/.gitkeep`
  - `lib/services/.gitkeep`
  - `lib/utils/.gitkeep`
  - `lib/widgets/.gitkeep`
  - `CHANGELOG.md`
  - `DEV_HISTORY.md`
- Sửa:
  - `lib/main.dart`
  - `test/widget_test.dart`
  - `pubspec.yaml`
  - `pubspec.lock`
  - `android/app/build.gradle.kts`
- Xóa: Không có file bị xóa ngoài phạm vi yêu cầu.

### Kết quả kiểm tra
- `flutter analyze`: Hoàn toàn sạch lỗi (No issues found!).
- `flutter test`: 1/1 test passed.
- `flutter build apk --debug`: Thành công 100%, xuất ra file `build\app\outputs\flutter-apk\app-debug.apk` trong 553.8s.
- `flutter devices`: Chưa có thiết bị vật lý kết nối.

### Việc tồn đọng / lưu ý cho bước sau
- Chuẩn bị thiết bị vật lý hoặc AVD để kiểm thử giao diện thực tế khi bước sang các giai đoạn tiếp theo.
- Khi tạo các model Isar ở Bước 2, sử dụng annotation từ `package:isar_community/isar.dart` và chạy code generation với lệnh `dart run build_runner build --delete-conflicting-outputs`.

---

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

---

> **Ghi chú quy ước phát triển**: Nếu sửa lỗi ở bước cũ, thêm mục mới dạng `## [Sửa lỗi] <mô tả ngắn> - <ngày giờ>` theo cùng mẫu ở trên cùng, không viết đè lịch sử cũ.

